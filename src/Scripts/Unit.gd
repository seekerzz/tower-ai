class_name Unit
extends Node2D

const UnitBehavior = preload("res://src/Scripts/Units/UnitBehavior.gd")

var is_summoned: bool = false
var type_key: String
var level: int = 1
var stats_multiplier: float = 1.0
var cooldown: float = 0.0
var skill_cooldown: float = 0.0
var active_buffs: Array = []
var buff_sources: Dictionary = {} # Key: buff_type, Value: source_unit (Node2D)
var temporary_buffs: Array = [] # Array of {stat, amount, duration, source}
var traits: Array = []
var unit_data: Dictionary

var behavior: UnitBehavior

var attachment: Node2D = null
var host: Node2D = null

# Stats
var damage: float
var range_val: float
var atk_speed: float
var attack_cost_mana: float = 0.0
var skill_mana_cost: float = 30.0

var max_hp: float = 0.0
var current_hp: float = 0.0

var is_no_mana: bool = false
var crit_rate: float = 0.0
var crit_dmg: float = 1.5
var bounce_count: int = 0
var split_count: int = 0

var guaranteed_crit_stacks: int = 0

# Grid
var grid_pos = null # Vector2i or null

# Interaction state variables
var interaction_target_pos = null # Vector2i or null
var associated_traps: Array = [] # Stores references to traps placed by this unit
var focus_target: Node2D = null
var focus_stacks: int = 0

const MAX_LEVEL = 3

signal unit_clicked(unit)
signal attack_performed(target_node)
signal merged(consumed_unit)
signal damage_taken()
signal damage_blocked(damage: float, source: Node)
signal mouse_entered()
signal mouse_exited()

var UnitVisualsClass = preload("res://src/Scripts/Components/UnitVisuals.gd")
var UnitInteractionClass = preload("res://src/Scripts/Components/UnitInteraction.gd")
var visuals_component: Node2D
var interaction_component: Node2D

func _start_skill_cooldown(base_duration: float):
	if get_node("/root/GameManager").cheat_fast_cooldown and base_duration > 1.0:
		skill_cooldown = 1.0
	else:
		skill_cooldown = base_duration * get_node("/root/GameManager").get_stat_modifier("cooldown")

func _ready():
	visuals_component = UnitVisualsClass.new()
	add_child(visuals_component)

	interaction_component = UnitInteractionClass.new()
	add_child(interaction_component)

	tree_exiting.connect(_on_cleanup)

	if !unit_data.is_empty():
		visuals_component.update_visuals()

func _on_cleanup():
	if behavior:
		behavior.on_cleanup()

func setup(key: String):
	type_key = key
	unit_data = get_node("/root/Constants").UNIT_TYPES[key].duplicate()

	_load_behavior()

	reset_stats()
	current_hp = max_hp
	behavior.on_setup()

	visuals_component.update_visuals()
	visuals_component.start_breathe_anim()

func _load_behavior():
	var behavior_name = type_key.to_pascal_case()
	var path = "res://src/Scripts/Units/Behaviors/%s.gd" % behavior_name
	var script_res = null

	if ResourceLoader.exists(path):
		script_res = load(path)
	else:
		script_res = load("res://src/Scripts/Units/Behaviors/DefaultBehavior.gd")

	behavior = script_res.new(self)

func take_damage(amount: float, source_enemy = null):
	var original_amount = amount

	if "guardian_shield" in active_buffs:
		var source = buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			amount = amount * (1.0 - reduction)

	amount = behavior.on_damage_taken(amount, source_enemy)

	var blocked_amount = original_amount - amount
	if blocked_amount > 0:
		damage_blocked.emit(blocked_amount, source_enemy)

	current_hp = max(0, current_hp - amount)
	get_node("/root/GameManager").damage_core(amount)

	damage_taken.emit()

func reset_stats():
	var stats = {}
	if unit_data.has("levels") and unit_data["levels"].has(str(level)):
		stats = unit_data["levels"][str(level)]
	else:
		stats = unit_data

	damage = stats.get("damage", unit_data.get("damage", 0))
	max_hp = stats.get("hp", unit_data.get("hp", 0))
	if current_hp > max_hp: current_hp = max_hp

	range_val = unit_data.get("range", 0)
	atk_speed = unit_data.get("atkSpeed", 1.0)

	crit_rate = unit_data.get("crit_rate", 0.1)
	crit_dmg = unit_data.get("crit_dmg", 1.5)

	attack_cost_mana = unit_data.get("manaCost", 0.0)
	skill_mana_cost = unit_data.get("skillCost", 30.0)

	if stats.has("mechanics"):
		var mechs = stats["mechanics"]
		if mechs.has("crit_rate_bonus"):
			crit_rate += mechs["crit_rate_bonus"]

	bounce_count = 0
	split_count = 0
	active_buffs.clear()
	buff_sources.clear()

	if get_node("/root/GameManager").reward_manager and "focus_fire" in get_node("/root/GameManager").reward_manager.acquired_artifacts:
		range_val *= 1.2

	if behavior:
		behavior.on_stats_updated()

	if visuals_component:
		visuals_component.update_visuals()

