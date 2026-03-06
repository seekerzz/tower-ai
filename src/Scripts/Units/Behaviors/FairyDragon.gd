extends "res://src/Scripts/Units/UnitBehavior.gd"

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target or not is_instance_valid(target):
		return

	var resistance = 1.0
	if "knockback_resistance" in target:
		resistance = target.knockback_resistance

	var base_chance = 0.0
	# Access unit_data safely to get mechanics for current level
	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		var stats = unit.unit_data["levels"][str(unit.level)]
		if stats.has("mechanics") and stats["mechanics"].has("teleport_base_chance"):
			base_chance = stats["mechanics"]["teleport_base_chance"]

	# 记录仙女龙攻击日志（无论是否触发传送）
	if AILogger:
		var unit_id = unit.type_key if unit and "type_key" in unit else "未知单位"
		var target_name = target.type_key if target.has("type_key") else str(target.get_instance_id())
		var chance_display = base_chance * 100 if base_chance > 0 else 0
		AILogger.broadcast_log("事件", "[SKILL] 仙女龙攻击 | 目标: %s | 传送概率: %.0f%%" % [target_name, chance_display])
		if AIManager:
			AIManager.broadcast_text("[SKILL] 仙女龙攻击 | 目标: %s" % target_name)

	if base_chance <= 0.0:
		return

	var final_chance = base_chance / max(1.0, resistance)

	if randf() < final_chance:
		var direction = (target.global_position - unit.global_position).normalized()
		# Random distance between 2 and 3 tiles
		var distance = randf_range(2.0, 3.0) * Constants.TILE_SIZE

		# New position along the line from unit to target (extension)
		var target_pos = unit.global_position + (direction * distance)

		target.global_position = target_pos

		GameManager.spawn_floating_text(target.global_position, "Warp!", Color.VIOLET)

		if AILogger:
			var unit_id = unit.type_key if unit and "type_key" in unit else "未知单位"
			pass
			# 记录[FAIRY_DRAGON]仙女龙传送技能日志 - 使用测试脚本可检测的格式
			AILogger.broadcast_log("事件", "[FAIRY_DRAGON] 仙女龙触发传送 | 概率: %.0f%% | 目标位置: (%.0f, %.0f)" % [final_chance * 100, target_pos.x, target_pos.y])
			# 同时保留[SKILL]格式日志用于兼容性
			AILogger.broadcast_log("事件", "[SKILL] 仙女龙触发传送 | 概率: %.0f%% | 目标位置: (%.0f, %.0f)" % [final_chance * 100, target_pos.x, target_pos.y])
			if AIManager:
				AIManager.broadcast_text("[FAIRY_DRAGON] 仙女龙触发传送 | 概率: %.0f%%" % (final_chance * 100))

		if unit.level >= 3:
			# Only logic related to phase collapse needed for logs
			var aoe_damage = 50.0
			var enemies = unit.get_tree().get_nodes_in_group("enemies")
			for e in enemies:
				if e != target and e.global_position.distance_to(target_pos) <= 1.5 * Constants.TILE_SIZE:
					if e.has_method("take_damage"):
						e.take_damage(aoe_damage, unit, "magic")
			if target.has_method("take_damage"):
				target.take_damage(aoe_damage, unit, "magic")
			if AILogger:
				pass
