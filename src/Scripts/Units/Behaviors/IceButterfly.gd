extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name IceButterfly

var freeze_threshold: int = 2  # 从3层降低到2层触发冰冻

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	super.on_projectile_hit(target, damage, projectile)

	if not target or not is_instance_valid(target):
		return

	# 记录冰晶蝶攻击日志（无论是否触发冻结）
	if AILogger:
		var target_name = target.type_key if target.has("type_key") else str(target.get_instance_id())
		var current_stacks = target.get_meta("ice_stacks") if target.has_meta("ice_stacks") else 0
		AILogger.broadcast_log("事件", "[SKILL] 冰晶蝶攻击 | 目标: %s | 当前冰层: %d/%d" % [target_name, current_stacks, freeze_threshold])
		if AIManager:
			AIManager.broadcast_text("[SKILL] 冰晶蝶攻击 | 目标: %s" % target_name)

	if not target.has_meta("ice_stacks"):
		target.set_meta("ice_stacks", 0)

	var stacks = target.get_meta("ice_stacks") + 1
	target.set_meta("ice_stacks", stacks)

	GameManager.spawn_floating_text(target.global_position, "❄", Color.CYAN)

	if stacks >= freeze_threshold:
		_freeze_enemy(target)
		target.set_meta("ice_stacks", 0)

func _freeze_enemy(enemy: Node2D):
	# 冻结时间从1.0/1.5秒提升到1.5/2.0秒
	var duration = 1.5 if unit.level < 2 else 2.0
	if enemy.has_method("apply_freeze"):
		enemy.apply_freeze(duration)
		if AILogger:
			var enemy_id = enemy.name if enemy and "name" in enemy else "未知敌人"
			if enemy and "type_key" in enemy:
				enemy_id = enemy.type_key
			pass
			# 记录[SKILL]冰晶蝶冻结日志 - 使用测试脚本可检测的格式
			AILogger.broadcast_log("事件", "[SKILL] 冰晶蝶触发冻结 | 目标: %s | 持续时间: %.1fs" % [enemy_id, duration])
			if AIManager:
				AIManager.broadcast_text("[SKILL] 冰晶蝶触发冻结 | 目标: %s | 持续时间: %.1fs" % [enemy_id, duration])
