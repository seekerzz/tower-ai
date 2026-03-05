extends Node2D

@onready var grid_manager = $GridManager
@onready var camera = $Camera2D

func _ready():
	# Test: Place some units
	grid_manager.place_unit("squirrel", 0, 1)
	grid_manager.place_unit("octopus", 1, 0)

	# Test: Place large unit (All units currently 1x1, so just place another one)
	grid_manager.create_tile(0, 2)
	grid_manager.create_tile(1, 2)
	grid_manager.create_tile(0, 3)
	grid_manager.create_tile(1, 3)

	if grid_manager.place_unit("lion", 0, 2):
		print("Placed Lion!")
	else:
		print("Failed to place Lion")

func _process(delta):
	# Simple camera movement
	if Input.is_action_pressed("ui_right"): camera.position.x += 200 * delta
	if Input.is_action_pressed("ui_left"): camera.position.x -= 200 * delta
	if Input.is_action_pressed("ui_down"): camera.position.y += 200 * delta
	if Input.is_action_pressed("ui_up"): camera.position.y -= 200 * delta
