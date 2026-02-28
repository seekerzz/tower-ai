extends Area2D

var type: String
var props: Dictionary

@onready var collision_shape = $CollisionShape2D
# @onready var line_2d = $Line2D # Deprecated
var visual_rect: ColorRect = null

var trap_timer: float = 0.0
var is_triggered: bool = false
var flash_timer: float = 0.0

# Signal for trap trigger - used by LureSnake
signal trap_triggered(enemy: Node2D, trap_position: Vector2)

func init(grid_pos: Vector2i, type_key: String):
	type = type_key
	if Constants.BARRICADE_TYPES.has(type_key):
		props = Constants.BARRICADE_TYPES[type_key]

		var tile_size = Constants.TILE_SIZE
		var offset = Vector2(-tile_size/2.0, -tile_size/2.0)

		# Setup Visuals
		var label = Label.new()
		label.text = props.get("icon", "?")
		label.add_theme_font_size_override("font_size", 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(tile_size, tile_size)
		label.position = offset
		add_child(label)

		# Hide Line2D if it exists
		if has_node("Line2D"):
			$Line2D.visible = false

		# Setup Physics
		var rect = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		collision_shape.shape = rect

		# Collision Settings
		# Detect Enemies (Layer 2)
		collision_layer = 4 # Trap Layer
		collision_mask = 2 # Enemy Layer
		monitoring = true
		monitorable = true

		body_entered.connect(_on_body_entered)

		# Snowball Trap Logic: Start Timer
		if props.get("type") == "trap_freeze":
			trap_timer = 3.0
			GameManager.spawn_floating_text(global_position, "3...", Color.WHITE)

	else:
		push_error("Invalid barricade type: " + type_key)

func _process(delta):
	if !props: return

	# Continuous Effect Application (moved from Enemy.check_traps)
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.has_method("handle_environmental_impact"):
			body.handle_environmental_impact(self)

	# Snowball Trap Logic
	if props.get("type") == "trap_freeze" and !is_triggered:
		trap_timer -= delta
		flash_timer += delta

		# Visual Feedback: Flashing
		# Frequency increases as timer decreases
		var frequency = 5.0 + (3.0 - trap_timer) * 5.0
		var alpha = 0.5 + 0.5 * sin(flash_timer * frequency)
		modulate.a = alpha

		if trap_timer <= 0:
			trigger_freeze_explosion()

func trigger_freeze_explosion():
	is_triggered = true
	GameManager.spawn_floating_text(global_position, "Freeze!", Color.CYAN)

	# Visual Effect
	spawn_splash_effect(global_position)

	# Logic: Freeze enemies in 3x3 range
	var center_pos = global_position
	var range_sq = (Constants.TILE_SIZE * 1.5) ** 2

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.global_position.distance_squared_to(center_pos) <= range_sq:
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(2.0)
			elif enemy.has_method("apply_stun"):
				enemy.apply_stun(2.0)

	if GameManager.grid_manager:
		GameManager.grid_manager.remove_obstacle(self)
	queue_free()

func spawn_splash_effect(pos: Vector2):
	var color = props.get("color", Color.WHITE)
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	get_parent().add_child(effect)
	effect.global_position = pos
	effect.configure("cross", color)
	effect.scale = Vector2(2, 2)
	effect.play()

	# 根据陷阱类型播放独特视觉特效
	_play_trap_trigger_effect(pos)

func _play_trap_trigger_effect(pos: Vector2):
	var trap_type = props.get("type", "")

	match trap_type:
		"slow":
			_play_slime_trap_effect(pos)
		"poison":
			_play_poison_trap_effect(pos)
		"reflect":
			_play_thorn_trap_effect(pos)
		"trap_freeze":
			_play_freeze_trap_effect(pos)

func _play_slime_trap_effect(pos: Vector2):
	# 粘液陷阱: 绿色粘液飞溅 + 粘滞效果
	var particle_count = 12
	for i in range(particle_count):
		var particle = _create_trap_particle(pos, Color(0.2, 0.8, 0.3, 0.8), 5, 15)
		get_parent().add_child(particle)

	# 粘液附着效果 - 绿色圆圈扩散
	var slime_ring = _create_expanding_ring(pos, Color(0.2, 0.8, 0.3, 0.5), 60)
	get_parent().add_child(slime_ring)

	# 文字提示
	GameManager.spawn_floating_text(pos + Vector2(0, -20), "粘滞!", Color(0.2, 0.8, 0.3))

func _play_poison_trap_effect(pos: Vector2):
	# 毒雾陷阱: 绿色毒雾爆发 + 毒雾缭绕
	var particle_count = 15
	for i in range(particle_count):
		var particle = _create_trap_particle(pos, Color(0.18, 0.8, 0.44, 0.7), 4, 12, true)
		get_parent().add_child(particle)

	# 毒雾缭绕效果
	var mist = _create_mist_effect(pos, Color(0.18, 0.8, 0.44, 0.4))
	get_parent().add_child(mist)

	# 文字提示
	GameManager.spawn_floating_text(pos + Vector2(0, -20), "毒雾!", Color(0.18, 0.8, 0.44))

func _play_thorn_trap_effect(pos: Vector2):
	# 荆棘陷阱: 尖刺突出动画 + 红色闪光
	var spike_count = 6
	for i in range(spike_count):
		var angle = (float(i) / spike_count) * TAU
		var spike = _create_spike(pos, angle)
		get_parent().add_child(spike)

	# 红色闪光
	var flash = _create_flash_effect(pos, Color(0.9, 0.2, 0.2, 0.6))
	get_parent().add_child(flash)

	# 文字提示
	GameManager.spawn_floating_text(pos + Vector2(0, -20), "荆棘!", Color(0.9, 0.2, 0.2))

func _play_freeze_trap_effect(pos: Vector2):
	# 雪球陷阱: 冰霜扩散 + 雪花飞溅
	var particle_count = 20
	for i in range(particle_count):
		var particle = _create_snowflake_particle(pos)
		get_parent().add_child(particle)

	# 冰霜扩散效果
	var frost = _create_expanding_ring(pos, Color(0.6, 0.9, 1.0, 0.6), 100)
	get_parent().add_child(frost)

	# 文字提示
	GameManager.spawn_floating_text(pos + Vector2(0, -20), "冰霜!", Color(0.6, 0.9, 1.0))

func _create_trap_particle(pos: Vector2, color: Color, min_size: float, max_size: float, floating: bool = false) -> Node2D:
	var particle = Node2D.new()
	particle.global_position = pos

	var visual = Polygon2D.new()
	var size = randf_range(min_size, max_size)
	visual.polygon = PackedVector2Array([
		Vector2(-size/2, -size/2),
		Vector2(size/2, -size/2),
		Vector2(size/2, size/2),
		Vector2(-size/2, size/2)
	])
	visual.color = color
	particle.add_child(visual)

	# 随机方向和速度
	var angle = randf() * TAU
	var speed = randf_range(80, 180)
	var velocity = Vector2(cos(angle), sin(angle)) * speed

	# 动画
	var tween = particle.create_tween()
	var target_pos = pos + velocity * randf_range(0.4, 0.8)

	if floating:
		# 漂浮效果 - 向上飘
		target_pos = pos + Vector2(randf_range(-30, 30), -randf_range(40, 80))
		tween.tween_property(particle, "global_position", target_pos, 0.8)
		tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.8)
	else:
		tween.tween_property(particle, "global_position", target_pos, 0.5)
		tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.5)

	tween.tween_callback(particle.queue_free)

	return particle

