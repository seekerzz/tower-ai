class_name Unit
extends Node2D

const UnitBehavior = preload("res://src/Scripts/Units/UnitBehavior.gd")
const UnitVisuals = preload("res://src/Scripts/Units/UnitVisuals.gd")
const UnitInteraction = preload("res://src/Scripts/Units/UnitInteraction.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")
const UnitCombat = preload("res://src/Scripts/Components/UnitCombat.gd")

var is_summoned: bool = false
var type_key: String
var level: int = 1
var stats_multiplier: float = 1.0

var active_buffs: Array = []
var buff_sources: Dictionary = {} # Key: buff_type, Value: source_unit (Node2D)
var temporary_buffs: Array = [] # Array of {stat, amount, duration, source}
var traits: Array = []
var unit_data: Dictionary

var behavior: UnitBehavior
var combat: UnitCombat

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
var grid_pos: Vector2i = Vector2i.ZERO
var start_position: Vector2 = Vector2.ZERO

# Interaction
var interaction_target_pos = null # Vector2i or null
var associated_traps: Array = [] # Stores references to traps placed by this unit

# Dragging
var focus_target: Node2D = null
var focus_stacks: int = 0

# Highlighting

const MAX_LEVEL = 3
const DRAG_HANDLER_SCRIPT = preload("res://src/Scripts/UI/UnitDragHandler.gd")

signal unit_clicked(unit)
signal attack_performed(target_node)
signal merged(consumed_unit)
signal damage_blocked(damage: float, source: Node)

signal on_damage_taken_visual()
signal attack_started_visual(attack_type: String, target_pos: Vector2, duration: float)
signal buff_received_visual()
signal level_up_visual()
signal skill_cast_visual()
signal visual_update_requested()
signal spawn_buff_effect_visual(icon_char: String)

signal interaction_mouse_entered()
signal interaction_mouse_exited()
signal interaction_input_event(viewport, event, shape_idx)
signal highlight_requested(active: bool, color: Color)
signal force_highlight_requested(active: bool)
signal drag_started(mouse_pos_global: Vector2)

var _unit_visuals = null
var _unit_interaction = null



func _start_skill_cooldown(base_duration: float):
	if combat:
		combat.start_skill_cooldown(base_duration, GameManager.cheat_fast_cooldown)

func _ready():
	combat = UnitCombat.new()
	combat.attack_performed.connect(_on_combat_attack_performed)
	combat.skill_activated.connect(_on_combat_skill_activated)
	combat.on_no_mana.connect(_on_combat_no_mana)

	_unit_visuals = UnitVisuals.new(self)
	add_child(_unit_visuals)

	_unit_interaction = UnitInteraction.new(self)
	add_child(_unit_interaction)

	tree_exiting.connect(_on_cleanup)

	if !unit_data.is_empty():
		visual_update_requested.emit()

func _on_cleanup():
	if behavior:
		behavior.on_cleanup()

func setup(key: String):
	type_key = key
	unit_data = Constants.UNIT_TYPES[key].duplicate()

	_load_behavior()

	reset_stats()
	current_hp = max_hp
	behavior.on_setup()

	visual_update_requested.emit()
	attack_started_visual.emit('breathe', Vector2.ZERO, 0.0)

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

func take_damage(amount: float, source_enemy = null):
	var original_amount = amount

	# 检查是否有guardian_shield buff，应用减伤
	if "guardian_shield" in active_buffs:
		var source = buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			amount = amount * (1.0 - reduction)

	amount = behavior.on_damage_taken(amount, source_enemy)

	# 计算被阻挡的伤害（来自spore shield等机制）
	var blocked_amount = original_amount - amount
	if blocked_amount > 0:
		damage_blocked.emit(blocked_amount, source_enemy)

	current_hp = max(0, current_hp - amount)
	GameManager.damage_core(amount)

	on_damage_taken_visual.emit()

