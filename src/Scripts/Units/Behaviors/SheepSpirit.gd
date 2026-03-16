extends "res://src/Scripts/Units/UnitBehavior.gd"

# 羊灵行为脚本 - 敌人死亡时召唤克隆体

func on_setup():
	# 连接敌人死亡信号
	GameManager.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy, killer_unit):
	if !is_instance_valid(enemy):
		return

	# 检查敌人是否在攻击范围内
	var dist = unit.global_position.distance_to(enemy.global_position)
	if dist > unit.range_val:
		return

	# 根据等级确定克隆体数量和继承比例
	var num_clones = 1 if unit.level < 3 else 2
	var inherit_ratio = 0.4 if unit.level < 2 else 0.6

	for i in range(num_clones):
		var offset = Vector2(randf() * 100 - 50, randf() * 100 - 50)

		if GameManager.summon_manager:
			GameManager.summon_manager.create_summon({
				"unit_id": "enemy_clone",
				"position": enemy.global_position + offset,
				"source": unit,
				"is_clone": true,
				"inherit_ratio": inherit_ratio,
				"lifetime": 10.0,
				"faction": "player"
			})

func on_cleanup():
	# 断开信号连接，避免内存泄漏
	if GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.disconnect(_on_enemy_died)
