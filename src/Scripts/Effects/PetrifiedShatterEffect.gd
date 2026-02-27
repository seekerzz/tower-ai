extends Node2D

var launch_direction: Vector2 = Vector2.RIGHT
var damage_percent: float = 0.1
var source_max_hp: float = 100
var enemy_texture: Texture2D = null
var enemy_color: Color = Color.GRAY

const BASE_SPEED: float = 300.0
const SPEED_VARIATION: float = 150.0
const LIFETIME: float = 3.0
const FRAGMENT_COUNT_MIN: int = 3
const FRAGMENT_COUNT_MAX: int = 6
const SPREAD_ANGLE: float = 30.0  # 度

var fragments: Array = []
var hit_enemies: Dictionary = {}

func _ready():
	if launch_direction == Vector2.ZERO:
		launch_direction = Vector2.RIGHT
	_create_fragments()

	# 延迟后开始淡出
	var timer = get_tree().create_timer(LIFETIME)
	timer.timeout.connect(_fade_out)

func _create_fragments():
	var count = randi_range(FRAGMENT_COUNT_MIN, FRAGMENT_COUNT_MAX)

	# 预定义几种碎块形状（相对坐标，-0.5到0.5范围）
	var shape_templates = [
		[Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0, 0.5)],  # 三角形
		[Vector2(-0.5, -0.5), Vector2(0.3, -0.5), Vector2(0.5, 0.5), Vector2(-0.3, 0.5)],  # 四边形1
		[Vector2(-0.3, -0.5), Vector2(0.5, -0.3), Vector2(0.3, 0.5), Vector2(-0.5, 0.3)],  # 四边形2
		[Vector2(0, -0.5), Vector2(0.5, -0.2), Vector2(0.3, 0.5), Vector2(-0.3, 0.5), Vector2(-0.5, -0.2)],  # 五边形
	]

	var texture_size = enemy_texture.get_size() if enemy_texture else Vector2(40, 40)
	var fragment_scale = 30.0  # 基础碎块大小

	for i in range(count):
		var shape_points = shape_templates[i % shape_templates.size()]
		var fragment = _create_single_fragment(i, count, shape_points, texture_size, fragment_scale)
		add_child(fragment)
		fragments.append(fragment)

func _create_single_fragment(index: int, total: int, shape_points: Array, tex_size: Vector2, scale: float) -> RigidBody2D:
	var fragment = RigidBody2D.new()
	fragment.collision_layer = 0  # 不与其他碎块碰撞
	fragment.collision_mask = 2   # 只检测敌人层

	# 创建碰撞形状
	var scaled_points = PackedVector2Array()
	for p in shape_points:
		scaled_points.append(p * scale)

	var collision_shape = CollisionPolygon2D.new()
	collision_shape.polygon = scaled_points
	fragment.add_child(collision_shape)

	# 创建视觉 - 使用Polygon2D显示纹理的一部分
	var visual = Polygon2D.new()
	visual.polygon = scaled_points
	visual.color = Color.GRAY  # 石化色调

	if enemy_texture:
		visual.texture = enemy_texture
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		# 计算UV坐标，将图像分割显示
		var cols = ceil(sqrt(float(total)))
		var rows = ceil(float(total) / cols)
		var col = index % int(cols)
		var row = index / int(cols)

		var u_size = 1.0 / cols
		var v_size = 1.0 / rows

		var uvs = PackedVector2Array()
		for p in shape_points:
			var u = (col + p.x + 0.5) / cols
			var v = (row + p.y + 0.5) / rows
			uvs.append(Vector2(u, v))
		visual.uv = uvs

	fragment.add_child(visual)

	# 设置物理属性
	fragment.mass = randf_range(0.5, 2.0)
	fragment.gravity_scale = 0.5

	# 计算飞散速度
	var spread_rad = deg_to_rad(SPREAD_ANGLE)
	var angle_offset = randf_range(-spread_rad, spread_rad)
	var fly_direction = launch_direction.rotated(angle_offset).normalized()

	var speed = (BASE_SPEED + randf_range(-SPEED_VARIATION, SPEED_VARIATION)) / fragment.mass
	fragment.linear_velocity = fly_direction * speed
	fragment.angular_velocity = randf_range(-10.0, 10.0)

	# 连接碰撞信号
	fragment.body_entered.connect(_on_fragment_hit_enemy.bind(fragment))

	# Enable contact monitoring for body_entered to work
	fragment.contact_monitor = true
	fragment.max_contacts_reported = 1

	return fragment

func _on_fragment_hit_enemy(enemy: Node, _fragment: RigidBody2D):
	if not enemy.is_in_group("enemies"):
		return
	if not enemy.has_method("take_damage"):
		return

	if not (enemy is Node2D):
		return

	var enemy_id = enemy.get_instance_id()
	if hit_enemies.has(enemy_id):
		return

	hit_enemies[enemy_id] = true

	var damage = source_max_hp * damage_percent
	enemy.take_damage(damage, null, "physical", self, 0)

	GameManager.spawn_floating_text(
		enemy.global_position,
		"石块冲击!",
		Color.GRAY
	)

func _fade_out():
	var tween = create_tween()
	tween.set_parallel(true)
	for fragment in fragments:
		if is_instance_valid(fragment):
			tween.tween_property(fragment, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
