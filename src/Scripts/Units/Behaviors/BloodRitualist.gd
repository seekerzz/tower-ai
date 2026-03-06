extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var hp_cost_percent: float = 0.20
var buff_active: bool = false

func on_skill_activated():
	var hp_cost = GameManager.core_health * hp_cost_percent
	if GameManager.core_health - hp_cost <= 0:
		GameManager.spawn_floating_text(unit.global_position, "Too Low HP!", Color.RED)
		return

	GameManager.damage_core(hp_cost)

	var bleed_stacks = 2 if unit.level < 2 else 3
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var affected_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and unit.global_position.distance_to(enemy.global_position) <= unit.stats.range_val:
			enemy.add_bleed_stacks(bleed_stacks, unit)
			affected_count += 1

	# 记录血祭术士鲜血仪式日志
	if AILogger:
		var skill_msg = "[SKILL] 血祭术士触发鲜血仪式 | 消耗核心血量: %.0f | 流血层数: %d | 影响敌人: %d" % [hp_cost, bleed_stacks, affected_count]
		AILogger.broadcast_log("事件", skill_msg)
		if AIManager:
			AIManager.broadcast_text(skill_msg)

	if unit.level >= 3:
		_start_ritual_buff()

func _start_ritual_buff():
	if buff_active: return

	buff_active = true
	GameManager.apply_global_buff("lifesteal_multiplier", 2.0)
	GameManager.spawn_floating_text(unit.global_position, "Ritual!", Color.RED)

	# 记录鲜血仪式Buff日志
	if AILogger:
		var buff_msg = "[SKILL] 血祭术士鲜血仪式Buff生效 | 吸血倍数: 2.0x | 持续: 4秒"
		AILogger.broadcast_log("事件", buff_msg)
		if AIManager:
			AIManager.broadcast_text(buff_msg)

	# Wait 4 seconds then remove
	await unit.get_tree().create_timer(4.0).timeout

	if buff_active:
		GameManager.remove_global_buff("lifesteal_multiplier")
		buff_active = false
		# 记录Buff结束日志
		if AILogger:
			var end_msg = "[SKILL] 血祭术士鲜血仪式Buff结束"
			AILogger.broadcast_log("事件", end_msg)
			if AIManager:
				AIManager.broadcast_text(end_msg)

func on_cleanup():
	if buff_active:
		GameManager.remove_global_buff("lifesteal_multiplier")
		buff_active = false
