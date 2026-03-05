extends Control

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")
const UIConstants = preload("res://src/Scripts/Constants/UIConstants.gd")

signal sacrifice_requested

@onready var hp_bar = $TopLeftPanel/HPBar
@onready var mana_bar = $TopLeftPanel/ManaBar
@onready var hp_label = $TopLeftPanel/HPBar/Label
@onready var mana_label = $TopLeftPanel/ManaBar/Label
@onready var wave_label = $Panel/WaveLabel
@onready var stats_container = $DamageStats/ScrollContainer/VBoxContainer
@onready var damage_stats_panel = $DamageStats
@onready var stats_scroll = $DamageStats/ScrollContainer
@onready var stats_header = $DamageStats/Header
@onready var left_sidebar = $LeftSidebar
@onready var right_sidebar = $RightSidebar
@onready var top_left_panel = $TopLeftPanel

@onready var game_over_panel = $GameOverPanel
@onready var retry_button = $GameOverPanel/RetryWaveButton
@onready var new_game_button = $GameOverPanel/NewGameButton
@onready var cutin_manager = $CutInManager

const FLOATING_TEXT_SCENE = preload("res://src/Scenes/UI/FloatingText.tscn")
const TOOLTIP_SCENE = preload("res://src/Scenes/UI/Tooltip.tscn")

var damage_stats = {} # unit_id -> {name, icon, amount, node}
var last_sort_time: float = 0.0
var tooltip_instance = null
var sort_interval: float = 1.0
var sidebar_tween: Tween
var shop_node: Control = null

# New Combat Gold Label
var combat_gold_label: Label
var soul_label: Label

# Risk-Reward Warning UI
var risk_warning_panel: Panel
var risk_warning_label: Label
var risk_warning_tween: Tween

func _ready():
	# Remove FoodBar if it exists
	var food_bar_node = $TopLeftPanel.get_node_or_null("FoodBar")
	if food_bar_node:
		food_bar_node.queue_free()

	# 1. 布局核心修复：强制重置侧边栏锚点为全高模式
	_fix_sidebar_anchors()

	# 连接 SessionData 信号（替代 GameManager.resource_changed）
	if GameManager.session_data:
		GameManager.session_data.gold_changed.connect(_on_gold_changed)
		GameManager.session_data.mana_changed.connect(_on_mana_changed)
		GameManager.session_data.core_health_changed.connect(_on_core_health_changed)
		GameManager.session_data.wave_changed.connect(_on_wave_changed)

	GameManager.resource_changed.connect(update_ui)
	# 连接 WaveSystemManager 的波次信号
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(update_ui)
		GameManager.wave_system_manager.wave_ended.connect(_on_wave_ended_wrapper)
		GameManager.wave_system_manager.wave_started.connect(_update_hud_visibility)
		GameManager.wave_system_manager.wave_ended.connect(_on_wave_ended_hud_wrapper)
		GameManager.wave_system_manager.wave_started.connect(_update_sidebar_position)
		GameManager.wave_system_manager.wave_ended.connect(_on_wave_ended_sidebar_wrapper)

	GameManager.game_over.connect(_on_game_over)
	GameManager.game_reset.connect(_on_game_reset)

	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.skill_activated.connect(_on_skill_activated)
	GameManager.ftext_spawn_requested.connect(_on_ftext_spawn_requested)

	# Connect risk-reward warning signal
	GameManager.risk_reward_warning_changed.connect(_on_risk_reward_warning_changed)

	_setup_ui_styles()

	if retry_button:
		retry_button.pressed.connect(_on_retry_wave_pressed)
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)

	_setup_tooltip()

	_setup_stats_panel()
	_setup_combat_gold_label()
	_setup_soul_label()

	# 连接狼图腾魂魄变化信号
	TotemManager.totem_resource_changed.connect(_on_totem_resource_changed)
	_on_totem_resource_changed("wolf", TotemManager.get_resource("wolf"), TotemManager.get_max_resource("wolf"))
	
	# 2. 布局核心修复：重新组织右侧栏内容，解决重叠
	_setup_right_sidebar_layout()

	# Setup risk-reward warning UI
	_setup_risk_reward_warning()

	# Try to find Shop node dynamically
	shop_node = get_tree().root.find_child("Shop", true, false)
	if not shop_node and GameManager.get("main_game"):
		shop_node = GameManager.main_game.find_child("Shop", true, false)

	update_ui()

	# Initial visibility state
	_update_hud_visibility()
	_update_sidebar_position()

