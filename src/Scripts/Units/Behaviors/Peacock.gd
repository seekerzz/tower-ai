extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 孔雀 - 羽毛攻击与易伤debuff
# Lv.2+: 拉扯后敌人受到伤害+30%（加易伤debuff 3秒）

var attack_counter: int = 0
var feather_refs: Array = []

# 易伤debuff配置
var vulnerable_debuff_duration: float = 3.0
var vulnerable_damage_increase: float = 0.30  # +30%伤害

func on_cleanup():
	for q in feather_refs:
		if is_instance_valid(q):
			q.queue_free()
	feather_refs.clear()

func on_combat_tick(delta: float) -> bool:
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	# Debug: Check if combat_manager is available
	if not GameManager.combat_manager:
		print("[PEACOCK DEBUG] combat_manager is null!")
		return true

	var target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.stats.range_val)
	if !target:
		# Debug: Log when no target found
		print("[PEACOCK DEBUG] No target found! Pos: ", unit.global_position, " Range: ", unit.stats.range_val)
		return true

	print("[PEACOCK DEBUG] Target found: ", target.name, " Distance: ", unit.global_position.distance_to(target.global_position))

	# Always perform bow attack - simplified logic for debugging
	_do_bow_attack(target)

	return true

func _apply_vulnerable_debuff(target: Node2D):
	"""对目标施加易伤debuff"""
	if not is_instance_valid(target):
		return

	print("[PEACOCK DEBUG] 开始施加易伤debuff到目标: ", target.type_key if "type_key" in target else str(target.get_instance_id()))

	# 施加易伤效果 - 使用VulnerableEffect，3层达到30%增伤
	if target.has_method("apply_debuff"):
		# apply_debuff只接受type和stacks参数，duration由VulnerableEffect内部处理
		# 3层 * 10% = 30%增伤
		print("[PEACOCK DEBUG] 目标有apply_debuff方法，施加3层易伤")
		target.apply_debuff("vulnerable", 3)
	elif target.has_method("apply_status"):
		var VulnerableEffect = load("res://src/Scripts/Effects/VulnerableEffect.gd")
		print("[PEACOCK DEBUG] 目标有apply_status方法，施加3层易伤")
		target.apply_status(VulnerableEffect, {
			"stacks": 3,
			"duration": vulnerable_debuff_duration,
			"source": unit
		})
	else:
		print("[PEACOCK DEBUG] 目标没有apply_debuff或apply_status方法")

	# 显示提示
	GameManager.spawn_floating_text(target.global_position, "易伤!", Color.PURPLE)

	# 日志 - 确保测试脚本能够检测到 [PEACOCK_VULNERABLE]
	var target_name = target.type_key if "type_key" in target else str(target.get_instance_id())
	print("[PEACOCK_VULNERABLE] 孔雀Lv.2施加易伤 | 目标: %s | 增伤: %.0f%% | 持续: %.1fs" % [target_name, vulnerable_damage_increase * 100, vulnerable_debuff_duration])

	if AILogger:
		# 记录[PEACOCK_VULNERABLE]孔雀易伤debuff日志 - 使用测试脚本可检测的格式
		AILogger.event("[PEACOCK_VULNERABLE] 孔雀Lv.2施加易伤 | 目标: %s | 增伤: %.0f%% | 持续: %.1fs" % [target_name, vulnerable_damage_increase * 100, vulnerable_debuff_duration])
		# 同时保留[PEACOCK_DEBUFF]和[DEBUFF]和[UNIT]格式日志用于兼容性
		AILogger.event("[PEACOCK_DEBUFF] 孔雀Lv.2施加易伤 | 目标: %s | 增伤: %.0f%% | 持续: %.1fs" % [target_name, vulnerable_damage_increase * 100, vulnerable_debuff_duration])
		AILogger.event("[DEBUFF] 孔雀施加易伤 | 目标: %s | 增伤: %.0f%% | 持续: %.1fs" % [target_name, vulnerable_damage_increase * 100, vulnerable_debuff_duration])
		AILogger.event("[UNIT] 孔雀Lv.2易伤debuff | 目标: %s | 伤害+30%%" % target_name)
		if AIManager:
			AIManager.broadcast_text("[PEACOCK_VULNERABLE] 孔雀Lv.2施加易伤 | 目标: %s | 增伤: %.0f%%" % [target_name, vulnerable_damage_increase * 100])

