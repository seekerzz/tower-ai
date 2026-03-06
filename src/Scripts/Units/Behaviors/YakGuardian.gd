extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var taunt_behavior = null

func on_setup():
	var script = load("res://src/Scripts/Units/Behaviors/TauntBehavior.gd")
	if script:
		taunt_behavior = script.new(unit)
		taunt_behavior.taunt_interval = 6.0 if unit.level < 2 else 5.0

	if unit.level >= 3:
		if not GameManager.is_connected("totem_attacked", _on_totem_attack):
			GameManager.totem_attacked.connect(_on_totem_attack)

	# 记录[YAK]牦牛守护嘲讽日志 - 使用测试脚本可检测的格式
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "牦牛守护"
		AILogger.broadcast_log("BUFF", "%s 施加 %s 给 %s" % [ unit_name,  "嘲讽光环", "自身"])
		AILogger.broadcast_log("事件", "[YAK] 牦牛守护激活嘲讽光环 | 等级: %d | 嘲讽间隔: %.1fs" % [unit.level, taunt_behavior.taunt_interval if taunt_behavior else 6.0])
		# 同时保留[UNIT]格式日志用于兼容性
		AILogger.broadcast_log("事件", "[UNIT] 牦牛守护激活嘲讽光环")
		if AIManager:
			AIManager.broadcast_text("[YAK] 牦牛守护激活嘲讽光环 | 等级: %d" % unit.level)

func on_tick(delta: float):
	if taunt_behavior and taunt_behavior.has_method("on_tick"):
		taunt_behavior.on_tick(delta)

func _on_totem_attack(totem_type: String):
	if totem_type != "cow":
		return

	var bonus_damage = unit.stats.max_hp * 0.15
	var enemies = unit.get_enemies_in_range(unit.stats.range_val)
	var hit_count = 0
	for enemy in enemies:
		enemy.take_damage(bonus_damage, unit, "physical")
		unit.spawn_buff_effect("⚔️")
		hit_count += 1

	# 记录[YAK_TOTEM]牦牛守护图腾联动日志 - 使用测试脚本可检测的格式
	if AILogger and hit_count > 0:
		var unit_name = unit.type_key if unit and "type_key" in unit else "牦牛守护"
		AILogger.broadcast_log("事件", "[YAK_TOTEM] 牦牛守护触发图腾联动 | 目标: %d个敌人 | 伤害: %.0f" % [hit_count, bonus_damage])
		# 同时保留[UNIT]格式日志用于兼容性
		AILogger.broadcast_log("事件", "[UNIT] 牦牛守护触发图腾联动 | 目标: %d个敌人 | 伤害: %.0f" % [hit_count, bonus_damage])
		if AIManager:
			AIManager.broadcast_text("[YAK_TOTEM] 牦牛守护触发图腾联动 | 目标: %d个敌人 | 伤害: %.0f" % [hit_count, bonus_damage])

func on_cleanup():
	if GameManager.has_signal("totem_attacked") and GameManager.is_connected("totem_attacked", _on_totem_attack):
		GameManager.totem_attacked.disconnect(_on_totem_attack)
