extends Node2D

var color: Color = Color.WHITE
var shape_type: String = "slash"

func configure(type: String, col: Color):
	shape_type = type
	color = col
	queue_redraw()

func play():
	# Initial state
	scale = Vector2.ZERO
	modulate.a = 1.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Move slightly forward in the direction of rotation
	var move_vec = Vector2.RIGHT.rotated(rotation) * 20.0
	tween.tween_property(self, "position", position + move_vec, 0.2)

	await tween.finished
	queue_free()

func _draw():
	if shape_type == "cross":
		draw_cross_slash()
	elif shape_type == "bite":
		draw_bite()
	else:
		draw_slash()

func draw_slash():
	# Draw a white crescent/fan shape simulating a slash
	var center = Vector2.ZERO
	var radius = 20.0
	var start_angle = -PI / 3
	var end_angle = PI / 3
	var point_count = 32

	var points = PackedVector2Array()

	for i in range(point_count + 1):
		var t = float(i) / point_count
		var angle = lerp(start_angle, end_angle, t)
		var dir = Vector2(cos(angle), sin(angle))

		# Taper thickness: thick in middle (t=0.5), thin at edges
		var thickness = 10.0 * sin(t * PI)

		points.append(dir * (radius + thickness / 2.0))

	# Create inner edge
	for i in range(point_count, -1, -1):
		var t = float(i) / point_count
		var angle = lerp(start_angle, end_angle, t)
		var dir = Vector2(cos(angle), sin(angle))

		var thickness = 10.0 * sin(t * PI)
		points.append(dir * (radius - thickness / 2.0))

	draw_colored_polygon(points, color)

func draw_cross_slash():
	# Save current transform
	draw_set_transform_matrix(Transform2D())

	# Rotate -45 deg
	draw_set_transform(Vector2.ZERO, deg_to_rad(-45), Vector2.ONE)
	draw_slash()

	# Rotate +45 deg
	draw_set_transform(Vector2.ZERO, deg_to_rad(45), Vector2.ONE)
	draw_slash()

	# Reset
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_bite():
	# Draw two arcs representing a bite
	var width = 20.0
	var height = 15.0

	# Top teeth
	var top_points = PackedVector2Array()
	top_points.append(Vector2(-width, -height))
	top_points.append(Vector2(-width/2, -5))
	top_points.append(Vector2(0, -height))
	top_points.append(Vector2(width/2, -5))
	top_points.append(Vector2(width, -height))
	top_points.append(Vector2(width, -height-5))
	top_points.append(Vector2(-width, -height-5))
	draw_colored_polygon(top_points, color)

	# Bottom teeth
	var bot_points = PackedVector2Array()
	bot_points.append(Vector2(-width, height))
	bot_points.append(Vector2(-width/2, 5))
	bot_points.append(Vector2(0, height))
	bot_points.append(Vector2(width/2, 5))
	bot_points.append(Vector2(width, height))
	bot_points.append(Vector2(width, height+5))
	bot_points.append(Vector2(-width, height+5))
	draw_colored_polygon(bot_points, color)
