extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 瘟疫使者 - 毒血传播机制
# 攻击使敌人中毒，中毒敌人死亡时传播给附近敌人

var poison_effect_script = preload("res://src/Scripts/Effects/PoisonEffect.gd")

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target or not is_instance_valid(target):
		return

	# 获取等级相关的传播范围
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var spread_range = mechanics.get("spread_range", 0.0)

	# 应用中毒效果
	if target.has_method("apply_status"):
		var poison_params = {
			"duration": 5.0,
			"damage": unit.damage * 0.2,
			"stacks": 1,
			"source": unit
		}
		target.apply_status(poison_effect_script, poison_params)

		# 连接死亡信号以传播瘟疫（只连接一次）
		if not target.died.is_connected(_on_infected_enemy_died):
			target.died.connect(_on_infected_enemy_died.bind(target, spread_range))

func _on_infected_enemy_died(infected_enemy: Node2D, spread_range: float):
	# 敌人死亡时，传播瘟疫给附近敌人
	if spread_range <= 0:
		return

	if not GameManager.combat_manager:
		return

	var enemies = GameManager.combat_manager.get_tree().get_nodes_in_group("enemies")
	var spread_count = 0
	const MAX_SPREAD = 3  # 最多传播给3个敌人

	for enemy in enemies:
		if spread_count >= MAX_SPREAD:
			break

		if not is_instance_valid(enemy) or enemy == infected_enemy:
			continue

		var dist = infected_enemy.global_position.distance_to(enemy.global_position)
		if dist <= spread_range:
			# 传播中毒效果
			if enemy.has_method("apply_status"):
				var poison_params = {
					"duration": 4.0,
					"damage": unit.damage * 0.15,
					"stacks": 1,
					"source": unit
				}
				enemy.apply_status(poison_effect_script, poison_params)
				spread_count += 1

	if spread_count > 0:
		GameManager.spawn_floating_text(infected_enemy.global_position, "传播!", Color.GREEN)
