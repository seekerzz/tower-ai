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
var traits: Array = []
var unit_data: Dictionary

var behavior: UnitBehavior

var attachment: Node2D = null
var host: Node2D = null

# Components
var stats_component
var buff_component
var combat_component
var visual_component
var interaction_component

const UNIT_STATS_COMPONENT = preload("res://src/Scripts/Components/UnitStatsComponent.gd")
const UNIT_BUFF_COMPONENT = preload("res://src/Scripts/Components/UnitBuffComponent.gd")
const UNIT_COMBAT_COMPONENT = preload("res://src/Scripts/Components/UnitCombatComponent.gd")
const UNIT_VISUAL_COMPONENT = preload("res://src/Scripts/Components/UnitVisualComponent.gd")
const UNIT_INTERACTION_COMPONENT = preload("res://src/Scripts/Components/UnitInteractionComponent.gd")

# Proxy properties to components to avoid breaking other files
var damage: float:
	get: return stats_component.damage if stats_component else 0.0
	set(v): if stats_component: stats_component.damage = v
var range_val: float:
	get: return stats_component.range_val if stats_component else 0.0
	set(v): if stats_component: stats_component.range_val = v
var atk_speed: float:
	get: return stats_component.atk_speed if stats_component else 0.0
	set(v): if stats_component: stats_component.atk_speed = v
var attack_cost_mana: float:
	get: return stats_component.attack_cost_mana if stats_component else 0.0
	set(v): if stats_component: stats_component.attack_cost_mana = v
var skill_mana_cost: float:
	get: return stats_component.skill_mana_cost if stats_component else 0.0
	set(v): if stats_component: stats_component.skill_mana_cost = v
var max_hp: float:
	get: return stats_component.max_hp if stats_component else 0.0
	set(v): if stats_component: stats_component.max_hp = v
var current_hp: float:
	get: return stats_component.current_hp if stats_component else 0.0
	set(v): if stats_component: stats_component.current_hp = v
var crit_rate: float:
	get: return stats_component.crit_rate if stats_component else 0.0
	set(v): if stats_component: stats_component.crit_rate = v
var crit_dmg: float:
	get: return stats_component.crit_dmg if stats_component else 1.5
	set(v): if stats_component: stats_component.crit_dmg = v

var active_buffs: Array:
	get: return buff_component.active_buffs if buff_component else []
var buff_sources: Dictionary:
	get: return buff_component.buff_sources if buff_component else {}
var temporary_buffs: Array:
	get: return buff_component.temporary_buffs if buff_component else []

var bounce_count: int:
	get: return buff_component.bounce_count if buff_component else 0
	set(v): if buff_component: buff_component.bounce_count = v
var split_count: int:
	get: return buff_component.split_count if buff_component else 0
	set(v): if buff_component: buff_component.split_count = v

# Visual Holder for animations and structure
var visual_holder: Node2D = null

var is_no_mana: bool = false
var guaranteed_crit_stacks: int = 0

# Grid
var grid_pos: Vector2i = Vector2i.ZERO
var start_position: Vector2:
	get: return interaction_component.start_position if interaction_component else Vector2.ZERO
	set(v): if interaction_component: interaction_component.start_position = v

# Interaction
var interaction_target_pos = null # Vector2i or null
var associated_traps: Array = [] # Stores references to traps placed by this unit

# Dragging
var is_dragging: bool:
	get: return interaction_component.is_dragging if interaction_component else false
	set(v): if interaction_component: interaction_component.is_dragging = v
var drag_offset: Vector2:
	get: return interaction_component.drag_offset if interaction_component else Vector2.ZERO
	set(v): if interaction_component: interaction_component.drag_offset = v
var ghost_node: Node2D:
	get: return interaction_component.ghost_node if interaction_component else null
	set(v): if interaction_component: interaction_component.ghost_node = v
var is_hovered: bool:
	get: return interaction_component.is_hovered if interaction_component else false
	set(v): if interaction_component: interaction_component.is_hovered = v
