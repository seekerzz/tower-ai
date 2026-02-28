extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 瘟疫使者 - 毒血传播机制
# 攻击使敌人中毒，中毒敌人死亡时传播给附近敌人
# L1: 传播范围0（无传播）
# L2: 传播范围60
# L3: 传播范围120

var poison_effect_script = preload("res://src/Scripts/Effects/PoisonEffect.gd")

# 存储已感染敌人的信息，避免重复连接信号
var _infected_enemies: Dictionary = {}

func on_setup():
	# 监听全局debuff应用信号，用于追踪中毒敌人
	if not GameManager.debuff_applied.is_connected(_on_debuff_applied):
		GameManager.debuff_applied.connect(_on_debuff_applied)

func on_cleanup():
	# 清理信号连接
	if GameManager.debuff_applied.is_connected(_on_debuff_applied):
		GameManager.debuff_applied.disconnect(_on_debuff_applied)

	# 断开所有已连接的单位死亡信号
	for enemy_id in _infected_enemies.keys():
		var enemy = _infected_enemies[enemy_id]
		if is_instance_valid(enemy) and enemy.died.is_connected(_on_infected_enemy_died):
			enemy.died.disconnect(_on_infected_enemy_died)
	_infected_enemies.clear()

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target or not is_instance_valid(target):
		return

	# 应用中毒效果
	if target.has_method("apply_status"):
		var poison_params = {
			"duration": 5.0,
			"damage": unit.damage * 0.2,
			"stacks": 1,
			"source": unit
		}
		target.apply_status(poison_effect_script, poison_params)

func _on_debuff_applied(enemy, debuff_type: String, stacks: int):
	# 只处理中毒debuff，且只处理由本单位施加的中毒
	if debuff_type != "poison":
		return

	if not is_instance_valid(enemy):
		return

	# 检查这个敌人是否已经被我们追踪
	var enemy_id = enemy.get_instance_id()
	if _infected_enemies.has(enemy_id):
		return

	# 获取等级相关的传播范围
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var spread_range = mechanics.get("spread_range", 0.0)

	# 如果传播范围大于0，连接死亡信号
	if spread_range > 0 and enemy.has_signal("died"):
		_infected_enemies[enemy_id] = enemy
		enemy.died.connect(_on_infected_enemy_died.bind(enemy, spread_range))

		# 当敌人被清理时，从字典中移除
		enemy.tree_exiting.connect(_on_infected_enemy_exiting.bind(enemy_id), CONNECT_ONE_SHOT)

func _on_infected_enemy_exiting(enemy_id: int):
	# 敌人被销毁时，从追踪字典中移除
	if _infected_enemies.has(enemy_id):
		_infected_enemies.erase(enemy_id)

func _on_infected_enemy_died(infected_enemy: Node2D, spread_range: float):
	# 从追踪字典中移除
	var enemy_id = infected_enemy.get_instance_id()
	if _infected_enemies.has(enemy_id):
		_infected_enemies.erase(enemy_id)

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
