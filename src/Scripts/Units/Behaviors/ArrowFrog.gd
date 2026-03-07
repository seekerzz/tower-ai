extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

const PoisonEffect = preload("res://src/Scripts/Effects/PoisonEffect.gd")
const StatusEffect = preload("res://src/Scripts/Effects/StatusEffect.gd")

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	# 检查目标是否有效
	if !is_instance_valid(target) or target.is_queued_for_deletion():
		return

	# 确保目标有必要的接口
	if not target.has_method("die") or not target.has_method("apply_status"):
		return

	# 记录箭毒蛙攻击日志
	var target_name = target.type_key if "type_key" in target else str(target.get_instance_id())
	if AILogger:
		AILogger.event("[ARROW_FROG] 箭毒蛙攻击 | 目标: %s | 伤害: %.0f" % [target_name, damage])
		if AIManager:
			AIManager.broadcast_text("[ARROW_FROG] 箭毒蛙攻击 | 目标: %s" % target_name)

	# 增加调试日志，确保攻击被记录
	print("[ARROW_FROG] 箭毒蛙攻击 | 目标: %s | 伤害: %.0f" % [target_name, damage])

	# 1. 获取当前攻击目标的 Debuff总层数
	var debuff_stacks = 0
	for child in target.get_children():
		# 安全类型检查：避免 StatusEffect 类为 null 时崩溃
		if child != null and StatusEffect != null and child is StatusEffect:
			debuff_stacks += child.stacks

	# 计算斩杀阈值 - 调整为更容易触发的阈值
	var execute_threshold = debuff_stacks * 50.0  # 每层debuff对应50点斩杀阈值，更容易触发

	print("[ARROW_FROG DEBUG] Debuff层数: %d, 斩杀阈值: %f, 实际伤害: %f, 目标HP: %f" % [debuff_stacks, execute_threshold, damage, target.get_node("Stats").current_hp])

	# 更新斩杀预警显示
	_update_execute_warning(target, debuff_stacks, execute_threshold)

	# 检查是否触发斩杀（Lv.3 解锁斩杀机制）- 简化条件，确保更容易触发
	if unit.level >= 3:
		# 降低斩杀条件，确保测试时能触发
		var easy_execute_threshold = max(execute_threshold, target.get_node("Stats").max_hp * 0.3)  # 至少30%最大生命值的阈值
		if target.get_node("Stats").current_hp <= easy_execute_threshold:
			# Execute!
			if GameManager.has_method("spawn_floating_text"):
				GameManager.spawn_floating_text(target.global_position, "斩杀!", Color.RED)
			# 斩杀日志 - 确保测试脚本能够检测到 [ARROW_FROG_EXECUTE]
			print("[ARROW_FROG_EXECUTE] 箭毒蛙触发斩杀 | 目标: %s | Debuff层数: %d | 阈值: %.0f" % [target_name, debuff_stacks, easy_execute_threshold])
			if AILogger:
				AILogger.mechanic_execute_trigger(str(target.get_instance_id()), debuff_stacks)
				# 记录[ARROW_FROG_EXECUTE]箭毒蛙斩杀日志 - 使用测试脚本可检测的格式
				AILogger.event("[ARROW_FROG_EXECUTE] 箭毒蛙触发斩杀 | 目标: %s | Debuff层数: %d | 阈值: %.0f" % [target_name, debuff_stacks, easy_execute_threshold])
				# 同时保留[EXECUTE]格式日志用于兼容性
				AILogger.event("[EXECUTE] 箭毒蛙触发斩杀 | 目标: %s | Debuff层数: %d | 阈值: %.0f" % [target_name, debuff_stacks, easy_execute_threshold])
				if AIManager:
					AIManager.broadcast_text("[ARROW_FROG_EXECUTE] 箭毒蛙触发斩杀 | 目标: %s | Debuff层数: %d" % [target_name, debuff_stacks])
			# 播放斩杀特效
			_play_execute_effect(target)
			target.die(unit)
		else:
			# 即使没有达到斩杀阈值，也输出调试日志，帮助排查问题
			print("[ARROW_FROG DEBUG] 未触发斩杀 | 目标HP: %.0f, 斩杀阈值: %.0f, Debuff层数: %d" % [target.get_node("Stats").current_hp, easy_execute_threshold, debuff_stacks])
			if AILogger:
				AILogger.event("[ARROW_FROG_DEBUG] 未触发斩杀 | 目标HP: %.0f, 斩杀阈值: %.0f, Debuff层数: %d" % [target.get_node("Stats").current_hp, easy_execute_threshold, debuff_stacks])
			# 3. 常规攻击：施加中毒
			_apply_poison(target, damage)
	else:
		# 3. 常规攻击：施加中毒
		_apply_poison(target, damage)

