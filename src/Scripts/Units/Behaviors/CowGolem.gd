extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 牛魔像 - 震荡反击机制
# 每受到15/12/10次攻击触发全屏震荡，晕眩1/1/1.5秒

var hit_counter: int = 0
var hits_threshold: int = 15
var stun_duration: float = 1.0

func on_setup():
	# 从单位数据中获取等级相关的机制参数
	_update_mechanics()

func _update_mechanics():
	var level = unit.level if unit else 1
	var unit_data = unit.unit_data if unit else {}
	var level_data = unit_data.get("levels", {}).get(str(level), {})
	var mechanics = level_data.get("mechanics", {})

	# 根据等级设置受击阈值和晕眩时长
	hits_threshold = mechanics.get("hits_threshold", 15)
	stun_duration = mechanics.get("stun_duration", 1.0)

func on_damage_taken(amount: float, source: Node2D) -> float:
	# 增加受击计数
	hit_counter += 1

	# 检查是否达到阈值
	if hit_counter >= hits_threshold:
		_trigger_shockwave()
		hit_counter = 0  # 重置计数器

	return amount

func _trigger_shockwave():
	# 触发全屏晕眩效果
	var enemies = unit.get_tree().get_nodes_in_group("enemies")

	var stunned_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("apply_stun"):
			enemy.apply_stun(stun_duration)
			stunned_count += 1

	# 显示视觉反馈
	GameManager.spawn_floating_text(unit.global_position, "震荡反击!", Color.GOLD)

	# 触发屏幕震动效果（如果可用）
	if GameManager.has_method("trigger_impact"):
		GameManager.trigger_impact(Vector2.ZERO, 1.0)

	# Emit counter_attack signal for test logging (emit before reset in on_damage_taken)
	# hits_taken is the threshold, damage is estimated based on stunned enemies
	if GameManager.has_signal("counter_attack"):
		GameManager.counter_attack.emit(unit, stunned_count * 10.0, hits_threshold)

func on_stats_updated():
	# 当单位升级或属性更新时，重新读取机制参数
	_update_mechanics()

# 获取当前受击计数（用于UI显示）
func get_hit_counter() -> int:
	return hit_counter

# 获取触发阈值（用于UI显示）
func get_hits_threshold() -> int:
	return hits_threshold
