extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 影蝠 (ShadowBat) - 蝙蝠图腾流派攻击单位
# LV.1: 暗影步 - 每 6 秒瞬移到最远敌人身边，落点周围敌人获得 1 层流血，然后返回原位
# LV.2: 冷却 6 秒→4 秒，瞬移路径留下暗影轨迹，经过的敌人移速 -30%
# LV.3: 暗影轨迹持续 3 秒，且经过的敌人每秒受到攻击力 30% 伤害

var shadow_step_timer: float = 0.0
var shadow_step_interval: float = 6.0  # 暗影步冷却时间
var original_position: Vector2 = Vector2.ZERO
var is_shadow_stepping: bool = false
var shadow_trail_active: bool = false  # LV.2: 暗影轨迹是否激活
var trail_duration: float = 3.0  # LV.3: 轨迹持续时间
var trail_damage_percent: float = 0.3  # LV.3: 轨迹伤害比例（攻击力的 30%）
var slow_factor: float = 0.7  # LV.2: 移速 -30%

# 暗影步目标位置
var shadow_step_target: Vector2 = Vector2.ZERO

func on_setup():
	_update_mechanics()
	original_position = unit.global_position
	shadow_step_timer = shadow_step_interval  # 开局即可使用

func on_stats_updated():
	_update_mechanics()

func _update_mechanics():
	"""根据等级更新暗影步参数"""
	var level_data = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = level_data.get("mechanics", {})

	# 更新冷却时间
	if mechanics.has("shadow_step_interval"):
		shadow_step_interval = mechanics["shadow_step_interval"]
	else:
		# 默认：LV.1=6 秒，LV.2+=4 秒
		shadow_step_interval = 6.0 if unit.level == 1 else 4.0

	# 更新轨迹持续时间
	if mechanics.has("trail_duration"):
		trail_duration = mechanics["trail_duration"]
	else:
		trail_duration = 3.0 if unit.level >= 3 else 0.0

	# 更新轨迹伤害比例
	if mechanics.has("trail_damage_percent"):
		trail_damage_percent = mechanics["trail_damage_percent"]
	else:
		trail_damage_percent = 0.3 if unit.level >= 3 else 0.0

	# 更新减速效果
	if mechanics.has("slow_factor"):
		slow_factor = mechanics["slow_factor"]
	else:
		slow_factor = 0.7 if unit.level >= 2 else 1.0

	shadow_trail_active = unit.level >= 2

func on_tick(delta: float):
	# 更新暗影步计时器
	if shadow_step_timer > 0:
		shadow_step_timer -= delta
	else:
		# 尝试执行暗影步
		_try_shadow_step()

	# 处理暗影轨迹（LV.2+）
	if shadow_trail_active and trail_duration > 0:
		_update_shadow_trail(delta)

func _try_shadow_step():
	"""尝试执行暗影步 - 瞬移到最远敌人"""
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# 找到距离最远的敌人
	var farthest_enemy = null
	var max_dist = 0.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = unit.global_position.distance_to(enemy.global_position)
		if dist > max_dist:
			max_dist = dist
			farthest_enemy = enemy

	if not farthest_enemy:
		return

	# 记录原始位置用于返回
	original_position = unit.global_position
	shadow_step_target = farthest_enemy.global_position

	# 执行瞬移
	_execute_shadow_step(farthest_enemy)

	# 重置计时器
	shadow_step_timer = shadow_step_interval

func _execute_shadow_step(target: Node2D):
	is_shadow_stepping = true

	# 瞬移到目标位置
	var teleport_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	unit.global_position = shadow_step_target + teleport_offset

	# 落点周围敌人获得 1 层流血
	var AoE_radius = 80.0
	_apply_bleed_stacks_to_nearby_enemies(unit.global_position, AoE_radius, 1)

	# 视觉效果
	GameManager.spawn_floating_text(unit.global_position, "暗影步!", Color(0.6, 0.2, 0.8))

	# 记录日志
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "影蝠"
		var target_name = target.type_key if "type_key" in target else str(target.get_instance_id())
		AILogger.event("[SKILL] %s 暗影步 | 目标：%s | 距离：%.0f | 流血范围：%.0f" % [unit_name, target_name, shadow_step_target.distance_to(original_position), AoE_radius])
		if AIManager:
			AIManager.broadcast_text("[SKILL] %s 暗影步瞬移 | 目标：%s" % [unit_name, target_name])

	# 创建暗影轨迹（LV.2+）
	if shadow_trail_active:
		_create_shadow_trail(original_position, unit.global_position)

	# 延迟后返回原位
	await unit.get_tree().create_timer(1.5).timeout
	_return_to_original_position()

	is_shadow_stepping = false