var focus_target: Node2D = null
var focus_stacks: int = 0

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
	stats_component = UNIT_STATS_COMPONENT.new(self)
	buff_component = UNIT_BUFF_COMPONENT.new(self)
	combat_component = UNIT_COMBAT_COMPONENT.new(self)
	visual_component = UNIT_VISUAL_COMPONENT.new(self)
	interaction_component = UNIT_INTERACTION_COMPONENT.new(self)

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

	_load_behavior()

	reset_stats()
	current_hp = max_hp
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
	if visual_component:
		visual_component.ensure_visual_hierarchy()

func take_damage(amount: float, source_enemy = null):
	if stats_component:
		stats_component.take_damage(amount, source_enemy)

	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "position", Vector2(randf_range(-2,2), randf_range(-2,2)), 0.05).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(visual_holder, "position", Vector2.ZERO, 0.05)

func reset_stats():
	if stats_component:
		stats_component.reset_stats()
	if buff_component:
		buff_component.clear()

	if behavior:
		behavior.on_stats_updated()

	update_visuals()

func capture_bullet(bullet_snapshot: Dictionary):
	if behavior.has_method("capture_bullet"):
		behavior.capture_bullet(bullet_snapshot)

func calculate_damage_against(target_node: Node2D) -> float:
	var final_damage = damage

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
	if buff_component:
		buff_component.apply_buff(buff_type, source_unit)

func set_highlight(active: bool, color: Color = Color.WHITE):
	_is_skill_highlight_active = active
	_highlight_color = color
	queue_redraw()

func set_force_highlight(active: bool):
	is_force_highlighted = active
	queue_redraw()

func execute_skill_at(grid_pos: Vector2i):
	if skill_cooldown > 0: return
	if not unit_data.has("skill"): return

	var final_cost = skill_mana_cost
	var cost_reduction = GameManager.get_global_buff("skill_mana_cost_reduction", 0.0)
	if cost_reduction > 0:
		final_cost *= (1.0 - cost_reduction)

	if GameManager.consume_resource("mana", final_cost):
		is_no_mana = false
		_start_skill_cooldown(unit_data.get("skillCd", 10.0))

		var skill_name = unit_data.skill
		GameManager.spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(self)

		behavior.on_skill_executed_at(grid_pos)

	else:
		is_no_mana = true
		GameManager.spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func add_crit_stacks(amount: int):
	guaranteed_crit_stacks += amount
	GameManager.spawn_floating_text(global_position, "Crit Ready!", Color.ORANGE)

func _on_skill_ended():
	set_highlight(false)

func activate_skill():
	if !unit_data.has("skill"): return
	if skill_cooldown > 0: return

	behavior.on_skill_activated()

	if unit_data.get("skillType") == "point":
		# Behavior handles targeting initiation
		return

	var final_cost = skill_mana_cost
	if GameManager.skill_cost_reduction > 0:
		final_cost *= (1.0 - GameManager.skill_cost_reduction)

	if GameManager.consume_resource("mana", final_cost):
		is_no_mana = false
		_start_skill_cooldown(unit_data.get("skillCd", 10.0))

		var skill_name = unit_data.skill
		GameManager.spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(self)
		# 中文技能日志
		if AILogger:
			AILogger.action("[技能] %s(Lv%d) 使用了技能: %s (消耗%.0f法力)" % [type_key, level, skill_name, final_cost])

		if visual_holder:
			var tween = create_tween()
			tween.tween_property(visual_holder, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1)

	else:
		is_no_mana = true
		GameManager.spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func update_visuals():
	if visual_component:
		visual_component.update_visuals()

func _process(delta):
	if !GameManager.is_wave_active: return
	if not behavior: return

	behavior.on_tick(delta)

	_update_temporary_buffs(delta)

	if !behavior.on_combat_tick(delta):
		if combat_component:
			combat_component.process_combat(delta)

	if skill_cooldown > 0:
		skill_cooldown -= delta

	if is_no_mana and unit_data.has("skill"):
		modulate = Color(0.7, 0.7, 1.0, 1.0)
	else:
		modulate = Color.WHITE

