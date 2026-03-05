extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func on_setup():
	super.on_setup()
	# 记录蚊子单位激活日志
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "蚊子"
		AILogger.event("[SKILL] 蚊子单位激活 | 单位: %s | 等级: %d" % [unit_name, unit.level])
		if AIManager:
			AIManager.broadcast_text("[SKILL] 蚊子单位激活 | 单位: %s" % unit_name)

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not is_instance_valid(target): return

	# Get base lifesteal from unit_data
	var lifesteal_pct = unit.unit_data.get("lifesteal_percent", 0.0)

	# Check for level-specific lifesteal in mechanics
	var level_data = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = level_data.get("mechanics", {})
	if mechanics.has("lifesteal_percent"):
		lifesteal_pct = mechanics["lifesteal_percent"]

	var heal_amt = damage * lifesteal_pct

	# 记录蚊子吸血日志（无论heal_amt是否为0，都记录攻击事件）
	if AILogger:
		var target_name = target.type_key if target.has("type_key") else str(target.get_instance_id())
		var skill_msg = "[SKILL] 蚊子触发吸血 | 目标: %s | 伤害: %.0f | 吸血比例: %.0f%% | 吸血量: %.0f" % [target_name, damage, lifesteal_pct * 100, heal_amt]
		AILogger.event(skill_msg)
		if AIManager:
			AIManager.broadcast_text(skill_msg)

	if heal_amt > 0:
		GameManager.heal_core(heal_amt)
		unit.heal(heal_amt)

	if unit.level >= 3:
		# Check for bleed stacks with proper property existence check
		if target.has_method("add_bleed_stacks") and "bleed_stacks" in target:
			if target.bleed_stacks > 0:
				target.take_damage(damage, unit, "physical")
				# 记录[UNIT_SKILL]蚊子对流血敌人额外伤害日志
				if AILogger:
					var target_name = target.type_key if target.has("type_key") else str(target.get_instance_id())
					var skill_msg = "[SKILL] 蚊子(Lv3+)对流血敌人造成额外伤害 | 目标: %s | 伤害: %.0f | 流血层数: %d" % [target_name, damage, target.bleed_stacks]
					AILogger.event(skill_msg)
					if AIManager:
						AIManager.broadcast_text(skill_msg)

		# Check for kill with proper hp property check
		if target.has_method("die") and "hp" in target and target.hp <= 0:
			_explode_on_kill(target.global_position, damage * 0.4)

func _explode_on_kill(position: Vector2, damage: float):
	var radius = 80.0
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) <= radius:
			enemy.take_damage(damage, unit, "physical")
			hit_count += 1

	GameManager.spawn_floating_text(position, "BOOM!", Color.ORANGE)
	# 记录[UNIT_SKILL]蚊子击杀爆炸日志
	if AILogger:
		var skill_msg = "[UNIT_SKILL] 蚊子 触发击杀爆炸 | 范围: %.0f | 命中: %d个敌人 | 伤害: %.0f" % [radius, hit_count, damage]
		AILogger.event(skill_msg)
		if AIManager:
			AIManager.broadcast_text(skill_msg)