# --- 关键修复：修正侧边栏锚点 ---
func _fix_sidebar_anchors():
	# 将侧边栏强制改为全高度容器，避免被压缩
	if left_sidebar:
		left_sidebar.anchor_top = 0.0
		left_sidebar.anchor_bottom = 1.0
		left_sidebar.offset_top = 0.0
		# offset_bottom 将在 _update_sidebar_position 中动态控制
		
	if right_sidebar:
		right_sidebar.anchor_top = 0.0
		right_sidebar.anchor_bottom = 1.0
		right_sidebar.offset_top = 0.0
		# 确保本身是 VBox 且底部对齐
		# 安全类型检查：避免 BoxContainer 类为 null 时崩溃
		if BoxContainer != null and right_sidebar is BoxContainer:
			right_sidebar.alignment = BoxContainer.ALIGNMENT_END

# --- 关键修复：重构右侧栏内容 ---
func _setup_right_sidebar_layout():
	if not right_sidebar: return

	# 获取子节点引用
	var passive_bar = right_sidebar.get_node_or_null("PassiveSkillBar")
	if not passive_bar: passive_bar = get_node_or_null("PassiveSkillBar")
	if not passive_bar: passive_bar = find_child("PassiveSkillBar", true, false)

	var inv_panel = right_sidebar.get_node_or_null("InventoryPanel")
	if not inv_panel: inv_panel = get_node_or_null("InventoryPanel")
	if not inv_panel: inv_panel = find_child("InventoryPanel", true, false)

	# 确保它们都在 right_sidebar 下
	if passive_bar and passive_bar.get_parent() != right_sidebar:
		passive_bar.reparent(right_sidebar)
	if inv_panel and inv_panel.get_parent() != right_sidebar:
		inv_panel.reparent(right_sidebar)

	# --- 修复核心：设置 Size Flags 和 最小高度 ---
	
	# 1. 被动技能栏 (PassiveSkillBar)
	if passive_bar:
		passive_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		passive_bar.size_flags_vertical = Control.SIZE_SHRINK_END
		# PassiveSkillBar 脚本里有 _process 更新 min_size，所以这里通常不用强制设置，但为了保险初始化设为0
		# passive_bar.custom_minimum_size.y = 0 
		
	# 2. 间隔 (Spacer)
	# 检查是否已经有 Spacer，防止重复添加
	var existing_spacer = right_sidebar.get_node_or_null("SidebarSpacer")
	if existing_spacer: existing_spacer.queue_free()
	
	var spacer = Control.new()
	spacer.name = "SidebarSpacer"
	spacer.custom_minimum_size = Vector2(0, 60) # 间距 60px
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_sidebar.add_child(spacer)

	# 3. 物品栏 (InventoryPanel)
	if inv_panel:
		inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inv_panel.size_flags_vertical = Control.SIZE_SHRINK_END
		
		# [重要修复]：强制给 InventoryPanel 设置最小高度。
		# 因为 InventoryPanel.tscn 根节点是 Control，默认 min_size 是 (0,0)。
		# 如果不设置这个，VBox 会认为它高度为 0，导致它和上面的元素重叠，并且内容向下溢出。
		inv_panel.custom_minimum_size.y = 220.0 

	# --- 排序：从上到下 (由于 Alignment=End，这实际上是靠底堆叠的顺序) ---
	# 在 VBox ALIGNMENT_END 模式下，子节点列表中的最后一个元素在最底部。
	# 我们希望顺序是：
	# (顶部空闲区域)
	# PassiveSkillBar
	# Spacer
	# InventoryPanel (最底端)
	
	if passive_bar: right_sidebar.move_child(passive_bar, right_sidebar.get_child_count()-1)
	if spacer: right_sidebar.move_child(spacer, right_sidebar.get_child_count()-1)
	if inv_panel: right_sidebar.move_child(inv_panel, right_sidebar.get_child_count()-1)

func _setup_combat_gold_label():
	combat_gold_label = Label.new()
	combat_gold_label.name = "CombatGoldLabel"
	combat_gold_label.text = "💰 0"
	combat_gold_label.add_theme_font_size_override("font_size", 20)
	combat_gold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combat_gold_label.add_theme_constant_override("outline_size", 4)

	if top_left_panel:
		top_left_panel.add_child(combat_gold_label)
		# 安全类型检查：避免 Container 类为 null 时崩溃
		if Container != null and not (top_left_panel is Container):
			combat_gold_label.layout_mode = 1
			combat_gold_label.anchors_preset = Control.PRESET_BOTTOM_LEFT
			combat_gold_label.position.y = top_left_panel.size.y + 10