func capture_bullet(bullet_snapshot: Dictionary):
	if behavior.has_method("capture_bullet"):
		behavior.capture_bullet(bullet_snapshot)

func calculate_damage_against(target_node: Node2D) -> float:
	var final_damage = damage

	if get_node("/root/GameManager").reward_manager and "focus_fire" in get_node("/root/GameManager").reward_manager.acquired_artifacts:
		if target_node == focus_target:
			focus_stacks = min(focus_stacks + 1, 10)
		else:
			focus_target = target_node
			focus_stacks = 0

		final_damage *= (1.0 + 0.05 * focus_stacks)

	final_damage *= get_node("/root/GameManager").get_stat_modifier("damage")

	return final_damage

func apply_buff(buff_type: String, source_unit: Node2D = null):
	var is_stackable = buff_type == "bounce" or buff_type == "split"
	var is_new_buff = not (buff_type in active_buffs)

	if buff_type in active_buffs and not is_stackable: return

	if is_new_buff:
		active_buffs.append(buff_type)

	if source_unit:
		buff_sources[buff_type] = source_unit

	var ailogger = get_node_or_null("/root/AILogger")
	var aimanager = get_node_or_null("/root/AIManager")

	if ailogger:
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
			ailogger.event(buff_msg)
			if aimanager:
				aimanager.broadcast_text(buff_msg)
		elif is_stackable:
			var current_stacks = bounce_count if buff_type == "bounce" else split_count
			var stack_msg = "[BUFF_STACK] %s %s Buff叠加 | 目标: %s | 当前层数: %d | 效果: %s" % [source_name, buff_type, target_name, current_stacks + 1, effect_desc]
			ailogger.event(stack_msg)
			if aimanager:
				aimanager.broadcast_text(stack_msg)

	if get_node("/root/GameManager").has_signal("buff_applied"):
		var amount = 0.0
		match buff_type:
			"range": amount = 1.25
			"speed": amount = 1.2
			"crit": amount = 0.25
			"bounce": amount = 1.0
			"split": amount = 1.0
			"forest_blessing": amount = 1.0
			"guardian_shield": amount = 1.0
		get_node("/root/GameManager").buff_applied.emit(self, buff_type, source_unit, amount)

	match buff_type:
		"range":
			range_val *= 1.25
		"speed":
			atk_speed *= 1.2
		"crit":
			crit_rate += 0.25
		"bounce":
			bounce_count += 1
		"split":
			split_count += 1

func execute_skill_at(grid_pos: Vector2i):
	if skill_cooldown > 0: return
	if not unit_data.has("skill"): return

	var final_cost = skill_mana_cost
	var cost_reduction = get_node("/root/GameManager").get_global_buff("skill_mana_cost_reduction", 0.0)
	if cost_reduction > 0:
		final_cost *= (1.0 - cost_reduction)

	if get_node("/root/GameManager").consume_resource("mana", final_cost):
		is_no_mana = false
		_start_skill_cooldown(unit_data.get("skillCd", 10.0))

		var skill_name = unit_data.skill
		get_node("/root/GameManager").spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		get_node("/root/GameManager").skill_activated.emit(self)

		behavior.on_skill_executed_at(grid_pos)

	else:
		is_no_mana = true
		get_node("/root/GameManager").spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func add_crit_stacks(amount: int):
	guaranteed_crit_stacks += amount
	get_node("/root/GameManager").spawn_floating_text(global_position, "Crit Ready!", Color.ORANGE)

func _on_skill_ended():
	if interaction_component:
		interaction_component.set_highlight(false)