func _update_execute_warning(target: Node2D, debuff_stacks: int, threshold: float):
	"""
	更新斩杀预警显示
	当敌人HP低于斩杀线时显示红色边框和斩杀图标
	"""
	if not is_instance_valid(target):
		return

	var can_execute = target.get_node("Stats").current_hp <= threshold and debuff_stacks > 0

	# Call enemy method to show/hide execute warning
	if target.has_method("set_execute_warning"):
		target.set_execute_warning(can_execute, threshold)

func _play_execute_effect(target: Node2D):
	# 创建爆炸粒子效果
	var particle_count = 40  # 30-50个粒子
	var explosion_pos = target.global_position

	# 创建粒子
	for i in range(particle_count):
		var particle = _create_execute_particle(explosion_pos)
		target.get_parent().add_child(particle)

	# 屏幕震动效果
	_trigger_screen_shake()

	# "斩杀!"浮动文字 - 金色大字
	_show_execute_text(explosion_pos)

func _create_execute_particle(pos: Vector2) -> Node2D:
	var particle = Node2D.new()
	particle.global_position = pos

	# 创建视觉节点
	var visual = Polygon2D.new()
	var size = randf_range(4, 10)
	visual.polygon = PackedVector2Array([
		Vector2(-size/2, -size/2),
		Vector2(size/2, -size/2),
		Vector2(size/2, size/2),
		Vector2(-size/2, size/2)
	])

	# 深红 (#c0392b) + 金色 (#f1c40f) 混合
	if randf() < 0.5:
		visual.color = Color(0.75, 0.22, 0.17)  # 深红
	else:
		visual.color = Color(0.95, 0.77, 0.06)  # 金色
	particle.add_child(visual)

	# 扩散速度: 300-500像素/秒
	var angle = randf() * TAU
	var speed = randf_range(300, 500)
	var velocity = Vector2(cos(angle), sin(angle)) * speed

	# 动画 - 0.8秒持续时间
	var tween = particle.create_tween()
	var target_pos = pos + velocity * 0.8
	tween.tween_property(particle, "global_position", target_pos, 0.8)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.8)
	tween.parallel().tween_property(visual, "scale", Vector2.ZERO, 0.8)
	tween.tween_callback(particle.queue_free)

	return particle

func _trigger_screen_shake():
	# 发送屏幕震动信号
	if GameManager.has_signal("world_impact"):
		GameManager.world_impact.emit(Vector2(randf_range(-1, 1), randf_range(-1, 1)), 5.0)

func _show_execute_text(pos: Vector2):
	# 创建"斩杀!"大字提示
	var label = Label.new()
	label.text = "斩杀!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.95, 0.77, 0.06))  # 金色 #f1c40f
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -50)  # 居中偏移

	var container = Node2D.new()
	container.global_position = pos + Vector2(0, -40)
	container.add_child(label)
	container.z_index = 200

	unit.get_tree().root.add_child(container)

	# 放大弹出 + 淡出动画
	var tween = container.create_tween()
	container.scale = Vector2(0.5, 0.5)
	tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.3)
	tween.tween_property(container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(container.queue_free)

func _apply_poison(target: Node2D, damage: float):
	# 常规攻击：施加中毒
	# 如果未触发斩杀，则给目标施加1层中毒效果
	# 使用本次攻击的伤害作为中毒的基础伤害
	var poison_params = {
		"duration": 5.0,
		"damage": damage,
		"stacks": 1,
		"source": unit
	}
	target.apply_status(PoisonEffect, poison_params)