func _setup_soul_label():
	soul_label = Label.new()
	soul_label.name = "SoulLabel"
	soul_label.text = "🔮 0"
	soul_label.add_theme_font_size_override("font_size", 18)
	soul_label.add_theme_color_override("font_outline_color", Color.BLACK)
	soul_label.add_theme_constant_override("outline_size", 4)

	if top_left_panel:
		top_left_panel.add_child(soul_label)
		# 安全类型检查：避免 Container 类为 null 时崩溃
		if Container != null and not (top_left_panel is Container):
			soul_label.layout_mode = 1
			soul_label.anchors_preset = Control.PRESET_BOTTOM_LEFT
			# Place below combat gold label (which is at size.y + 10)
			soul_label.position.y = top_left_panel.size.y + 40

func _on_totem_resource_changed(totem_id: String, current: int, max_value: int):
	# 只显示狼图腾的魂魄数量
	if totem_id == "wolf" and soul_label:
		soul_label.text = "🔮 %d/%d" % [current, max_value]

# ===== SessionData 信号处理 =====

func _on_gold_changed(new_amount: int):
	if combat_gold_label:
		combat_gold_label.text = "💰 %d" % new_amount

func _on_mana_changed(current: float, maximum: float):
	if mana_bar:
		mana_bar.value = (current / maximum) * 100
	if mana_label:
		mana_label.text = "💧 %d/%d" % [int(current), int(maximum)]

