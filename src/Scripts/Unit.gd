class_name Unit
extends Node2D

const UnitBehavior = preload("res://src/Scripts/Units/UnitBehavior.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var is_summoned: bool = false
var type_key: String
var level: int = 1
var stats_multiplier: float = 1.0
var cooldown: float = 0.0
var skill_cooldown: float = 0.0
var active_buffs: Array:
	get: return buff_manager.active_buffs if buff_manager else []
	set(value): if buff_manager: buff_manager.active_buffs = value
var buff_sources: Dictionary:
	get: return buff_manager.buff_sources if buff_manager else {}
	set(value): if buff_manager: buff_manager.buff_sources = value
var temporary_buffs: Array = [] # Array of {stat, amount, duration, source}
var traits: Array = []
var unit_data: Dictionary

var behavior: UnitBehavior

var attachment: Node2D = null
var host: Node2D = null

const BuffManager = preload("res://src/Scripts/Units/Components/BuffManager.gd")
const UnitStats = preload("res://src/Scripts/Units/Components/UnitStats.gd")
const CombatController = preload("res://src/Scripts/Units/Components/CombatController.gd")
const VisualController = preload("res://src/Scripts/Units/Components/VisualController.gd")
const InteractController = preload("res://src/Scripts/Units/Components/InteractController.gd")

var buff_manager: BuffManager
var stats: UnitStats
var combat: CombatController
var visual: VisualController
var interact: InteractController


# Visual Holder for animations and structure
var visual_holder: Node2D = null

var is_no_mana: bool = false
var bounce_count: int = 0
var split_count: int = 0

var guaranteed_crit_stacks: int = 0

# Grid
var grid_pos: Vector2i = Vector2i.ZERO
var start_position: Vector2 = Vector2.ZERO

# Interaction
var interaction_target_pos = null # Vector2i or null
var associated_traps: Array = [] # Stores references to traps placed by this unit

# Dragging
var is_dragging: bool:
	get: return interact.is_dragging if interact else false
	set(value): if interact: interact.is_dragging = value
var drag_offset: Vector2:
	get: return interact.drag_offset if interact else Vector2.ZERO
	set(value): if interact: interact.drag_offset = value
var ghost_node: Node2D:
	get: return interact.ghost_node if interact else null
	set(value): if interact: interact.ghost_node = value
var is_hovered: bool:
	get: return interact.is_hovered if interact else false
	set(value): if interact: interact.is_hovered = value
var focus_target: Node2D:
	get: return interact.focus_target if interact else null
	set(value): if interact: interact.focus_target = value
var focus_stacks: int:
	get: return interact.focus_stacks if interact else 0
	set(value): if interact: interact.focus_stacks = value

# Highlighting
var _is_skill_highlight_active: bool = false
var _highlight_color: Color = Color.WHITE
var is_force_highlighted: bool = false

const MAX_LEVEL = 3
const DRAG_HANDLER_SCRIPT = preload("res://src/Scripts/UI/UnitDragHandler.gd")

signal unit_clicked(unit)
signal attack_performed(target_node)
signal merged(consumed_unit)
signal damage_blocked(damage: float, source: Node)

func _start_skill_cooldown(base_duration: float):
	if GameManager.cheat_fast_cooldown and base_duration > 1.0:
		skill_cooldown = 1.0
	else:
		skill_cooldown = base_duration * GameManager.get_stat_modifier("cooldown")

func _ready():
	_ensure_visual_hierarchy()
	tree_exiting.connect(_on_cleanup)

	if !unit_data.is_empty():
		update_visuals()

func _on_cleanup():
	if behavior:
		behavior.on_cleanup()

func setup(key: String):
	_ensure_visual_hierarchy()
	type_key = key
	unit_data = Constants.UNIT_TYPES[key].duplicate()

	buff_manager = BuffManager.new()
	buff_manager.name = "BuffManager"
	add_child(buff_manager)
	buff_manager.unit = self

	stats = UnitStats.new()
	stats.name = "Stats"
	add_child(stats)
	stats.unit = self

	combat = CombatController.new()
	combat.name = "CombatController"
	add_child(combat)
	combat.unit = self

	visual = VisualController.new()
	visual.name = "VisualController"
	add_child(visual)
	visual.unit = self

	interact = InteractController.new()
	interact.name = "InteractController"
	add_child(interact)
	interact.unit = self

	_load_behavior()

	reset_stats()
	stats.current_hp = stats.max_hp
	behavior.on_setup()

	update_visuals()
	start_breathe_anim()

	var drag_handler = Control.new()
	drag_handler.set_script(DRAG_HANDLER_SCRIPT)
	add_child(drag_handler)
	drag_handler.setup(self)

func _load_behavior():
	var behavior_name = type_key.to_pascal_case()
	var path = "res://src/Scripts/Units/Behaviors/%s.gd" % behavior_name
	var script_res = null

	if ResourceLoader.exists(path):
		script_res = load(path)
	else:
		script_res = load("res://src/Scripts/Units/Behaviors/DefaultBehavior.gd")

	behavior = script_res.new(self)

func _ensure_visual_hierarchy():
	if visual_holder and is_instance_valid(visual_holder):
		return

	visual_holder = get_node_or_null("VisualHolder")
	if !visual_holder:
		visual_holder = Node2D.new()
		visual_holder.name = "VisualHolder"
		add_child(visual_holder)

		var visual_elements = ["Label", "StarLabel"]
		for child_name in visual_elements:
			var child = get_node_or_null(child_name)
			if child:
				remove_child(child)
				visual_holder.add_child(child)

	var highlight = visual_holder.get_node_or_null("HighlightBorder")
	if !highlight:
		highlight = ReferenceRect.new()
		highlight.name = "HighlightBorder"
		highlight.border_width = 4.0
		highlight.editor_only = false
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_holder.add_child(highlight)

	if unit_data and unit_data.has("size"):
		var size_val = unit_data["size"]
		var target_size = Vector2(size_val.x * Constants.TILE_SIZE - 4, size_val.y * Constants.TILE_SIZE - 4)
		highlight.size = target_size
		highlight.position = -(target_size / 2)

func take_damage(amount: float, source_enemy = null):
	var final_amount = amount
	if buff_manager:
		final_amount = buff_manager.modify_damage_taken(final_amount, source_enemy)
	if behavior:
		final_amount = behavior.on_damage_taken(final_amount, source_enemy)

	var blocked_amount = amount - final_amount
	if blocked_amount > 0:
		damage_blocked.emit(blocked_amount, source_enemy)

	stats.take_damage(final_amount)
	if get_tree().root.has_node("GameManager"):
		get_node("/root/GameManager").damage_core(final_amount)

	if visual: visual.play_damage_anim()

func reset_stats():
	if stats:
		stats.reset_stats(unit_data, level)

	bounce_count = 0
	split_count = 0

	if buff_manager:
		buff_manager.active_buffs.clear()
		buff_manager.buff_sources.clear()

	if get_tree().root.has_node("GameManager"):
		var GameManager = get_node("/root/GameManager")
		if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
			stats.range_val *= 1.2

	if behavior:
		behavior.on_stats_updated()

	update_visuals()

func capture_bullet(bullet_snapshot: Dictionary):
	if behavior.has_method("capture_bullet"):
		behavior.capture_bullet(bullet_snapshot)

func calculate_damage_against(target_node: Node2D) -> float:
	var final_damage = stats.damage if stats else 0.0

	if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
		if target_node == focus_target:
			focus_stacks = min(focus_stacks + 1, 10)
		else:
			focus_target = target_node
			focus_stacks = 0

		final_damage *= (1.0 + 0.05 * focus_stacks)

	final_damage *= GameManager.get_stat_modifier("damage")

	return final_damage

func apply_buff(buff_type: String, source_unit: Node2D = null):
	var is_stackable = buff_type == "bounce" or buff_type == "split"
	var is_new_buff = not (buff_type in active_buffs)

	if buff_type in active_buffs and not is_stackable: return

	if is_new_buff:
		active_buffs.append(buff_type)

	if source_unit:
		buff_sources[buff_type] = source_unit

	# 记录[BUFF]日志
	if AILogger:
		var source_name = source_unit.type_key if source_unit and source_unit.get("type_key") else "未知"
		var target_name = type_key if type_key else "单位"
		var effect_desc = ""
		match buff_type:
			"range": effect_desc = "射程+25%"
			"speed": effect_desc = "攻速+20%"
			"crit": effect_desc = "暴击率+25%"
			"bounce": effect_desc = "弹射+1"
			"split": effect_desc = "分裂+1"
			"forest_blessing": effect_desc = "森林祝福"
			"guardian_shield": effect_desc = "守护护盾"

		if is_new_buff:
			var buff_msg = "[BUFF] %s 施加 %s Buff | 目标: %s | 效果: %s" % [source_name, buff_type, target_name, effect_desc]
			AILogger.event(buff_msg)
			# 同时通过AIManager广播，确保测试脚本能检测到
			if AIManager:
				AIManager.broadcast_text(buff_msg)
		elif is_stackable:
			# 记录[BUFF_STACK]日志
			var current_stacks = bounce_count if buff_type == "bounce" else split_count
			var stack_msg = "[BUFF_STACK] %s %s Buff叠加 | 目标: %s | 当前层数: %d | 效果: %s" % [source_name, buff_type, target_name, current_stacks + 1, effect_desc]
			AILogger.event(stack_msg)
			# 同时通过AIManager广播，确保测试脚本能检测到
			if AIManager:
				AIManager.broadcast_text(stack_msg)

	# Emit buff_applied signal for test logging
	if GameManager.has_signal("buff_applied"):
		var amount = 0.0
		match buff_type:
			"range": amount = 1.25
			"speed": amount = 1.2
			"crit": amount = 0.25
			"bounce": amount = 1.0
			"split": amount = 1.0
			"forest_blessing": amount = 1.0
			"guardian_shield": amount = 1.0
		GameManager.buff_applied.emit(self, buff_type, source_unit, amount)

	match buff_type:
		"range":
			if stats: stats.range_val *= 1.25
		"speed":
			if stats: stats.atk_speed *= 1.2
		"crit":
			if stats: stats.crit_rate += 0.25
		"bounce":
			bounce_count += 1
		"split":
			split_count += 1
		"guardian_shield":
			# 牦牛守护的减伤buff，效果在take_damage中处理
			pass

func set_highlight(active: bool, color: Color = Color.WHITE):
	_is_skill_highlight_active = active
	_highlight_color = color
	queue_redraw()

func set_force_highlight(active: bool):
	is_force_highlighted = active
	queue_redraw()

func execute_skill_at(grid_pos: Vector2i):
	if combat: combat.execute_skill_at(grid_pos)

func add_crit_stacks(amount: int):
	guaranteed_crit_stacks += amount
	GameManager.spawn_floating_text(global_position, "Crit Ready!", Color.ORANGE)

func _on_skill_ended():
	set_highlight(false)

func activate_skill():
	if combat: combat.activate_skill()

func update_visuals():
	_ensure_visual_hierarchy()
	var label = visual_holder.get_node_or_null("Label")
	var star_label = visual_holder.get_node_or_null("StarLabel")

	var icon_texture = AssetLoader.get_unit_icon(type_key)

	var tex_rect = visual_holder.get_node_or_null("TextureRect")
	if !tex_rect:
		tex_rect = TextureRect.new()
		tex_rect.name = "TextureRect"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_holder.add_child(tex_rect)
		if label: visual_holder.move_child(tex_rect, label.get_index())

	if icon_texture:
		tex_rect.texture = icon_texture
		tex_rect.show()
		if label: label.hide()
	else:
		tex_rect.hide()
		if label:
			label.text = unit_data.icon
			label.show()
	
	var size = unit_data["size"]
	var target_size = Vector2(size.x * Constants.TILE_SIZE - 4, size.y * Constants.TILE_SIZE - 4)
	var target_pos = -(target_size / 2)

	if tex_rect:
		tex_rect.size = target_size
		tex_rect.position = target_pos
		tex_rect.pivot_offset = tex_rect.size / 2

	if label:
		label.size = target_size
		label.position = target_pos
		label.pivot_offset = label.size / 2

	if level > 1:
		if star_label:
			star_label.text = "⭐%d" % level
			star_label.show()
	else:
		if star_label:
			star_label.hide()

	_update_buff_icons()

func _update_buff_icons():
	var buff_container = get_node_or_null("BuffContainer")
	if !buff_container:
		buff_container = HBoxContainer.new()
		buff_container.name = "BuffContainer"
		buff_container.alignment = BoxContainer.ALIGNMENT_CENTER

		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit_data and unit_data.has("size"):
			size = Vector2(unit_data["size"].x * Constants.TILE_SIZE, unit_data["size"].y * Constants.TILE_SIZE)

		buff_container.position = Vector2(-size.x/2, size.y/2 - 20)
		buff_container.size = Vector2(size.x, 15)

		buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(buff_container)

	for child in buff_container.get_children():
		child.queue_free()

	for buff in active_buffs:
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		lbl.text = _get_buff_icon(buff)
		buff_container.add_child(lbl)

func _get_buff_icon(buff_type: String) -> String:
	match buff_type:
		"fire": return "🔥"
		"poison": return "🧪"
		"range": return "🔭"
		"speed": return "⚡"
		"crit": return "💥"
		"bounce": return "🪞"
		"split": return "💠"
		"multishot": return "📶"
		"wealth": return "💰"
	return "?"

func _process(delta):
	if !GameManager.session_data.is_wave_active: return
	if not behavior: return

	behavior.on_tick(delta)

	_update_temporary_buffs(delta)

	if !behavior.on_combat_tick(delta):
		_process_combat(delta)

	if skill_cooldown > 0:
		skill_cooldown -= delta

	if is_no_mana and unit_data.has("skill"):
		modulate = Color(0.7, 0.7, 1.0, 1.0)
	else:
		modulate = Color.WHITE

func _process_combat(delta):
	if !unit_data.has("attackType") or unit_data.attackType == "none":
		return

	if cooldown > 0:
		cooldown -= delta
		return

	if stats and stats.attack_cost_mana > 0:
		var GameManager = get_node_or_null("/root/GameManager")
		if GameManager and !GameManager.check_resource("mana", stats.attack_cost_mana):
			is_no_mana = true
			return
		else:
			is_no_mana = false

	var GameManager = get_node_or_null("/root/GameManager")
	var combat_manager = GameManager.combat_manager if GameManager else null
	if !combat_manager: return

	var target = combat_manager.find_nearest_enemy(global_position, stats.range_val)
	if !target: return

	if unit_data.attackType == "melee":
		if combat: combat._do_melee_attack(target)
	else:
		if combat: combat._do_standard_ranged_attack(target)

func play_attack_anim(attack_type: String, target_pos: Vector2, duration: float = -1.0):
	if visual: visual.play_attack_anim(attack_type, target_pos, duration)

func get_interaction_info() -> Dictionary:
	var info = { "has_interaction": false, "buff_id": "" }
	if unit_data.has("has_interaction") and unit_data.has_interaction:
		info.has_interaction = true
		info.buff_id = unit_data.get("buff_id", "")
	return info

func start_breathe_anim():
	if visual: visual.start_breathe_anim()

func can_merge_with(other_unit) -> bool:
	if other_unit == null: return false
	if other_unit == self: return false
	if other_unit.type_key != type_key: return false
	if other_unit.level != level: return false
	if level >= MAX_LEVEL: return false
	return true

func merge_with(other_unit):
	var old_level = level
	merged.emit(other_unit)
	level += 1
	reset_stats()
	stats.heal(stats.max_hp) # Full heal on level up using component

	if get_tree().root.has_node("GameManager"):
		get_node("/root/GameManager").unit_upgraded.emit(self, old_level, level)
		get_node("/root/GameManager").spawn_floating_text(global_position, "Level Up!", Color.GOLD)
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)

