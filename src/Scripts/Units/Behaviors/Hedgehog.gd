extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var reflect_chance: float = 0.25

func on_setup():
	reflect_chance = 0.25
	if unit.level >= 2:
		reflect_chance = 0.40

func on_damage_taken(amount: float, source: Node) -> float:
	# Reflect logic
	if randf() < reflect_chance and source and is_instance_valid(source) and source.has_method("take_damage"):
		var reflect_damage = amount
		# Reflect physical damage
		source.take_damage(reflect_damage, unit, "physical")
		unit.spawn_buff_effect("💢")

		# 记录[UNIT_SKILL]刺猬尖刺反弹日志
		if AILogger:
			var source_name = source.name if source.has("name") else "敌人"
			var chance_str = "30%" if unit.level < 2 else "50%"
			AILogger.broadcast_log("事件", "[UNIT_SKILL] 刺猬 尖刺反弹触发 | 概率: %s | 目标: %s | 反弹伤害: %.0f" % [chance_str, source_name, reflect_damage])
			if AIManager:
				AIManager.broadcast_text("[UNIT_SKILL] 刺猬 尖刺反弹 | 目标: %s | 伤害: %.0f" % [source_name, reflect_damage])

		if unit.level >= 3:
			_launch_spikes()

	return amount

func _launch_spikes():
	# 记录[UNIT_SKILL]刚毛散射日志
	if AILogger:
		AILogger.broadcast_log("事件", "[UNIT_SKILL] 刺猬 刚毛散射触发 | 发射数量: 3 | Lv.3技能")
		if AIManager:
			AIManager.broadcast_text("[UNIT_SKILL] 刺猬 刚毛散射 | 发射3枚尖刺")

	for i in range(3):
		var angle = i * (TAU / 3)

		# Using standard projectile logic (no gravity simulation in current Projectile.gd)
		var stats = {
			"damage": 20.0, # Base spike damage
			"proj_override": "stinger", # Using stinger visual as spike
			"speed": 300.0,
			"angle": angle,
			"pierce": 1,
			"damageType": "physical"
		}
		GameManager.combat_manager.spawn_projectile(unit, unit.global_position, null, stats)