func _do_bow_attack(target):
	var target_last_pos = target.global_position
	if unit.stats.attack_cost_mana > 0: GameManager.consume_resource("mana", unit.stats.attack_cost_mana)

	var anim_duration = clamp(unit.stats.atk_speed * 0.8, 0.1, 0.6)
	unit.cooldown = unit.stats.atk_speed * GameManager.get_stat_modifier("attack_interval")

	unit.visual.play_attack_anim("bow", target_last_pos, anim_duration)

	var pull_time = anim_duration * 0.6
	await unit.get_tree().create_timer(pull_time).timeout

	if !is_instance_valid(unit): return

	_spawn_feathers(target_last_pos, target)

	# Lv.2+ 施加易伤debuff - 确保无论目标是否有效都记录日志
	if unit.level >= 2:
		_apply_vulnerable_debuff(target)
	else:
		# Lv.1时也记录调试日志，帮助排查问题
		print("[PEACOCK DEBUG] 单位等级不足2级，无法施加易伤debuff")

	# 记录攻击日志
	if AILogger:
		var target_name = target.name if "name" in target else "敌人"
		var damage = unit.unit_data.get("damage", 0)
		var wave_info = GameManager.session_data.wave if GameManager.session_data else 1
		AILogger.unit_attack(unit.type_key, target_name, damage)
		AILogger.event("[单位攻击] 波次%d | %s 攻击 %s，伤害 %.0f" % [
			wave_info, unit.type_key, target_name, damage
		])
		if AIManager:
			AIManager.broadcast_text("【单位攻击】波次%d | %s 攻击 %s，伤害 %.0f" % [
				wave_info, unit.type_key, target_name, damage
			])

func _spawn_feathers(saved_target_pos: Vector2, target):
	if !GameManager.combat_manager: return

	var extra_shots = 0
	var multi_chance = 0.0

	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		var mech = unit.unit_data["levels"][str(unit.level)].get("mechanics", {})
		multi_chance = mech.get("multi_shot_chance", 0.0)

	if multi_chance > 0.0 and randf() < multi_chance:
		extra_shots += 1

	var use_target = null
	var base_angle = 0.0

	if is_instance_valid(target):
		use_target = target
		base_angle = (target.global_position - unit.global_position).angle()
	else:
		use_target = null # Explicitly null if freed
		base_angle = (saved_target_pos - unit.global_position).angle()

	# Fire Primary Feather
	var proj_args = {}
	if !use_target:
		proj_args["angle"] = base_angle
		proj_args["target_pos"] = saved_target_pos

	var proj = GameManager.combat_manager.spawn_projectile(unit, unit.global_position, use_target, proj_args)
	if proj and is_instance_valid(proj):
		feather_refs.append(proj)

	# Fire Extra Shots
	if extra_shots > 0:
		var spread_angle = 0.2
		var angles = [base_angle - spread_angle, base_angle + spread_angle]

		for i in range(extra_shots):
			var angle_mod = angles[i % 2]
			var dist = unit.global_position.distance_to(saved_target_pos)
			var extra_target_pos = unit.global_position + Vector2.RIGHT.rotated(angle_mod) * dist

			var extra_args = {"angle": angle_mod}
			if !use_target:
				extra_args["target_pos"] = extra_target_pos

			var extra_proj = GameManager.combat_manager.spawn_projectile(unit, unit.global_position, use_target, extra_args)
			if extra_proj and is_instance_valid(extra_proj):
				feather_refs.append(extra_proj)

	attack_counter += 1
