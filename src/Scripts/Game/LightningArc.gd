extends Line2D

func setup(start_pos: Vector2, end_pos: Vector2):
	points = [start_pos, end_pos]
	width = 5.0
	default_color = Color(0.2, 0.8, 1.0, 1.0)

	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	tween.tween_interval(0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