func activate_skill():
	if !unit_data.has("skill"): return
	if skill_cooldown > 0: return

	behavior.on_skill_activated()

	if unit_data.get("skillType") == "point":
		return

	var final_cost = skill_mana_cost
	if get_node("/root/GameManager").skill_cost_reduction > 0:
		final_cost *= (1.0 - get_node("/root/GameManager").skill_cost_reduction)

	if get_node("/root/GameManager").consume_resource("mana", final_cost):
		is_no_mana = false
		_start_skill_cooldown(unit_data.get("skillCd", 10.0))

		var skill_name = unit_data.skill
		get_node("/root/GameManager").spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		get_node("/root/GameManager").skill_activated.emit(self)

		var ailogger = get_node_or_null("/root/AILogger")
		if ailogger:
			ailogger.action("[技能] %s(Lv%d) 使用了技能: %s (消耗%.0f法力)" % [type_key, level, skill_name, final_cost])

		if visuals_component:
			visuals_component.play_skill_activation_anim()

	else:
		is_no_mana = true
		get_node("/root/GameManager").spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func _process(delta):
	var is_wave_active = get_node("/root/GameManager").session_data.is_wave_active if get_node("/root/GameManager").session_data else false

	if !is_wave_active: return
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

	if attack_cost_mana > 0:
		if !get_node("/root/GameManager").check_resource("mana", attack_cost_mana):
			is_no_mana = true
			return
		else:
			is_no_mana = false

	var combat_manager = get_node("/root/GameManager").combat_manager
	if !combat_manager: return

	var target = combat_manager.find_nearest_enemy(global_position, range_val)
	if !target: return

	if unit_data.attackType == "melee":
		_do_melee_attack(target)
	else:
		_do_standard_ranged_attack(target)

func _do_melee_attack(target):
	var target_last_pos = target.global_position

	if attack_cost_mana > 0:
		get_node("/root/GameManager").consume_resource("mana", attack_cost_mana)

	cooldown = atk_speed * get_node("/root/GameManager").get_stat_modifier("attack_interval")

	if visuals_component:
		visuals_component.play_attack_anim("melee", target_last_pos)

	if !is_instance_valid(self): return

	if is_instance_valid(target):
		_spawn_melee_projectiles(target)
		attack_performed.emit(target)

		var ailogger = get_node_or_null("/root/AILogger")
		var aimanager = get_node_or_null("/root/AIManager")
		if ailogger:
			var target_name = target.type_key if target and "type_key" in target else "目标"
			var damage_val = unit_data.get("damage", 0)
			var wave_info = get_node("/root/GameManager").session_data.wave if get_node("/root/GameManager").session_data else 1
			ailogger.unit_attack(type_key, target_name, damage_val)
			ailogger.event("[单位攻击] 波次%d | %s 攻击 %s，伤害 %.0f" % [
				wave_info, type_key, target_name, damage_val
			])
			if aimanager:
				aimanager.broadcast_text("【单位攻击】波次%d | %s 攻击 %s，伤害 %.0f" % [
					wave_info, type_key, target_name, damage_val
				])
	else:
		_spawn_melee_projectiles_blind(target_last_pos)
		attack_performed.emit(null)

func _spawn_melee_projectiles_blind(target_pos: Vector2):
	var combat_manager = get_node("/root/GameManager").combat_manager
	if !combat_manager: return

	var swing_hit_list = []
	var attack_dir = (target_pos - global_position).normalized()

	var proj_speed = 600.0
	var proj_life = (range_val + 30.0) / proj_speed
	var count = 5
	var spread = PI / 2.0

	var base_angle = attack_dir.angle()
	var start_angle = base_angle - spread / 2.0
	var step = spread / max(1, count - 1)

	for i in range(count):
		var angle = start_angle + (i * step)
		var stats = {
			"pierce": 100,
			"hide_visuals": true,
			"life": proj_life,
			"angle": angle,
			"speed": proj_speed,
			"shared_hit_list": swing_hit_list
		}
		combat_manager.spawn_projectile(self, global_position, null, stats)

func _spawn_melee_projectiles(target: Node2D):
	var combat_manager = get_node("/root/GameManager").combat_manager
	if !combat_manager: return

	var swing_hit_list = []
	var attack_dir = (target.global_position - global_position).normalized()

	var proj_speed = 600.0
	var proj_life = (range_val + 30.0) / proj_speed
	var count = 5
	var spread = PI / 2.0

	var base_angle = attack_dir.angle()
	var start_angle = base_angle - spread / 2.0
	var step = spread / max(1, count - 1)

	for i in range(count):
		var angle = start_angle + (i * step)
		var stats = {
			"pierce": 100,
			"hide_visuals": true,
			"life": proj_life,
			"angle": angle,
			"speed": proj_speed,
			"shared_hit_list": swing_hit_list
		}
		combat_manager.spawn_projectile(self, global_position, null, stats)