func _create_expanding_ring(pos: Vector2, color: Color, max_radius: float) -> Node2D:
	var ring = Node2D.new()
	ring.global_position = pos

	var visual = Polygon2D.new()
	var points = PackedVector2Array()
	var segments = 24
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * max_radius)
	visual.polygon = points
	visual.color = color
	ring.add_child(visual)

	# 动画: 扩散并淡出
	ring.scale = Vector2(0.1, 0.1)
	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.4)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)

	return ring

func _create_mist_effect(pos: Vector2, color: Color) -> Node2D:
	var mist = Node2D.new()
	mist.global_position = pos

	# 创建多个小圆圈模拟毒雾
	for i in range(5):
		var cloud = Polygon2D.new()
		var points = PackedVector2Array()
		var radius = randf_range(20, 35)
		var segments = 12
		for j in range(segments):
			var angle = (float(j) / segments) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		cloud.polygon = points
		cloud.color = color
		cloud.position = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		mist.add_child(cloud)

	# 动画: 缓慢扩散并淡出
	var tween = mist.create_tween()
	tween.tween_property(mist, "scale", Vector2(1.5, 1.5), 1.0)
	tween.parallel().tween_property(mist, "modulate:a", 0.0, 1.0)
	tween.tween_callback(mist.queue_free)

	return mist

