extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var damage_reduction: int = 15

func on_setup():
	damage_reduction = 15
	if unit.level >= 2:
		damage_reduction = 25
	if unit.level >= 3:
		damage_reduction = 35

func on_damage_taken(amount: float, source: Node) -> float:
	var reduced = max(0, amount - damage_reduction)

	# 记录[UNIT_BUFF]硬化皮肤减伤日志
	if AILogger and amount > 0:
		var source_name = source.name if source and source.has("name") else "未知"
		AILogger.broadcast_log("事件", "[UNIT_BUFF] 铁甲龟 硬化皮肤生效 | 减伤: %d | 原始伤害: %.0f | 实际伤害: %.0f | 来源: %s" % [damage_reduction, amount, reduced, source_name])

	if unit.level >= 3 and reduced <= 0 and amount > 0:
		var heal_amount = GameManager.max_core_health * 0.005
		GameManager.heal_core(heal_amount)
		unit.spawn_buff_effect("💖")

		# 记录[UNIT_HEAL]绝对防御回血日志
		if AILogger:
			AILogger.broadcast_log("事件", "[UNIT_HEAL] 铁甲龟 绝对防御回血 | 回复: %.0f HP (核心) | Lv.3技能触发" % heal_amount)
			if AIManager:
				AIManager.broadcast_text("[UNIT_HEAL] 铁甲龟 绝对防御 | 核心回复 %.0f HP" % heal_amount)

	# Apply reflection damage if source is valid
	if source and is_instance_valid(source) and source.has_method("take_damage"):
		# Reflection is handled by the damage system, not here
		pass

	return reduced
