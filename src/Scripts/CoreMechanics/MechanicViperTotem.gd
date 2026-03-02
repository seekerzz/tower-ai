extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

class ViperTotemSource:
	var damage: float = 35.0  # 从20点提升到35点
	var unit_data: Dictionary = { "damageType": "poison" }
	var crit_rate: float = 0.0
	var crit_dmg: float = 1.5

	func _init(dmg_val: float):
		damage = dmg_val

	func calculate_damage_against(target):
		return damage

	func is_in_group(group_name: String) -> bool:
		return false

func _ready():
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _on_timer_timeout():
	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	if not is_wave_active:
		return
	if not GameManager.grid_manager:
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return

	# Sort by distance to core (descending)
	var core_pos = GameManager.grid_manager.global_position

	enemies.sort_custom(func(a, b):
		if not is_instance_valid(a) or not is_instance_valid(b):
			return false
		var dist_a = a.global_position.distance_to(core_pos)
		var dist_b = b.global_position.distance_to(core_pos)
		return dist_a > dist_b
	)

	var targets = []
	for i in range(min(3, enemies.size())):
		targets.append(enemies[i])

	# 记录图腾触发日志
	if AILogger and targets.size() > 0:
		var target_names = []
		for t in targets:
			if is_instance_valid(t) and t.has_method("get"):
				target_names.append(t.type_key if "type_key" in t else "敌人")
		AILogger.totem_triggered("毒蛇图腾", str(target_names.size()) + "个最远敌人", "毒液攻击+3层中毒")

	for target in targets:
		if not is_instance_valid(target):
			continue

		# Mimic Tiger.gd meteor logic: start from above
		var start_pos = target.global_position + Vector2(randf_range(-50, 50), -600)

		# Create dummy source
		var source = ViperTotemSource.new(35.0)  # 伤害从20提升到35

		var stats = {
			"is_meteor": true,
			"ground_pos": target.global_position,
			"proj_override": "ink",
			"damage": 35.0,  # 伤害从20提升到35
			"effects": {
				"poison": 5.0,
				"poison_stacks": 3
			}
		}

		# Call spawn_projectile
		# Note: speed (4th arg) is overridden by is_meteor logic in Projectile.gd (sets to 1200)
		if GameManager.combat_manager:
			GameManager.combat_manager.spawn_projectile(
				source,
				start_pos,
				target,
				stats
			)