func _create_spike(pos: Vector2, angle: float) -> Node2D:
	var spike = Node2D.new()
	spike.global_position = pos
	spike.rotation = angle

	# 创建尖刺形状
	var visual = Polygon2D.new()
	var length = randf_range(25, 40)
	visual.polygon = PackedVector2Array([
		Vector2(0, -5),
		Vector2(length, 0),
		Vector2(0, 5)
	])
	visual.color = Color(0.4, 0.2, 0.1, 0.9)  # 深棕色
	spike.add_child(visual)

	# 动画: 从中心弹出
	spike.scale = Vector2(0, 1)
	var tween = spike.create_tween()
	tween.tween_property(spike, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(spike, "scale", Vector2(0, 1), 0.15)
	tween.tween_callback(spike.queue_free)

	return spike

func _create_flash_effect(pos: Vector2, color: Color) -> Node2D:
	var flash = Node2D.new()
	flash.global_position = pos

	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-30, -30),
		Vector2(30, -30),
		Vector2(30, 30),
		Vector2(-30, 30)
	])
	visual.color = color
	flash.add_child(visual)

	# 动画: 快速闪烁
	var tween = flash.create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.1)
	tween.tween_property(visual, "modulate:a", 0.6, 0.05)
	tween.tween_property(visual, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)

	return flash

func _create_snowflake_particle(pos: Vector2) -> Node2D:
	var particle = Node2D.new()
	particle.global_position = pos

	# 创建雪花形状 (六角星)
	var visual = Polygon2D.new()
	var points = PackedVector2Array()
	var outer_r = randf_range(6, 10)
	var inner_r = outer_r * 0.4
	for i in range(12):
		var angle = (float(i) / 12) * TAU
		var r = outer_r if i % 2 == 0 else inner_r
		points.append(Vector2(cos(angle), sin(angle)) * r)
	visual.polygon = points
	visual.color = Color(0.8, 0.95, 1.0, 0.9)  # 冰蓝色
	particle.add_child(visual)

	# 随机飞散
	var angle = randf() * TAU
	var speed = randf_range(100, 250)
	var velocity = Vector2(cos(angle), sin(angle)) * speed

	# 动画
	var tween = particle.create_tween()
	var target_pos = pos + velocity * 0.6
	tween.tween_property(particle, "global_position", target_pos, 0.6)
	tween.parallel().tween_property(particle, "rotation", randf_range(-PI, PI), 0.6)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.6)
	tween.tween_callback(particle.queue_free)

	return particle

func _on_body_entered(body):
	# Emit signal for any enemy entering trap - used by LureSnake
	if body.is_in_group("enemies"):
		emit_signal("trap_triggered", body, global_position)

	if props.get("type") == "reflect":
		if body.has_method("handle_environmental_impact"):
			body.handle_environmental_impact(self)
