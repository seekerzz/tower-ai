extends Button

var grid_x: int
var grid_y: int

func setup(x, y):
	grid_x = x
	grid_y = y
	text = "+"
	flat = true
	modulate = Color(1, 1, 1, 0.5)
	custom_minimum_size = Vector2(60, 60)

	pressed.connect(_on_pressed)

func _on_pressed():
	if GameManager.grid_manager:
		GameManager.grid_manager.on_ghost_clicked(grid_x, grid_y)
