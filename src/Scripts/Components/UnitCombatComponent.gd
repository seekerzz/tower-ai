extends RefCounted
class_name UnitCombatComponent

var unit: Node2D

func _init(target_unit: Node2D):
	unit = target_unit

func process_combat(delta: float):
	if !unit.unit_data.has("attackType") or unit.unit_data.attackType == "none":
		return

	if unit.cooldown > 0:
		unit.cooldown -= delta
		return

	if unit.attack_cost_mana > 0:
		if !GameManager.check_resource("mana", unit.attack_cost_mana):
			unit.is_no_mana = true
			return
		else:
			unit.is_no_mana = false

	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	var target = combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
	if !target: return

	if unit.unit_data.attackType == "melee":
		_do_melee_attack(target)
	else:
		_do_standard_ranged_attack(target)

func _do_melee_attack(target):
	var target_last_pos = target.global_position

	if unit.attack_cost_mana > 0:
		GameManager.consume_resource("mana", unit.attack_cost_mana)

	unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	if unit.has_method("play_attack_anim"):
		unit.play_attack_anim("melee", target_last_pos)

	await unit.get_tree().create_timer(Constants.ANIM_WINDUP_TIME).timeout
	if !is_instance_valid(unit): return

	if is_instance_valid(target):
		_spawn_melee_projectiles(target)
		unit.attack_performed.emit(target)
	else:
		_spawn_melee_projectiles_blind(target_last_pos)
		unit.attack_performed.emit(null)

func _spawn_melee_projectiles_blind(target_pos: Vector2):
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	var swing_hit_list = []
	var attack_dir = (target_pos - unit.global_position).normalized()

	var proj_speed = 600.0
	var proj_life = (unit.range_val + 30.0) / proj_speed
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
		combat_manager.spawn_projectile(unit, unit.global_position, null, stats)

func _spawn_melee_projectiles(target: Node2D):
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	var swing_hit_list = []
	var attack_dir = (target.global_position - unit.global_position).normalized()

	var proj_speed = 600.0
	var proj_life = (unit.range_val + 30.0) / proj_speed
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
		combat_manager.spawn_projectile(unit, unit.global_position, null, stats)

func _do_standard_ranged_attack(target):
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	if unit.attack_cost_mana > 0:
		GameManager.consume_resource("mana", unit.attack_cost_mana)

	unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	if unit.unit_data.get("proj") == "lightning":
		if unit.has_method("play_attack_anim"):
			unit.play_attack_anim("lightning", target.global_position)
		combat_manager.perform_lightning_attack(unit, unit.global_position, target, unit.unit_data.get("chain", 0))
		return

	if unit.has_method("play_attack_anim"):
		unit.play_attack_anim("ranged", target.global_position)

	var proj_count = unit.unit_data.get("projCount", 1)
	var spread = unit.unit_data.get("spread", 0.5)

	if "multishot" in unit.active_buffs:
		proj_count += 2
		spread = max(spread, 0.5)

	if proj_count == 1:
		combat_manager.spawn_projectile(unit, unit.global_position, target)
		unit.attack_performed.emit(target)
	else:
		var base_angle = (target.global_position - unit.global_position).angle()
		var start_angle = base_angle - spread / 2.0
		var step = spread / max(1, proj_count - 1)

		for i in range(proj_count):
			var angle = start_angle + (i * step)
			combat_manager.spawn_projectile(unit, unit.global_position, target, {"angle": angle})

	unit.attack_performed.emit(target)
