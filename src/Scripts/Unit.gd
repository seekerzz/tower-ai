class_name Unit
extends Node2D

const UnitBehavior = preload("res://src/Scripts/Units/UnitBehavior.gd")

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

var skill_service
var progression_service
var spatial_query_service

const UNIT_STATS_COMPONENT = preload("res://src/Scripts/Components/UnitStatsComponent.gd")
const UNIT_BUFF_COMPONENT = preload("res://src/Scripts/Components/UnitBuffComponent.gd")
const UNIT_COMBAT_COMPONENT = preload("res://src/Scripts/Components/UnitCombatComponent.gd")
const UNIT_VISUAL_COMPONENT = preload("res://src/Scripts/Components/UnitVisualComponent.gd")
const UNIT_INTERACTION_COMPONENT = preload("res://src/Scripts/Components/UnitInteractionComponent.gd")
const UNIT_SKILL_SERVICE = preload("res://src/Scripts/Services/UnitSkillService.gd")
const UNIT_PROGRESSION_SERVICE = preload("res://src/Scripts/Services/UnitProgressionService.gd")
const UNIT_SPATIAL_QUERY_SERVICE = preload("res://src/Scripts/Services/UnitSpatialQueryService.gd")
const DamageContext = preload("res://src/Scripts/CoreMechanics/DamageContext.gd")

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
	skill_service = UNIT_SKILL_SERVICE.new(self)
	progression_service = UNIT_PROGRESSION_SERVICE.new(self)
	spatial_query_service = UNIT_SPATIAL_QUERY_SERVICE.new(self)

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

func take_damage(amount: float, source_node = null):
	var context = DamageContext.new(source_node, self, amount)

	# Phase A: Hit Detection
	if stats_component:
		stats_component.process_hit_detection(context)
	if behavior:
		behavior.on_pre_damage_hit(context)

	if context.is_miss or context.is_dodge:
		var label = "Miss" if context.is_miss else "Dodge"
		print("[%s Debug] %s! (Source: %s)" % [name, label, context.source.name if context.source else "Unknown"])
		GameManager.spawn_floating_text(global_position, label, Color.GRAY)
		return

	# Phase B: Mitigation & Shield
	if stats_component:
		stats_component.process_mitigation(context)
	if behavior:
		behavior.on_calculate_mitigation(context)

	# Phase C: Application
	if stats_component:
		stats_component.apply_damage(context)
	if behavior:
		behavior.on_damage_applied(context)

	if visual_component:
		visual_component.play_damage_hit_anim()

	# Phase D: Feedback
	if behavior:
		behavior.on_post_damage_applied(context)

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
	if visual_component:
		visual_component.set_skill_highlight(active, color)

func set_force_highlight(active: bool):
	if visual_component:
		visual_component.set_force_highlight(active)

func execute_skill_at(grid_pos: Vector2i):
	if skill_service:
		skill_service.execute_skill_at(grid_pos)

func add_crit_stacks(amount: int):
	guaranteed_crit_stacks += amount
	GameManager.spawn_floating_text(global_position, "Crit Ready!", Color.ORANGE)

func _on_skill_ended():
	set_highlight(false)

func activate_skill():
	if skill_service:
		skill_service.activate_skill()

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
	if progression_service:
		return progression_service.can_merge_with(other_unit)
	return false

func merge_with(other_unit):
	if progression_service:
		progression_service.merge_with(other_unit)

func devour(food_unit):
	if progression_service:
		progression_service.devour(food_unit)

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
	if visual_component:
		visual_component.draw_overlays()

func _get_neighbor_units() -> Array:
	if spatial_query_service:
		return spatial_query_service.get_neighbor_units()
	return []

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
	if visual_component:
		visual_component.play_buff_receive_anim()
		return
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func spawn_buff_effect(icon_char: String):
	if visual_component:
		visual_component.spawn_buff_effect(icon_char)

func get_buff_icon(buff_type: String) -> String:
	if visual_component and visual_component.has_method("get_buff_icon"):
		return visual_component.get_buff_icon(buff_type)
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
	if spatial_query_service:
		return spatial_query_service.get_units_in_cell_range(center_unit, cell_range, self)
	return []