func devour(food_unit):
	var old_level = level
	level += 1
	stats.damage += 5 # Update through component
	stats_multiplier += 0.2
	update_visuals()
	if get_tree().root.has_node("GameManager"):
		get_node("/root/GameManager").unit_upgraded.emit(self, old_level, level)

func _on_area_2d_input_event(viewport, event, shape_idx):
	if interact: interact._on_area_2d_input_event(viewport, event, shape_idx)

func _on_area_2d_mouse_entered():
	if interact: interact._on_area_2d_mouse_entered()

func _on_area_2d_mouse_exited():
	if interact: interact._on_area_2d_mouse_exited()

func _draw():
	if visual: visual.draw_highlight(is_hovered, is_force_highlighted, _is_skill_highlight_active, _highlight_color)

func _get_neighbor_units() -> Array:
	var list = []
	if !GameManager.grid_manager: return list

	var cx = grid_pos.x
	var cy = grid_pos.y
	var w = unit_data.size.x
	var h = unit_data.size.y

	var neighbors_pos = []
	for dx in range(-1, w + 1):
		neighbors_pos.append(Vector2i(cx + dx, cy - 1))
		neighbors_pos.append(Vector2i(cx + dx, cy + h))
	for dy in range(0, h):
		neighbors_pos.append(Vector2i(cx - 1, cy + dy))
		neighbors_pos.append(Vector2i(cx + w, cy + dy))

	for n_pos in neighbors_pos:
		var key = GameManager.grid_manager.get_tile_key(n_pos.x, n_pos.y)
		if GameManager.grid_manager.tiles.has(key):
			var tile = GameManager.grid_manager.tiles[key]
			var u = tile.unit
			if u == null and tile.occupied_by != Vector2i.ZERO:
				var origin_key = GameManager.grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if GameManager.grid_manager.tiles.has(origin_key):
					u = GameManager.grid_manager.tiles[origin_key].unit

			if u and is_instance_valid(u) and not (u in list):
				list.append(u)
	return list

