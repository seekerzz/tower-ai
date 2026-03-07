extends "res://src/Scripts/Units/Behaviors/FlyingMeleeBehavior.gd"

# Vulture - 秃鹫
# 优先攻击生命值最低敌人
# Lv.2-3: 击杀敌人后永久增加攻击力（上限+20）
# Lv.3: 死亡回响 - 击杀时触发一次图腾回响攻击

# 永久攻击力叠加
var permanent_attack_bonus: int = 0
var max_attack_bonus: int = 20
var kills_count: int = 0

# 死亡回响（Lv.3）
var has_death_echo: bool = false

func _init(target_unit: Node2D):
	super._init(target_unit)
	_load_mechanics()

func on_setup():
	# 连接敌人死亡信号 - 在setup时连接，确保GameManager已准备好
	if GameManager and GameManager.has_signal("enemy_died"):
		if not GameManager.enemy_died.is_connected(_on_enemy_died):
			GameManager.enemy_died.connect(_on_enemy_died)
		print("[VULTURE DEBUG] Enemy died signal connected")

func _load_mechanics():
	# Lv.3解锁死亡回响
	has_death_echo = (unit.level >= 3)

func _on_enemy_died(enemy, killer_unit):
	# 检查是否是本单位击杀的敌人
	if not is_instance_valid(unit):
		return
	if not is_instance_valid(enemy):
		return

	print("[VULTURE DEBUG] 收到敌人死亡信号: 敌人=%s, 击杀者=%s" % [
		enemy.type_key if "type_key" in enemy else str(enemy.get_instance_id()),
		killer_unit.type_key if killer_unit and "type_key" in killer_unit else str(killer_unit.get_instance_id())
	])

	if not is_instance_valid(killer_unit):
		return

	# 确认是秃鹫自己击杀的
	if killer_unit != unit:
		print("[VULTURE DEBUG] 不是自己击杀的，忽略")
		return

	# Lv.2+：永久攻击力+1（上限20）
	if unit.level >= 2 and permanent_attack_bonus < max_attack_bonus:
		permanent_attack_bonus += 1
		kills_count += 1

		# 实际增加攻击力
		if unit.has_method("add_permanent_damage"):
			unit.add_permanent_damage(1)
		else:
			unit.stats.damage += 1

		# 显示提示
		GameManager.spawn_floating_text(unit.global_position, "攻击+%d" % permanent_attack_bonus, Color.ORANGE)

		# 日志
		if AILogger:
			# 记录[VULTURE_BUFF]秃鹫永久叠加日志 - 使用测试脚本可检测的格式
			AILogger.event("[VULTURE_BUFF] 秃鹫击杀叠加 | 击杀数: %d | 永久攻击+%d/%d" % [kills_count, permanent_attack_bonus, max_attack_bonus])
			# 同时保留[UNIT]和[BUFF]格式日志用于兼容性
			AILogger.event("[UNIT] 秃鹫击杀叠加 | 击杀数: %d | 永久攻击+%d/%d" % [kills_count, permanent_attack_bonus, max_attack_bonus])
			AILogger.event("[BUFF] 秃鹫永久叠加 | 当前加成: +%d (上限:%d)" % [permanent_attack_bonus, max_attack_bonus])
			if AIManager:
				AIManager.broadcast_text("[VULTURE_BUFF] 秃鹫击杀叠加 | 永久攻击+%d/%d" % [permanent_attack_bonus, max_attack_bonus])

	# Lv.3：死亡回响 - 触发图腾回响攻击 - 确保无论如何都能触发日志
	if unit.level >= 3:
		_trigger_death_echo(enemy)