func _do_standard_ranged_attack(target):
	var combat_manager = get_node("/root/GameManager").combat_manager
	if !combat_manager: return

	if attack_cost_mana > 0:
		get_node("/root/GameManager").consume_resource("mana", attack_cost_mana)

	cooldown = atk_speed * get_node("/root/GameManager").get_stat_modifier("attack_interval")

	if unit_data.get("proj") == "lightning":
		if visuals_component:
			visuals_component.play_attack_anim("lightning", target.global_position)
		combat_manager.perform_lightning_attack(self, global_position, target, unit_data.get("chain", 0))
		return

	if visuals_component:
		visuals_component.play_attack_anim("ranged", target.global_position)

	var proj_count = unit_data.get("projCount", 1)
	var spread = unit_data.get("spread", 0.5)

	if "multishot" in active_buffs:
		proj_count += 2
		spread = max(spread, 0.5)

	if proj_count == 1:
		combat_manager.spawn_projectile(self, global_position, target)
		attack_performed.emit(target)
	else:
		var base_angle = (target.global_position - global_position).angle()
		var start_angle = base_angle - spread / 2.0
		var step = spread / max(1, proj_count - 1)

		for i in range(proj_count):
			var angle = start_angle + (i * step)
			combat_manager.spawn_projectile(self, global_position, target, {"angle": angle})

	attack_performed.emit(target)

	var ailogger = get_node_or_null("/root/AILogger")
	var aimanager = get_node_or_null("/root/AIManager")
	if ailogger:
		var target_name = target.type_key if target and "type_key" in target else "目标"
		var damage_val = unit_data.get("damage", 0)
		var wave_info = get_node("/root/GameManager").session_data.wave if get_node("/root/GameManager").session_data else 1
		ailogger.unit_attack(type_key, target_name, damage_val)
		ailogger.event("[单位攻击] 波次%d | %s 攻击 %s，伤害 %.0f" % [
			wave_info, type_key, target_name, damage_val
		])
		if aimanager:
			aimanager.broadcast_text("【单位攻击】波次%d | %s 攻击 %s，伤害 %.0f" % [
				wave_info, type_key, target_name, damage_val
			])

func get_interaction_info() -> Dictionary:
	var info = { "has_interaction": false, "buff_id": "" }
	if unit_data.has("has_interaction") and unit_data.has_interaction:
		info.has_interaction = true
		info.buff_id = unit_data.get("buff_id", "")
	return info

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
	current_hp = max_hp

	get_node("/root/GameManager").unit_upgraded.emit(self, old_level, level)
	get_node("/root/GameManager").spawn_floating_text(global_position, "Level Up!", Color.GOLD)
	if visuals_component:
		visuals_component.play_level_up_anim()

func devour(food_unit):
	var old_level = level
	level += 1
	damage += 5
	stats_multiplier += 0.2
	if visuals_component:
		visuals_component.update_visuals()
	get_node("/root/GameManager").unit_upgraded.emit(self, old_level, level)

func _on_area_2d_input_event(viewport, event, shape_idx):
	var is_wave_active = get_node("/root/GameManager").session_data.is_wave_active if get_node("/root/GameManager").session_data else false
	if !is_wave_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unit_clicked.emit(self)

func _on_area_2d_mouse_entered():
	mouse_entered.emit()

func _on_area_2d_mouse_exited():
	mouse_exited.emit()

func _get_neighbor_units() -> Array:
	var list = []
	if !get_node("/root/GameManager").grid_manager: return list

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
		var key = get_node("/root/GameManager").grid_manager.get_tile_key(n_pos.x, n_pos.y)
		if get_node("/root/GameManager").grid_manager.tiles.has(key):
			var tile = get_node("/root/GameManager").grid_manager.tiles[key]
			var u = tile.unit
			if u == null and tile.occupied_by != Vector2i.ZERO:
				var origin_key = get_node("/root/GameManager").grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if get_node("/root/GameManager").grid_manager.tiles.has(origin_key):
					u = get_node("/root/GameManager").grid_manager.tiles[origin_key].unit

			if u and is_instance_valid(u) and not (u in list):
				list.append(u)
	return list

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	get_node("/root/GameManager").spawn_floating_text(global_position, "+%d" % int(amount), Color.GREEN)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"defense":
			pass
		"move_speed":
			pass
		"crit_chance":
			crit_rate += amount

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
			atk_speed *= (1.0 + amount)
		"crit_chance":
			crit_rate += amount

func _remove_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed /= (1.0 + amount)
		"crit_chance":
			crit_rate -= amount

func get_units_in_cell_range(center_unit: Node2D, cell_range: int) -> Array:
	var result = []
	if not get_node("/root/GameManager").grid_manager:
		return result

	var center_x = 0
	var center_y = 0

	if "grid_pos" in center_unit:
		center_x = center_unit.grid_pos.x
		center_y = center_unit.grid_pos.y
	else:
		return result

	for key in get_node("/root/GameManager").grid_manager.tiles:
		var tile = get_node("/root/GameManager").grid_manager.tiles[key]
		if tile.unit and is_instance_valid(tile.unit) and tile.unit != self:
			var dist = abs(tile.x - center_x) + abs(tile.y - center_y)
			if dist <= cell_range:
				result.append(tile.unit)

	return result