func _on_core_health_changed(current: float, maximum: float):
	if hp_bar:
		var target_hp = (current / maximum) * 100
		create_tween().tween_property(hp_bar, "value", target_hp, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hp_label:
		hp_label.text = "❤️ %d/%d" % [int(current), int(maximum)]

func _on_wave_changed(new_wave: int):
	if wave_label:
		wave_label.text = "Wave %d" % new_wave

func _setup_stats_panel():
	damage_stats_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	damage_stats_panel.position.x = 0
	damage_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stats_scroll: stats_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stats_container: stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_hud_visibility(_wave_number: int = 0, _wave_type: String = "", _difficulty: float = 1.0):
	var is_combat = GameManager.session_data.is_wave_active if GameManager.session_data else false
	hp_bar.visible = is_combat
	mana_bar.visible = is_combat
	if damage_stats_panel:
		damage_stats_panel.visible = !is_combat
	if combat_gold_label:
		combat_gold_label.visible = is_combat
	if soul_label:
		soul_label.visible = is_combat

# wave_ended信号包装器 - 适配不同参数签名
func _on_wave_ended_hud_wrapper(_wave_number: int, _stats: Dictionary):
	_update_hud_visibility(_wave_number)

func _update_sidebar_position(_wave_number: int = 0, _wave_type: String = "", _difficulty: float = 1.0):
	if not left_sidebar:
		return

	if sidebar_tween and sidebar_tween.is_valid():
		sidebar_tween.kill()

	var target_offset_bottom = UIConstants.MARGINS.sidebar_bottom_combat # 战斗模式：贴近底边 (InventoryPanel 会在这个位置之上)

	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	if not is_wave_active:
		# 商店模式：向上避让
		var shop_height = UIConstants.MARGINS.sidebar_shop_base_height
		if shop_node and is_instance_valid(shop_node) and shop_node.visible:
			shop_height = shop_node.size.y
			if shop_height < 150: shop_height = 180.0 # 最小高度保护

		# 向上移动侧边栏底部，留出商店空间 + 缓冲
		target_offset_bottom = -(shop_height + 20)

	# 检查是否有有效的侧边栏需要动画
	if not left_sidebar and not right_sidebar:
		return

	sidebar_tween = create_tween()
	sidebar_tween.set_parallel(true)
	# 通过改变 offset_bottom 来挤压/拉伸 VBox 的高度。
	# 由于子元素是 Bottom Aligned，当 Bottom 向上移时，它们会自动跟着上移。
	if left_sidebar:
		sidebar_tween.tween_property(left_sidebar, "offset_bottom", float(target_offset_bottom), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if right_sidebar:
		sidebar_tween.tween_property(right_sidebar, "offset_bottom", float(target_offset_bottom), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# wave_ended信号包装器 - 适配不同参数签名
func _on_wave_ended_sidebar_wrapper(_wave_number: int, _stats: Dictionary):
	_update_sidebar_position(_wave_number)

func _setup_ui_styles():
	var radius = UIConstants.CORNER_RADIUS.medium
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = UIConstants.BAR_COLORS.hp
	hp_fill.set_corner_radius_all(radius)
	var mana_fill = StyleBoxFlat.new()
	mana_fill.bg_color = UIConstants.BAR_COLORS.mana
	mana_fill.set_corner_radius_all(radius)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = UIConstants.COLORS.panel_bg
	bg_style.set_corner_radius_all(radius)

	if hp_bar:
		hp_bar.add_theme_stylebox_override("background", bg_style)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
	if mana_bar:
		mana_bar.add_theme_stylebox_override("background", bg_style)
		mana_bar.add_theme_stylebox_override("fill", mana_fill)

	var labels = [hp_label, mana_label]
	for label in labels:
		if label:
			label.add_theme_constant_override("outline_size", 4)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_font_size_override("font_size", 18)

func _setup_tooltip():
	tooltip_instance = TOOLTIP_SCENE.instantiate()
	add_child(tooltip_instance)
	tooltip_instance.hide()
	GameManager.show_tooltip.connect(_on_show_tooltip)
	GameManager.hide_tooltip.connect(_on_hide_tooltip)

func _on_show_tooltip(data, stats, buffs, pos):
	if tooltip_instance:
		tooltip_instance.show_tooltip(data, stats, buffs, pos)

func _on_hide_tooltip():
	if tooltip_instance:
		tooltip_instance.hide_tooltip()

func _process(delta):
	if last_sort_time > 0:
		last_sort_time -= delta
	
	if cutin_manager and top_left_panel and left_sidebar:
		_update_cutin_layout()

func _update_cutin_layout():
	var top_panel_bottom = top_left_panel.position.y + top_left_panel.size.y
	# 简单处理：CutIn 区域从 TopPanel 下方开始
	var screen_h = get_viewport_rect().size.y
	var bottom_margin = 350.0 # 预留给左侧可能的UI
	
	var x_pos = top_left_panel.position.x
	var width = 270.0
	var available_height = screen_h - top_panel_bottom - bottom_margin
	if available_height < 100: available_height = 100
	
	var new_rect = Rect2(x_pos, top_panel_bottom, width, available_height)
	cutin_manager.update_area(new_rect)

func update_ui(_wave_number: int = 0, _wave_type: String = "", _difficulty: float = 1.0):
	var target_hp = (GameManager.core_health / GameManager.max_core_health) * 100
	create_tween().tween_property(hp_bar, "value", target_hp, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# wave_ended信号包装器 - 适配不同参数签名
func _on_wave_ended_wrapper(_wave_number: int, _stats: Dictionary):
	update_ui(_wave_number)

	mana_bar.value = (GameManager.mana / GameManager.max_mana) * 100

	hp_label.text = "❤️ %d/%d" % [int(GameManager.core_health), int(GameManager.max_core_health)]
	mana_label.text = "💧 %d/%d" % [int(GameManager.mana), int(GameManager.max_mana)]
	var current_wave = GameManager.session_data.wave if GameManager.session_data else 1
	wave_label.text = "Wave %d" % current_wave
	if combat_gold_label:
		combat_gold_label.text = "💰 %d" % GameManager.gold

func _on_damage_dealt(unit, amount):
	if not unit: return
	var id = unit.get_instance_id()

	if not damage_stats.has(id):
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if "type_key" in unit and AssetLoader:
			var icon = AssetLoader.get_unit_icon(unit.type_key)
			if icon: icon_rect.texture = icon

		row.add_child(icon_rect)

		var name_lbl = Label.new()
		var dmg_lbl = Label.new()
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dmg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var unit_name = "Unit"
		if "unit_data" in unit and unit.unit_data:
			unit_name = unit.unit_data.get("name", "Unit")

		name_lbl.text = unit_name
		dmg_lbl.text = "0"
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		row.add_child(name_lbl)
		row.add_child(dmg_lbl)
		stats_container.add_child(row)

		damage_stats[id] = { "amount": 0, "dmg_lbl": dmg_lbl, "row": row }

	damage_stats[id].amount += amount
	damage_stats[id].dmg_lbl.text = str(int(damage_stats[id].amount))

	if last_sort_time <= 0:
		_sort_stats()
		last_sort_time = sort_interval

func _sort_stats():
	var children = stats_container.get_children()
	children.sort_custom(func(a, b):
		return _get_amount_from_row(a) > _get_amount_from_row(b)
	)
	for i in range(children.size()):
		stats_container.move_child(children[i], i)

func _get_amount_from_row(row):
	for id in damage_stats:
		if damage_stats[id].row == row:
			return damage_stats[id].amount
	return 0

func _on_skill_activated(unit):
	if cutin_manager: cutin_manager.trigger_cutin(unit)

func _on_ftext_spawn_requested(pos, value, color, direction):
	var ftext = FLOATING_TEXT_SCENE.instantiate()
	var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	var world_pos = pos + offset
	var screen_pos = get_viewport().canvas_transform * world_pos

	ftext.position = screen_pos
	add_child(ftext)

	var value_num: float = 0.0
	var display_value = str(value)
	if display_value.is_valid_float():
		value_num = float(display_value)
		display_value = str(int(value_num))

	var is_crit = color.r > 0.9 and color.g > 0.8 and color.b < 0.4
	ftext.setup(display_value, color, is_crit, value_num, direction)

func _on_game_over():
	if game_over_panel: game_over_panel.show()

func _on_game_reset():
	if game_over_panel: game_over_panel.hide()

func _on_retry_wave_pressed():
	if game_over_panel: game_over_panel.hide()
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.reset()
		GameManager.wave_system_manager.current_wave = GameManager.session_data.wave if GameManager.session_data else 1
	# 重试波次：完全恢复核心血量
	if GameManager.session_data:
		GameManager.session_data.core_health = GameManager.session_data.max_core_health
		GameManager.session_data.is_wave_active = false
	# 清除敌人
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.has_method("call_group"):
		main_loop.call_group("enemies", "queue_free")
	GameManager.resource_changed.emit()

func _on_new_game_pressed():
	get_tree().reload_current_scene()

# ===== Risk-Reward Warning System =====
func _setup_risk_reward_warning():
	"""
	设置风险奖励警告UI
	当核心HP <= 35%时显示红色警告边框
	"""
	# Create warning panel (full screen overlay with border)
	risk_warning_panel = Panel.new()
	risk_warning_panel.name = "RiskWarningPanel"
	risk_warning_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	risk_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	risk_warning_panel.visible = false

	# Create red border style
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0.75, 0.22, 0.17, 0.0)  # Transparent center
	border_style.border_color = Color(0.91, 0.3, 0.24)  # Red #e74c3c
	border_style.border_width_left = 20
	border_style.border_width_right = 20
	border_style.border_width_top = 20
	border_style.border_width_bottom = 20
	border_style.set_corner_radius_all(0)
	risk_warning_panel.add_theme_stylebox_override("panel", border_style)

	# Create warning label
	risk_warning_label = Label.new()
	risk_warning_label.name = "RiskWarningLabel"
	risk_warning_label.text = "⚠ 风险奖励激活 - 吸血效果翻倍"
	risk_warning_label.add_theme_font_size_override("font_size", 24)
	risk_warning_label.add_theme_color_override("font_color", Color(0.91, 0.3, 0.24))  # Red
	risk_warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	risk_warning_label.add_theme_constant_override("outline_size", 4)
	risk_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	risk_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	risk_warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	risk_warning_label.position.y = 50

	# Add to scene
	add_child(risk_warning_panel)
	risk_warning_panel.add_child(risk_warning_label)

func _on_risk_reward_warning_changed(active: bool):
	"""
	处理风险奖励警告状态变化
	"""
	if not risk_warning_panel:
		return

	risk_warning_panel.visible = active

	if active:
		_start_risk_warning_pulse()
	else:
		_stop_risk_warning_pulse()

func _start_risk_warning_pulse():
	"""
	启动警告边框脉冲动画
	2秒周期：淡入淡出
	"""
	if risk_warning_tween and risk_warning_tween.is_valid():
		risk_warning_tween.kill()

	var border_style = risk_warning_panel.get_theme_stylebox("panel")
	if border_style:
		risk_warning_tween = create_tween().set_loops()
		risk_warning_tween.tween_property(border_style, "border_color:a", 0.3, 1.0)
		risk_warning_tween.tween_property(border_style, "border_color:a", 1.0, 1.0)

func _stop_risk_warning_pulse():
	"""
	停止警告边框脉冲动画
	"""
	if risk_warning_tween and risk_warning_tween.is_valid():
		risk_warning_tween.kill()
		risk_warning_tween = null

	var border_style = risk_warning_panel.get_theme_stylebox("panel")
	if border_style:
		border_style.border_color.a = 1.0