func play_attack_anim(attack_type: String, target_pos: Vector2, duration: float = -1.0):
	if visual_component:
		visual_component.play_attack_anim(attack_type, target_pos, duration)

func get_interaction_info() -> Dictionary:
	var info = { "has_interaction": false, "buff_id": "" }
	if unit_data.has("has_interaction") and unit_data.has_interaction:
		info.has_interaction = true
		info.buff_id = unit_data.get("buff_id", "")
	return info

func start_breathe_anim():
	if visual_component:
		visual_component.start_breathe_anim()

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
	current_hp = max_hp # Full heal on level up

	GameManager.unit_upgraded.emit(self, old_level, level)
	GameManager.spawn_floating_text(global_position, "Level Up!", Color.GOLD)
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)

func devour(food_unit):
	var old_level = level
	level += 1
	damage += 5
	stats_multiplier += 0.2
	update_visuals()
	GameManager.unit_upgraded.emit(self, old_level, level)

func _on_area_2d_input_event(viewport, event, shape_idx):
	if interaction_component:
		interaction_component.on_area_2d_input_event(viewport, event, shape_idx)

func _on_area_2d_mouse_entered():
	if interaction_component:
		interaction_component.on_area_2d_mouse_entered()

func _on_area_2d_mouse_exited():
	if interaction_component:
		interaction_component.on_area_2d_mouse_exited()

func _draw():
	if is_hovered:
		var draw_radius = range_val
		if unit_data.get("attackType") == "melee":
			draw_radius = max(range_val, 100.0)

		draw_circle(Vector2.ZERO, draw_radius, Color(1, 1, 1, 0.1))
		draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)

	if _is_skill_highlight_active:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit_data and unit_data.has("size"):
			size = Vector2(unit_data.size.x * Constants.TILE_SIZE, unit_data.size.y * Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		draw_rect(rect, _highlight_color, false, 4.0)

	if is_force_highlighted:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit_data and unit_data.has("size"):
			size = Vector2(unit_data.size.x * Constants.TILE_SIZE, unit_data.size.y * Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		draw_rect(rect, Color.WHITE, false, 4.0)

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
	if interaction_component:
		interaction_component.handle_input(event)

func start_drag(mouse_pos_global):
	if interaction_component:
		interaction_component.start_drag(mouse_pos_global)

func end_drag():
	if interaction_component:
		interaction_component.end_drag()

func create_ghost():
	if interaction_component:
		interaction_component.create_ghost()

func remove_ghost():
	if interaction_component:
		interaction_component.remove_ghost()

func return_to_start():
	if interaction_component:
		interaction_component.return_to_start()

func _find_empty_bench_slot() -> int:
	if interaction_component:
		return interaction_component._find_empty_bench_slot()
	return -1

func heal(amount: float):
	if stats_component:
		stats_component.heal(amount)

func play_buff_receive_anim():
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func spawn_buff_effect(icon_char: String):
	var effect_node = Node2D.new()
	effect_node.name = "BuffEffect"
	effect_node.z_index = 101

	var lbl = Label.new()
	lbl.text = icon_char
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.position = Vector2(-20, -20)
	lbl.size = Vector2(40, 40)

	effect_node.add_child(lbl)
	add_child(effect_node)

	effect_node.position = Vector2.ZERO

	var tween = create_tween()
	tween.tween_property(effect_node, "scale", Vector2(2.5, 2.5), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(effect_node, "modulate:a", 0.0, 0.6)

	tween.finished.connect(effect_node.queue_free)

func get_buff_icon(buff_type: String) -> String:
	if visual_component and visual_component.has_method("_get_buff_icon"):
		return visual_component._get_buff_icon(buff_type)
	return "?"

func add_stat_bonus(stat: String, amount: float):
	if stats_component:
		stats_component.add_stat_bonus(stat, amount)

func add_temporary_buff(stat: String, amount: float, duration: float):
	if buff_component:
		buff_component.add_temporary_buff(stat, amount, duration)

func _update_temporary_buffs(delta: float):
	if buff_component:
		buff_component._update_temporary_buffs(delta)

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
