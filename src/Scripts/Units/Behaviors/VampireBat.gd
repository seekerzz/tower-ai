extends "res://src/Scripts/Units/Behaviors/FlyingMeleeBehavior.gd"

# 吸血蝠 - 鲜血狂噬机制
# 自身生命值越低，吸血比例越高

func _calculate_damage(target: Node2D) -> float:
	# 获取等级相关的机制配置
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var crit_rate_bonus = mechanics.get("crit_rate_bonus", 0.0)

	# 基础伤害计算
	var dmg = unit.damage

	# 计算暴击率（包含等级3的额外暴击）
	var total_crit_rate = unit.crit_rate + crit_rate_bonus
	if randf() < total_crit_rate:
		dmg *= unit.crit_dmg

	return dmg

func _enter_impact(t_impact, t_return, t_landing):
	state = State.IMPACT

	if is_instance_valid(current_target):
		var dmg = _calculate_damage(current_target)
		current_target.take_damage(dmg, unit, "physical")

		# 触发吸血机制
		_apply_lifesteal(dmg)

		if GameManager.has_method("trigger_impact"):
			var dir = (current_target.global_position - unit.global_position).normalized()
			GameManager.trigger_impact(dir, 0.5)

	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()

		# Impact Squash (0.5, 1.5)
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

func _apply_lifesteal(damage: float):
	"""
	鲜血狂噬机制：自身生命值越低，吸血比例越高
	- 基础吸血由等级决定
	- 低血量时获得额外吸血加成
	"""
	# 从mechanics获取等级相关的吸血配置
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var base_lifesteal = mechanics.get("base_lifesteal", 0.0)
	var low_hp_bonus = mechanics.get("low_hp_bonus", 0.5)

	# 计算自身生命值比例
	var unit_hp_percent = unit.current_hp / unit.max_hp if unit.max_hp > 0 else 1.0

	# 计算吸血比例：生命值越低，吸血越高
	var lifesteal_pct = base_lifesteal
	if low_hp_bonus > 0:
		# 当生命值为0时获得最大加成，生命值为100%时获得0加成
		var missing_hp_percent = 1.0 - unit_hp_percent
		lifesteal_pct += low_hp_bonus * missing_hp_percent

	var heal_amt = damage * lifesteal_pct

	if heal_amt > 0:
		# 治疗核心
		if GameManager.has_method("heal_core"):
			GameManager.heal_core(heal_amt)
		else:
			GameManager.damage_core(-heal_amt)

		# 治疗自身
		if unit.has_method("heal"):
			unit.heal(heal_amt)

		# 显示吸血效果
		GameManager.spawn_floating_text(unit.global_position, "+%d" % int(heal_amt), Color.CRIMSON)

		# 发射吸血信号
		if GameManager.has_signal("lifesteal_occurred"):
			GameManager.lifesteal_occurred.emit(unit, heal_amt)
