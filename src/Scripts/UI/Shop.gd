extends Control

const ShopCard = preload("res://src/Scripts/UI/ShopCard.gd")
const UIConstants = preload("res://src/Scripts/Constants/UIConstants.gd")
const StyleMaker = preload("res://src/Scripts/Utils/StyleMaker.gd")

# Shop Logic
var shop_items: Array = []
var shop_locked: Array = [false, false, false, false]
const SHOP_SIZE = 4

# Node References
# Updated references based on new layout
@onready var shop_container = $Panel/MainContainer/LeftZone/ShopContainer
@onready var refresh_btn = $Panel/MainContainer/RightZone/RefreshButton
@onready var expand_btn = $Panel/MainContainer/RightZone/ExpandButton
@onready var start_wave_btn = $Panel/MainContainer/RightZone/StartWaveButton
@onready var sell_zone_container = $Panel/MainContainer/RightZone/SellZoneContainer
# These are removed from scene, checking if we can just remove them or if we need to keep vars as null safe
# @onready var global_preview = $Panel/MainContainer/Zone3/GlobalPreview # REMOVED
# @onready var current_details = $Panel/MainContainer/Zone3/CurrentDetails # REMOVED
@onready var gold_label = $Panel/MainContainer/LeftZone/GoldLabel
@onready var toggle_handle = $Panel/ToggleHandle

var sell_zone = null
var is_collapsed: bool = false
var panel_initial_y: float = 0.0

signal unit_bought(unit_key)

func _ready():
	GameManager.resource_changed.connect(update_ui)
	# 连接 WaveSystemManager 的波次信号
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(on_wave_started)
		GameManager.wave_system_manager.wave_ended.connect(on_wave_ended)

	# 连接 BoardController 信号
	BoardController.shop_refreshed.connect(_on_shop_refreshed)
	BoardController.unit_purchased.connect(_on_unit_purchased)

	# Wait for GameManager to be initialized
	if GameManager.core_type == "":
		await GameManager.core_type_changed

	# 先从 SessionData 加载商店数据（如果已有）
	_load_shop_from_session()
	update_ui()
	# update_wave_info() # Removed functionality

	expand_btn.pressed.connect(_on_expand_button_pressed)

	_create_sell_zone()
	call_deferred("_setup_collapse_handle")

	# Apply styles
	_apply_styles()

func _setup_collapse_handle():
	panel_initial_y = $Panel.position.y

	# ToggleHandle is now in Tscn, just connect signal
	if toggle_handle:
		if not toggle_handle.pressed.is_connected(_on_toggle_handle_pressed):
			toggle_handle.pressed.connect(_on_toggle_handle_pressed)

func _on_toggle_handle_pressed():
	if is_collapsed:
		expand_shop()
	else:
		collapse_shop()

