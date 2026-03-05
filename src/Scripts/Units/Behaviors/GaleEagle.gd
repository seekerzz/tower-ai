extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Gale Eagle - 疾风鹰
# 每次攻击发射多道风刃
# Lv3: 可暴击，可触发回响，概率生成额外风刃

var wind_blade_count: int = 2
var damage_per_blade: float = 0.6
var spread_angle: float = 0.15

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_setup():
	_update_mechanics()

func _update_mechanics():
	var lvl_stats = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = lvl_stats.get("mechanics", {})
	wind_blade_count = mechanics.get("wind_blade_count", 2)
	damage_per_blade = mechanics.get("damage_per_blade", 0.6)

func on_stats_updated():
	_update_mechanics()

func on_combat_tick(delta: float) -> bool:
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	var target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
	if target:
		_do_wind_blade_attack(target)
	return true

func _do_wind_blade_attack(target):
	var target_last_pos = target.global_position

	if unit.attack_cost_mana > 0:
		if not GameManager.check_resource("mana", unit.attack_cost_mana):
			unit.is_no_mana = true
			return
		GameManager.consume_resource("mana", unit.attack_cost_mana)
		unit.is_no_mana = false

	var anim_duration = clamp(unit.atk_speed * 0.8, 0.1, 0.6)
	unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	unit.play_attack_anim("bow", target_last_pos, anim_duration)

	var pull_time = anim_duration * 0.6
	await unit.get_tree().create_timer(pull_time).timeout
	if not is_instance_valid(unit): return

	_fire_wind_blades(target_last_pos)

func _fire_wind_blades(target_pos: Vector2):
	if not GameManager.combat_manager: return

	var base_angle = (target_pos - unit.global_position).angle()
	var total_spread = spread_angle * (wind_blade_count - 1)
	var start_angle = base_angle - total_spread / 2

	for i in range(wind_blade_count):
		var angle = start_angle + spread_angle * i
		var blade_damage = unit.damage * damage_per_blade

		# Lv3 Logic: Can Crit, Trigger Echo
		var is_crit = false
		if unit.level >= 3:
			if randf() < unit.crit_rate:
				is_crit = true
				blade_damage *= unit.crit_dmg

		var extra_stats = {
			"angle": angle,
			"damage": blade_damage,
			"proj_override": "feather",
			"speed": 500.0,
			"pierce": 1,
			"source": unit,
			"is_critical": is_crit
		}

		GameManager.combat_manager.spawn_projectile(
			unit,
			unit.global_position,
			null,
			extra_stats
		)

	unit.attack_performed.emit(null)

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if unit.level >= 3:
		if randf() < 0.20:
			_spawn_extra_wind_blade(target.global_position)

func _spawn_extra_wind_blade(pos: Vector2):
	if not GameManager.combat_manager: return

	var angle = randf() * TAU
	var blade_damage = unit.damage * damage_per_blade

	var extra_stats = {
		"angle": angle,
		"damage": blade_damage,
		"proj_override": "feather",
		"speed": 500.0,
		"pierce": 1,
		"source": unit
	}

	GameManager.combat_manager.spawn_projectile(
		unit,
		pos,
		null,
		extra_stats
	)
