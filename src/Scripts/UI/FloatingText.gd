extends Node2D

@onready var label = $Label

# 物理属性
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 0.0
var friction: float = 0.0
var floor_y: float = 0.0
var mode: String = "impact" # impact(射击), gravity(金币), float(近战)

# 效果属性
var is_crit_hit: bool = false
var shake_amount: float = 2.0
var fade_speed: float = 3.0 # 默认淡出速度

func setup(value_str: String, color: Color, is_crit: bool = false, value_num: float = 0.0, direction: Vector2 = Vector2.ZERO):
	label.text = value_str
	label.modulate = color
	is_crit_hit = is_crit
	z_index = 200 if is_crit else 100

	# 1. 中心点设置
	if label.size == Vector2.ZERO:
		label.size = Vector2(100, 50)
	label.pivot_offset = label.size / 2.0

	# 2. 智能模式识别
	# 判断是否为资源（包含G或者+号开头通常是回血或金币）
	var is_resource = value_str.contains("G") or value_str.begins_with("+")
	
	if is_resource:
		# [模式 A: 掉落物/金币] - 抛物线跳动
		mode = "gravity"
		gravity = 2000.0 # 增加重力，让它掉得更快
		friction = 2.0
		floor_y = position.y + randf_range(10.0, 30.0)
		fade_speed = 8.0 # 快速消失
		
		# [修改点] 金币方向跟随子弹 + 散射 + 强制上抛
		if direction != Vector2.ZERO:
			# 1. 散射 (随机偏转 +/- 0.3 弧度)
			var spread = randf_range(-0.3, 0.3)
			var final_dir = direction.rotated(spread).normalized()
			
			# 2. 赋予速度
			# 水平方向跟随子弹方向
			velocity = final_dir * 400.0
			
			# 3. 强制上抛混合逻辑
			# 基础向上弹力(-400) + 子弹垂直方向的影响
			# 向上射击(y<0)会跳更高，向下射击(y>0)会压低高度但仍保持向上
			velocity.y = -400.0 + (final_dir.y * 200.0)
			
			# 兜底：确保至少有一定的向上跳跃力度，防止贴地
			if velocity.y > -200.0: velocity.y = -200.0
			
		else:
			# 无方向时的默认原地随机跳起
			velocity = Vector2(randf_range(-100, 100), -500.0)
		
	elif direction != Vector2.ZERO:
		# [模式 B: 远程射击] - 冲击模式
		mode = "impact"
		gravity = 0.0
		friction = 6.0
		
		# 只计算方向，不旋转节点(rotation)，保证文字永远正向
		var spread = randf_range(-0.2, 0.2)
		var final_dir = direction.rotated(spread).normalized()
		var speed = 800.0 if is_crit else 500.0
		velocity = final_dir * speed
		
	else:
		# [模式 C: 近战/默认] - 传统上浮模式
		mode = "float"
		gravity = 0.0
		friction = 3.0 # 适中阻力
		
		# 简单的向上飘，带一点点随机左右偏移
		velocity = Vector2(randf_range(-50, 50), -300.0 if is_crit else -200.0)

	# 3. 缩放动画
	var base_scale = clamp(1.0 + (value_num / 500.0), 1.0, 2.5)
	
	if is_resource:
		base_scale = 0.7 # 金币更小更精致
	elif is_crit:
		base_scale *= 1.5

	# 初始极小
	scale = Vector2(0.1, 0.1)

	var tween = create_tween()
	# 阶段1: 弹出
	tween.tween_property(self, "scale", Vector2(base_scale * 1.2, base_scale * 1.2), 0.05)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 阶段2: 回稳
	tween.tween_property(self, "scale", Vector2(base_scale, base_scale), 0.3)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# 4. 闪光 (仅伤害)
	if not is_resource:
		label.modulate = Color(2.0, 2.0, 2.0)
		var color_tween = create_tween()
		color_tween.tween_property(label, "modulate", color, 0.15)

func _process(delta):
	# === 物理逻辑 ===
	if mode == "gravity":
		# 抛物线逻辑
		velocity.y += gravity * delta
		position += velocity * delta
		
		if position.y >= floor_y and velocity.y > 0:
			position.y = floor_y
			velocity.y *= -0.4 # 减少反弹力度，更干脆
			velocity.x *= 0.6
			if abs(velocity.y) < 50: velocity = Vector2.ZERO
			
	elif mode == "impact":
		# 冲击逻辑 (强阻力)
		velocity = velocity.move_toward(Vector2.ZERO, friction * 200.0 * delta)
		position += velocity * delta
		
	elif mode == "float":
		# 上浮逻辑 (恒定向上减速)
		velocity.y = move_toward(velocity.y, 0, friction * 50.0 * delta) # 慢慢减速
		position += velocity * delta

	# === 暴击震动 ===
	# [修改]: 移除了原有的 is_crit_hit 随机抖动逻辑，仅保持居中
	label.position = -(label.size / 2.0)

	# === 淡出逻辑 ===
	# 允许根据不同模式判断开始淡出的时机
	var start_fade = false
	if mode == "gravity":
		# 金币落地停稳后，或者存在时间稍长后
		if velocity.length() < 10.0: start_fade = true
	elif mode == "float":
		# 上浮一定时间后(例如速度很慢了)
		if abs(velocity.y) < 50.0: start_fade = true
	else: # impact
		if velocity.length() < 50.0: start_fade = true
		
	if start_fade:
		modulate.a -= delta * fade_speed
		if modulate.a <= 0:
			queue_free()