func collapse_shop():
	if is_collapsed: return
	is_collapsed = true
	if toggle_handle: toggle_handle.text = "▲"

	var tween = create_tween()
	# Move panel down so only handle is visible at bottom
	# Since handle is hidden/invisible, we might not see anything. But logic is preserved as requested.
	var target_y = panel_initial_y + $Panel.size.y
	tween.tween_property($Panel, "position:y", target_y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func expand_shop():
	if !is_collapsed: return
	is_collapsed = false
	if toggle_handle: toggle_handle.text = "▼"

	var tween = create_tween()
	tween.tween_property($Panel, "position:y", panel_initial_y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _apply_styles():
	# Style Panel
	var panel = $Panel
	var panel_style = StyleBoxTexture.new()
	if ResourceLoader.exists("res://assets/images/UI/bg_shop.png"):
		panel_style.texture = load("res://assets/images/UI/bg_shop.png")
	# Ensure it stretches or tiles properly if needed, but for now default.
	# Fallback or overlay for borders
	# panel_style.border_width_top = 2 # StyleBoxTexture doesn't support border directly in same way
	# panel_style.border_color = Color("#ffffff")
	panel.add_theme_stylebox_override("panel", panel_style)

	# Style Buttons
	apply_button_style(refresh_btn, "primary") # Blue
	apply_button_style(expand_btn, "success") # Green
	apply_button_style(start_wave_btn, "danger", true) # Red, Main Action

func apply_button_style(button: Button, color_type: String, is_main_action: bool = false):
	var style_normal = StyleMaker.get_button_style(color_type)
	var color = style_normal.bg_color

	# Hover State
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = color.lightened(0.2)

	# Pressed State
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = color.darkened(0.2)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

	button.add_theme_font_size_override("font_size", 24) # Emoji size

func _create_sell_zone():
	# Create a visual area for selling inside Zone 1 -> SellZoneContainer
	sell_zone = PanelContainer.new()
	sell_zone.set_script(load("res://src/Scripts/UI/SellZone.gd"))
	var lbl = Label.new()
	lbl.text = "💰\nSELL"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_zone.add_child(lbl)

	# Add to SellZoneContainer
	sell_zone_container.add_child(sell_zone)
	sell_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Make sure it fills
	sell_zone.size_flags_horizontal = SIZE_EXPAND_FILL
	sell_zone.size_flags_vertical = SIZE_EXPAND_FILL

	sell_zone.mouse_filter = MOUSE_FILTER_STOP

	# Style Sell Zone
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0.3, 0.3, 0.3)
	style.set_corner_radius_all(12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 0, 0, 0.5)

	sell_zone.add_theme_stylebox_override("panel", style)

func update_ui():
	if gold_label:
		gold_label.text = "💰 %d" % GameManager.gold
	# update_wave_info() # REMOVED

# Removed update_wave_info, get_wave_type, get_wave_icon as they were used for GlobalPreview/CurrentDetails

func refresh_shop(force: bool = false):
	if force:
		# 强制刷新不走 BoardController（免费刷新）
		_perform_refresh()
	else:
		# 调用 BoardController API
		BoardController.refresh_shop()

func _perform_refresh():
	# Get player's current totem
	var player_faction = GameManager.core_type

	# Get available unit pool with faction weighting
	var faction_units = []
	var universal_units = []

	for unit_key in Constants.UNIT_TYPES.keys():
		var unit_data = Constants.UNIT_TYPES[unit_key]
		var unit_faction = unit_data.get("faction", "universal")

		if unit_faction == player_faction:
			faction_units.append(unit_key)
		elif unit_faction == "universal":
			universal_units.append(unit_key)

	var new_items = []

	for i in range(SHOP_SIZE):
		if shop_items.size() > i and shop_locked[i]:
			new_items.append(shop_items[i])
		else:
			# 70%概率出现阵营单位，30%概率出现通用单位
			if faction_units.size() > 0 and randf() < 0.7:
				new_items.append(faction_units.pick_random())
			elif universal_units.size() > 0:
				new_items.append(universal_units.pick_random())
			elif faction_units.size() > 0:
				new_items.append(faction_units.pick_random())
			else:
				new_items.append(Constants.UNIT_TYPES.keys().pick_random())

	shop_items = new_items

	# 同步到 SessionData，这样 BoardController 才能获取到商店单位
	if GameManager.session_data:
		for i in range(SHOP_SIZE):
			GameManager.session_data.set_shop_unit(i, shop_items[i])

	_update_shop_ui()

func _load_shop_from_session():
	"""从 SessionData 加载商店数据，避免覆盖已初始化的商店"""
	if GameManager.session_data:
		var has_existing_shop = false
		for i in range(SHOP_SIZE):
			var unit = GameManager.session_data.get_shop_unit(i)
			if unit != null:
				has_existing_shop = true
				break

		if has_existing_shop:
			# 使用已有的商店数据
			shop_items.clear()
			for i in range(SHOP_SIZE):
				shop_items.append(GameManager.session_data.get_shop_unit(i))
			_update_shop_ui()
		else:
			# 没有现有数据，执行刷新
			refresh_shop(true)
	else:
		# SessionData 未初始化，执行刷新
		refresh_shop(true)

func _update_shop_ui():
	for child in shop_container.get_children():
		child.queue_free()

	for i in range(SHOP_SIZE):
		create_shop_card(i, shop_items[i])

# New: Get unit list for specific faction
func _get_units_for_faction(faction: String) -> Array:
	var result = []

	for unit_key in Constants.UNIT_TYPES.keys():
		var unit_data = Constants.UNIT_TYPES[unit_key]
		var unit_faction = unit_data.get("faction", "universal")

		# Include specific faction or universal units
		if unit_faction == faction or unit_faction == "universal":
			result.append(unit_key)

	# Fallback if no units found (prevent crash)
	if result.is_empty():
		push_warning("No units found for faction: %s, falling back to all units" % faction)
		return Constants.UNIT_TYPES.keys()

	return result

func create_shop_card(index, unit_key):
	var card = ShopCard.new()
	card.setup(unit_key)
	card.custom_minimum_size = UIConstants.CARD_SIZE.large # Adjusted size for smaller shop
	card.size_flags_horizontal = SIZE_EXPAND_FILL

	card.card_clicked.connect(func(key): buy_unit(index, key, card))

	card.mouse_entered.connect(func():
		var proto = Constants.UNIT_TYPES[unit_key]
		var stats = {
			"damage": proto.get("damage", 0),
			"range": proto.get("range", 0),
			"atk_speed": proto.get("atkSpeed", proto.get("atk_speed", 1.0))
		}
		GameManager.show_tooltip.emit(proto, stats, [], card.get_global_mouse_position())
	)
	card.mouse_exited.connect(func(): GameManager.hide_tooltip.emit())

	shop_container.add_child(card)

func buy_unit(index, unit_key, card_ref):
	# 调用 BoardController API，传入期望的单位key进行验证
	var success = BoardController.buy_unit(index, unit_key)
	if success:
		card_ref.modulate = Color(0.5, 0.5, 0.5)
		card_ref.mouse_filter = MOUSE_FILTER_IGNORE
		unit_bought.emit(unit_key)

func on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	refresh_btn.disabled = true
	expand_btn.disabled = true
	start_wave_btn.disabled = true
	start_wave_btn.text = "⚔️"
	collapse_shop()

func on_wave_ended(wave_number: int = 0, stats: Dictionary = {}):
	refresh_btn.disabled = false
	expand_btn.disabled = false
	start_wave_btn.disabled = false
	refresh_shop(true)
	expand_shop()

func _on_start_wave_button_pressed():
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.start_wave()

func _on_refresh_button_pressed():
	refresh_shop(false)

func _on_expand_button_pressed():
	if GameManager.grid_manager:
		GameManager.grid_manager.toggle_expansion_mode()

# ===== BoardController 信号处理 =====

func _on_shop_refreshed(new_shop_units: Array):
	shop_items = new_shop_units
	_update_shop_ui()

func _on_unit_purchased(unit_key: String, target_zone: String, target_pos: Variant):
	# 金币已更新，刷新UI显示
	update_ui()

	# 如果购买成功且目标是暂存区，确保暂存区UI已刷新
	# 安全类型检查
	if target_zone == "bench" and target_pos is int:
		# 暂存区会通过 SessionData.bench_updated 信号自动刷新
		pass