func _input(event):
	if is_dragging:
		if event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			end_drag()

func start_drag(mouse_pos_global):
	if interact: interact.start_drag(mouse_pos_global)

func end_drag():
	if interact: interact.end_drag()

func return_to_start():
	if interact: interact.return_to_start()

func heal(amount: float):
	if stats:
		stats.current_hp = min(stats.current_hp + amount, stats.max_hp)
	GameManager.spawn_floating_text(global_position, "+%d" % int(amount), Color.GREEN)

func play_buff_receive_anim():
	if visual: visual.play_buff_receive_anim()

func spawn_buff_effect(icon_char: String):
	if visual: visual.spawn_buff_effect(icon_char)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			if stats: stats.atk_speed *= (1.0 + amount)
		"defense":
			# No defense stat on unit currently?
			pass
		"move_speed":
			# Units don't move.
			pass
		"crit_chance":
			if stats: stats.crit_rate += amount

func add_temporary_buff(stat: String, amount: float, duration: float):
	temporary_buffs.append({
		"stat": stat,
		"amount": amount,
		"duration": duration
	})
	_apply_temp_buff_effect(stat, amount)

func _update_temporary_buffs(delta: float):
	for i in range(temporary_buffs.size() - 1, -1, -1):
		var buff = temporary_buffs[i]
		buff["duration"] -= delta
		if buff["duration"] <= 0:
			_remove_temp_buff_effect(buff["stat"], buff["amount"])
			temporary_buffs.remove_at(i)