func reset_stats():
	var stats = {}
	if unit_data.has("levels") and unit_data["levels"].has(str(level)):
		stats = unit_data["levels"][str(level)]
	else:
		stats = unit_data

	damage = stats.get("damage", unit_data.get("damage", 0))
	max_hp = stats.get("hp", unit_data.get("hp", 0))
	# Note: current_hp is NOT reset here to avoid full heal on level up,
	# but usually max_hp changes, so maybe we should proportional update?
	# For simplicity, we assume heal on level up (merge) or just clamp.
	if current_hp > max_hp: current_hp = max_hp
	# If max_hp increased, we don't necessarily heal, but we could.
	# Standard behavior: Keep current_hp, unless we want to "heal on upgrade".
	# Let's simple clamp.

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

	if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
		range_val *= 1.2

	if combat:
		combat.update_stats({
			"damage": damage,
			"range_val": range_val,
			"atk_speed": atk_speed,
			"attack_cost_mana": attack_cost_mana,
			"skill_mana_cost": skill_mana_cost,
			"skill_cd": unit_data.get("skillCd", 10.0),
			"attack_interval_modifier": GameManager.get_stat_modifier("attack_interval"),
			"cooldown_modifier": GameManager.get_stat_modifier("cooldown"),
			"skill_cost_reduction": GameManager.get_global_buff("skill_mana_cost_reduction", 0.0)
		})

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
			range_val *= 1.25
		"speed":
			atk_speed *= 1.2
		"crit":
			crit_rate += 0.25
		"bounce":
			bounce_count += 1
		"split":
			split_count += 1
		"guardian_shield":
			# 牦牛守护的减伤buff，效果在take_damage中处理
			pass

func execute_skill_at(grid_pos: Vector2i):
	if not unit_data.has("skill"): return

	# Pass targeting context before executing
	set_meta("pending_skill_target_pos", grid_pos)

	# Component handles the condition, cooldown and signals
	combat.execute_skill(GameManager.mana)

func add_crit_stacks(amount: int):
	guaranteed_crit_stacks += amount
	GameManager.spawn_floating_text(global_position, "Crit Ready!", Color.ORANGE)

func _on_skill_ended():
	set_highlight(false)

func activate_skill():
	if not unit_data.has("skill"): return

	if unit_data.get("skillType") == "point":
		if combat.skill_cooldown <= 0:
			behavior.on_skill_activated()
		return

	set_meta("pending_skill_target_pos", null)
	combat.execute_skill(GameManager.mana)

func _on_combat_no_mana():
	GameManager.spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func _on_combat_skill_activated(cost):
	if GameManager.consume_resource("mana", cost):
		var skill_name = unit_data.skill
		GameManager.spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(self)

		if AILogger:
			AILogger.action("[技能] %s(Lv%d) 使用了技能: %s (消耗%.0f法力)" % [type_key, level, skill_name, cost])

		skill_cast_visual.emit()

		var pending_pos = get_meta("pending_skill_target_pos", null)
		if pending_pos != null:
			behavior.on_skill_executed_at(pending_pos)
		else:
			behavior.on_skill_activated()

func _process(delta):
	# Debug: Check if _process is being called
	var debug_msg = "[UNIT DEBUG] _process called, behavior: %s" % (behavior != null)
	print(debug_msg)
	if AILogger and AIManager and AIManager.has_method("broadcast_text"):
		AILogger.event(debug_msg)
		AIManager.broadcast_text(debug_msg)

	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	var wave_msg = "[UNIT DEBUG] is_wave_active: %s" % is_wave_active
	print(wave_msg)
	if AILogger and AIManager and AIManager.has_method("broadcast_text"):
		AILogger.event(wave_msg)
		AIManager.broadcast_text(wave_msg)

	if !is_wave_active: return
	if not behavior: return

	behavior.on_tick(delta)

	_update_temporary_buffs(delta)

	if combat:
		combat.process_tick(delta)

	if !behavior.on_combat_tick(delta) and combat and unit_data.has("attackType") and unit_data.attackType != "none":
		var enemies = get_tree().get_nodes_in_group("enemies")
		combat.process_combat(delta, global_position, enemies, GameManager.mana)

	if combat and combat.is_no_mana and unit_data.has("skill"):
		modulate = Color(0.7, 0.7, 1.0, 1.0)
	else:
		modulate = Color.WHITE

