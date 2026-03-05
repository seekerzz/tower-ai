extends Control

# Background polygon
var color: Color = Color.DARK_SLATE_BLUE : set = set_color

func set_color(c):
	color = c
	queue_redraw()

func _draw():
	var w = size.x
	var h = size.y
	# [0,0], [width, 0], [width - 40, height], [0, height]
	var points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(w, 0),
		Vector2(w - 40, h),
		Vector2(0, h)
	])
	draw_colored_polygon(points, color)