func _return_to_original_position():
	"""返回原始位置"""
	if is_instance_valid(unit):
		# 返回时如果有轨迹，再次检查轨迹上的敌人
		if shadow_trail_active and trail_duration > 0:
			_check_trail_damage(original_position)

		unit.global_position = original_position

func _apply_bleed_stacks_to_nearby_enemies(pos: Vector2, radius: float, stacks: int):
	"""对范围内的敌人施加流血层数"""
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var hit_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(pos) <= radius:
			if enemy.has_method("add_bleed_stacks"):
				enemy.add_bleed_stacks(stacks, unit)
				hit_count += 1

	if hit_count > 0 and AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "影蝠"
		AILogger.event("[SKILL] %s 暗影步流血 | 范围：%.0f | 命中敌人：%d | 流血层数：%d" % [unit_name, radius, hit_count, stacks])

func _create_shadow_trail(start_pos: Vector2, end_pos: Vector2):
	"""创建暗影轨迹（LV.2+）- 对路径上的敌人施加减速和持续伤害"""
	# 存储轨迹信息供后续更新使用
	var trail_info = {
		"start": start_pos,
		"end": end_pos,
		"duration": trail_duration,
		"affected_enemies": []
	}

	# 立即对路径上的敌人施加效果
	_apply_trail_effect(start_pos, end_pos)

func _apply_trail_effect(start_pos: Vector2, end_pos: Vector2):
	"""对轨迹路径上的敌人施加减速和伤害"""
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var trail_width = 60.0
	var affected_count = 0
	var damage_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# 检查敌人是否在轨迹线段附近
		var dist_to_line = _point_to_line_distance(enemy.global_position, start_pos, end_pos)
		if dist_to_line <= trail_width:
			# 检查敌人是否在线段范围内（不是无限延伸的直线）
			var line_length = end_pos.distance_to(start_pos)
			if line_length > 0:
				var t = (enemy.global_position - start_pos).dot(end_pos - start_pos) / (line_length * line_length)
				if t >= 0 and t <= 1:
					# 施加减速效果（LV.2+）
					if unit.level >= 2:
						_apply_slow_debuff(enemy)

					# 施加轨迹伤害（LV.3）
					if unit.level >= 3 and trail_damage_percent > 0:
						var trail_damage = unit.damage * trail_damage_percent
						if enemy.has_method("take_damage"):
							enemy.take_damage(trail_damage, unit, "physical")
							damage_count += 1
							GameManager.spawn_floating_text(enemy.global_position, "-%d" % int(trail_damage), Color(0.6, 0.2, 0.8))

					affected_count += 1

	if affected_count > 0 and AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "影蝠"
		var effect_text = "减速" if unit.level >= 2 else ""
		if unit.level >= 3:
			effect_text += "+轨迹伤害" if effect_text else "轨迹伤害"
		AILogger.event("[SKILL] %s 暗影轨迹 | 影响敌人：%d | 效果：%s | 伤害次数：%d" % [unit_name, affected_count, effect_text, damage_count])

func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	"""计算点到线段的最短距离"""
	var line_vec = line_end - line_start
	var line_length_sq = line_vec.length_squared()

	if line_length_sq == 0:
		return point.distance_to(line_start)

	var t = max(0, min(1, (point - line_start).dot(line_vec) / line_length_sq))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

func _apply_slow_debuff(enemy: Node2D):
	"""施加减速效果"""
	if enemy.has_method("apply_status"):
		var slow_script = load("res://src/Scripts/Effects/SlowEffect.gd")
		if slow_script:
			enemy.apply_status(slow_script, {
				"duration": 2.0,
				"slow_factor": slow_factor
			})

func _update_shadow_trail(delta: float):
	"""更新暗影轨迹持续时间"""
	if trail_duration > 0:
		trail_duration -= delta
		if trail_duration <= 0:
			# 轨迹消失
			shadow_trail_active = false
			if AILogger:
				var unit_name = unit.type_key if unit and "type_key" in unit else "影蝠"
				AILogger.event("[SKILL] %s 暗影轨迹消失" % unit_name)

func _check_trail_damage(pos: Vector2):
	"""返回时检查轨迹伤害（LV.3）"""
	if unit.level < 3:
		return

	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var radius = 60.0
	var damage_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				var trail_damage = unit.damage * trail_damage_percent
				enemy.take_damage(trail_damage, unit, "physical")
				damage_count += 1
				GameManager.spawn_floating_text(enemy.global_position, "-%d" % int(trail_damage), Color(0.6, 0.2, 0.8))

	if damage_count > 0 and AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "影蝠"
		AILogger.event("[SKILL] %s 返回轨迹伤害 | 范围：%.0f | 命中：%d" % [unit_name, radius, damage_count])

func on_cleanup():
	# 清理定时器和状态
	shadow_step_timer = 0
	is_shadow_stepping = false
	shadow_trail_active = false
	trail_duration = 0