func _on_combat_attack_performed(target):
	if unit_data.attackType == "melee":
		_do_melee_attack(target)
	else:
		_do_standard_ranged_attack(target)

func _do_melee_attack(target):
	var target_last_pos = target.global_position

	if attack_cost_mana > 0:
		GameManager.consume_resource("mana", attack_cost_mana)

	attack_started_visual.emit("melee", target_last_pos, -1.0)

	var timer = get_tree().create_timer(Constants.ANIM_WINDUP_TIME)
	await timer.timeout
	if !is_instance_valid(self): return

	if is_instance_valid(target):
		_spawn_melee_projectiles(target)
		attack_performed.emit(target)
		# 记录近战攻击日志
		if AILogger:
			var target_name = target.type_key if target and "type_key" in target else "目标"
			var damage = unit_data.get("damage", 0)
			var wave_info = GameManager.session_data.wave if GameManager.session_data else 1
			AILogger.unit_attack(type_key, target_name, damage)
			AILogger.event("[单位攻击] 波次%d | %s 攻击 %s，伤害 %.0f" % [
				wave_info, type_key, target_name, damage
			])
			if AIManager:
				AIManager.broadcast_text("【单位攻击】波次%d | %s 攻击 %s，伤害 %.0f" % [
					wave_info, type_key, target_name, damage
				])
	else:
		_spawn_melee_projectiles_blind(target_last_pos)
		attack_performed.emit(null)

func _spawn_melee_projectiles_blind(target_pos: Vector2):
	var combat_manager = GameManager.combat_manager
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
	var combat_manager = GameManager.combat_manager
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
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	if attack_cost_mana > 0:
		GameManager.consume_resource("mana", attack_cost_mana)

	if unit_data.get("proj") == "lightning":
		attack_started_visual.emit("lightning", target.global_position, -1.0)
		combat_manager.perform_lightning_attack(self, global_position, target, unit_data.get("chain", 0))
		return

	attack_started_visual.emit("ranged", target.global_position, -1.0)

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

	# 记录单位攻击日志（包含波次信息）
	if AILogger:
		var target_name = target.type_key if target and "type_key" in target else "目标"
		var damage = unit_data.get("damage", 0)
		var wave_info = GameManager.session_data.wave if GameManager.session_data else 1
		AILogger.unit_attack(type_key, target_name, damage)
		# 额外记录详细攻击信息
		AILogger.event("[单位攻击] 波次%d | %s 攻击 %s，伤害 %.0f" % [
			wave_info, type_key, target_name, damage
		])
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text("【单位攻击】波次%d | %s 攻击 %s，伤害 %.0f" % [
				wave_info, type_key, target_name, damage
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
	current_hp = max_hp # Full heal on level up

	GameManager.unit_upgraded.emit(self, old_level, level)
	GameManager.spawn_floating_text(global_position, "Level Up!", Color.GOLD)
	level_up_visual.emit()

func devour(food_unit):
	var old_level = level
	level += 1
	damage += 5
	stats_multiplier += 0.2
	update_visuals()
	GameManager.unit_upgraded.emit(self, old_level, level)

func _on_area_2d_input_event(viewport, event, shape_idx):
	interaction_input_event.emit(viewport, event, shape_idx)

func _on_area_2d_mouse_entered():
	interaction_mouse_entered.emit()

func _on_area_2d_mouse_exited():
	interaction_mouse_exited.emit()

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

func _find_empty_bench_slot() -> int:
	"""Find an empty bench slot, returns -1 if full"""
	if not GameManager.session_data:
		return -1
	for i in range(Constants.BENCH_SIZE):
		if GameManager.session_data.get_bench_unit(i) == null:
			return i
	return -1

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	GameManager.spawn_floating_text(global_position, "+%d" % int(amount), Color.GREEN)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"defense":
			# No defense stat on unit currently?
			pass
		"move_speed":
			# Units don't move.
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


func set_highlight(active: bool, color: Color = Color.WHITE):
	highlight_requested.emit(active, color)

func set_force_highlight(active: bool):
	force_highlight_requested.emit(active)

func start_drag(mouse_pos_global):
	drag_started.emit(mouse_pos_global)

func update_visuals():
	visual_update_requested.emit()