func _apply_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			if stats: stats.atk_speed *= (1.0 + amount)
		"crit_chance":
			if stats: stats.crit_rate += amount

func _remove_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			if stats: stats.atk_speed /= (1.0 + amount)
		"crit_chance":
			if stats: stats.crit_rate -= amount

# 获取指定范围内的友方单位
# center_unit: 中心单位（通常是self）
# cell_range: 格子范围（曼哈顿距离）
# returns: 范围内友方单位数组（不包含自己）
func get_units_in_cell_range(center_unit: Node2D, cell_range: int) -> Array:
	var result = []
	if not GameManager.grid_manager:
		return result

	var center_x = 0
	var center_y = 0

	if "grid_pos" in center_unit:
		center_x = center_unit.grid_pos.x
		center_y = center_unit.grid_pos.y
	else:
		return result

	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		if tile.unit and is_instance_valid(tile.unit) and tile.unit != self:
			# 计算曼哈顿距离
			var dist = abs(tile.x - center_x) + abs(tile.y - center_y)
			if dist <= cell_range:
				result.append(tile.unit)

	return result
func add_buff(buff_type: String, source_unit: Node2D):
	if buff_manager: buff_manager.add_buff(buff_type, source_unit)

func remove_buff(buff_type: String):
	if buff_manager: buff_manager.remove_buff(buff_type)