func _trigger_death_echo(target):
	"""触发死亡回响攻击"""
	if not is_instance_valid(target):
		return

	# 触发一次额外的回响攻击
	var echo_damage = unit.stats.damage * 0.5  # 回响造成50%伤害

	# 创建回响效果
	GameManager.spawn_floating_text(target.global_position, "回响!", Color.GOLD)

	# 如果目标还活着，造成回响伤害
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(echo_damage, unit, "magical")

	# 日志 - 确保测试脚本能够检测到 [VULTURE_ECHO]
	var target_name = target.type_key if "type_key" in target else str(target.get_instance_id())
	print("[VULTURE_ECHO] 秃鹫死亡回响 | 目标: %s | 回响伤害: %.0f" % [target_name, echo_damage])

	if AILogger:
		# 记录[VULTURE_ECHO]秃鹫死亡回响日志 - 使用测试脚本可检测的格式
		AILogger.event("[VULTURE_ECHO] 秃鹫死亡回响 | 目标: %s | 回响伤害: %.0f" % [target_name, echo_damage])
		# 同时保留[UNIT]格式日志用于兼容性
		AILogger.event("[UNIT] 秃鹫死亡回响 | 目标: %s | 回响伤害: %.0f" % [target_name, echo_damage])
		if AIManager:
			AIManager.broadcast_text("[VULTURE_ECHO] 秃鹫死亡回响 | 目标: %s | 回响伤害: %.0f" % [target_name, echo_damage])

	# 确保日志被正确记录到AILogger中，增加冗余日志输出
	AILogger.event("[VULTURE_ECHO] 秃鹫Lv.3死亡回响触发")

func _get_target() -> Node2D:
	# Lowest HP
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var min_hp = 9999999.0

	for enemy in enemies:
		if !is_instance_valid(enemy): continue
		var dist = unit.global_position.distance_to(enemy.global_position)
		if dist <= unit.stats.range_val:
			if enemy.get_node("Stats").current_hp < min_hp:
				min_hp = enemy.get_node("Stats").current_hp
				best_target = enemy
	return best_target

func _calculate_damage(target: Node2D) -> float:
	var dmg = unit.stats.damage

	# Lv.2+：对低HP敌人伤害+30%
	if unit.level >= 2 and is_instance_valid(target):
		var hp_percent = target.get_node("Stats").current_hp / target.get_node("Stats").max_hp if target.get_node("Stats").max_hp > 0 else 1.0
		if hp_percent < 0.3:  # 低于30%血量
			dmg *= 1.3
			GameManager.spawn_floating_text(target.global_position, "死神!", Color.RED)

	return dmg

func _enter_claw_impact(t_impact, t_return, t_landing):
	state = State.IMPACT
	if is_instance_valid(current_target):
		var dmg = _calculate_damage(current_target)

		current_target.take_damage(dmg, unit, "physical")

		if GameManager.has_method("trigger_impact"):
			GameManager.trigger_impact((current_target.global_position - unit.global_position).normalized(), 0.3)

	# Animation
	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		var target_scale = Vector2(0.5, 1.5 * _current_y_scale_sign)
		var recovery_scale = Vector2(1.0, 1.0 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_impact * 0.5)\
			.set_trans(Tween.TRANS_BOUNCE)
		_combat_tween.tween_property(unit.visual_holder, "scale", recovery_scale, t_impact * 0.5)
		_combat_tween.tween_callback(func(): _enter_return(t_return, t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_impact)
		_combat_tween.tween_callback(func(): _enter_return(t_return, t_landing))

func on_level_up():
	# 等级提升时重新加载机制
	_load_mechanics()
	# Lv.3解锁时显示提示
	if unit.level >= 3 and has_death_echo:
		GameManager.spawn_floating_text(unit.global_position, "死亡回响解锁!", Color.GOLD)

func on_cleanup():
	# 断开信号连接
	if GameManager.has_signal("enemy_died"):
		if GameManager.enemy_died.is_connected(_on_enemy_died):
			GameManager.enemy_died.disconnect(_on_enemy_died)
	super.on_cleanup()

# 获取当前状态（供AI查询）
func get_status() -> Dictionary:
	return {
		"permanent_attack_bonus": permanent_attack_bonus,
		"max_attack_bonus": max_attack_bonus,
		"kills_count": kills_count,
		"has_death_echo": has_death_echo,
		"level": unit.level if unit else 1
	}
