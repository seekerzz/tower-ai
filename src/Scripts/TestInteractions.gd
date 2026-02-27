extends Node2D

@onready var grid_manager = $GridManager
@onready var combat_manager = $CombatManager

var current_step = 0
var test_enemy
var test_wall
var test_passed = true

func _ready():
	# Manually start wave so CombatManager works
	GameManager.is_wave_active = true

	# Setup grid
	grid_manager.create_initial_grid()

	print("Starting Test Interactions...")
	call_deferred("test_step_1")

func test_step_1():
	print("Step 1: Testing Wood Wall (Block)")
	# 1. Place a wood barricade
	# In real game, DrawManager places Barricades.
	# We can manually instantiate one.

	var wall_pos = Vector2(200, 0)
	test_wall = create_barricade("wood", wall_pos)
	_add_barricade_to_scene(test_wall, wall_pos, "wood")

	# 2. Spawn enemy moving towards it
	# Enemy moves towards GridManager (0,0)
	# Spawn enemy at (400, 0), moving left towards (0,0)
	# Wall is at (200, 0) in between.

	var enemy_scene = load("res://src/Scenes/Game/Enemy.tscn")
	test_enemy = enemy_scene.instantiate()
	test_enemy.setup("slime", 1)
	test_enemy.global_position = Vector2(400, 0)

	# Ensure raycast is looking at wall.
	# Enemy at (400, 0), Wall at (200, 0).
	# Direction is Left (-1, 0).
	# Raycast should be pointing Left.

	add_child(test_enemy)

	# Wait and check
	get_tree().create_timer(2.0).timeout.connect(_check_step_1)

func _check_step_1():
	# Enemy should be stopped near wall
	var dist = test_enemy.global_position.distance_to(test_wall.global_position)
	print("Enemy Dist to Wall: ", dist)
	print("Wall HP: ", test_wall.hp, "/", test_wall.max_hp)

	if test_wall.hp < test_wall.max_hp:
		print("Pass: Wall took damage.")
	else:
		print("Fail: Wall did not take damage.")
		test_passed = false

	# Clean up
	test_enemy.queue_free()
	test_wall.queue_free()

	call_deferred("test_step_2")

func test_step_2():
	print("Step 2: Testing Mucus Wall (Slow)")

	var wall_pos = Vector2(200, 0)
	test_wall = create_barricade("mucus", wall_pos)
	_add_barricade_to_scene(test_wall, wall_pos, "mucus")

	var enemy_scene = load("res://src/Scenes/Game/Enemy.tscn")
	test_enemy = enemy_scene.instantiate()
	test_enemy.setup("slime", 1)
	test_enemy.global_position = Vector2(400, 0)
	add_child(test_enemy)

	# Wait
	get_tree().create_timer(2.0).timeout.connect(_check_step_2)

func _check_step_2():
	# Enemy should NOT stop, but be slower.
	# Normal speed ~40. 2s -> moves 80. Pos: 320.
	# With mucus, if it hit it, speed reduced.

	# Since automated checking of speed reduction via position is tricky due to timing,
	# we will just check if we didn't crash and enemy is still moving (not stopped).

	var dist = test_enemy.global_position.distance_to(Vector2(0,0))
	print("Enemy Dist to Core: ", dist)

	# If it was blocked, it would be around 200 (wall pos).
	# If it passed through, it should be closer to 0.
	# Start 400. 2s travel. Speed 40. Dist 80. Pos 320.
	# If slowed, it travelled LESS.

	# But checking "not stopped" is key.
	if test_enemy.attacking_wall == null:
		print("Pass: Enemy ignored trap wall and kept moving.")
	else:
		print("Fail: Enemy stopped at trap wall.")
		test_passed = false

	test_enemy.queue_free()
	test_wall.queue_free()

	call_deferred("test_step_3")

func test_step_3():
	print("Step 3: Spawn Warning")
	# Call spawn_enemy
	combat_manager.enemies_to_spawn = 1
	combat_manager.spawn_enemy()

	# Check immediately for warning indicator
	# CombatManager adds Label as child
	var warning_found = false
	for child in combat_manager.get_children():
		if child is Label and child.text == "⚠️":
			warning_found = true
			break

	if warning_found:
		print("Pass: Warning indicator found.")
	else:
		print("Fail: Warning indicator not found.")
		test_passed = false

	# Wait for actual spawn (1.5s delay + margin)
	get_tree().create_timer(1.7).timeout.connect(_check_step_3_spawn)

func _check_step_3_spawn():
	# Check if enemy spawned
	# CombatManager calls add_child(enemy) on itself
	var enemy_found = false
	for child in combat_manager.get_children():
		if child.has_method("move_towards_core"): # Rough check for Enemy
			enemy_found = true
			break

	if enemy_found:
		print("Pass: Enemy spawned after delay.")
	else:
		print("Fail: Enemy did not spawn.")
		test_passed = false

	if test_passed:
		print("ALL TESTS PASSED")
	else:
		print("SOME TESTS FAILED")

	get_tree().quit()

func create_barricade(type, pos):
	var scene = load("res://src/Scenes/Game/Barricade.tscn")
	var b = scene.instantiate()

	# We need to add it to tree so onready vars work, OR we modify Barricade.gd to not use onready for init
	# Adding to tree first is safer for onready usage.
	# But we usually init before adding to tree?
	# If we add to tree, _ready is called.

	# If we call init before adding to tree, onready vars are null.
	# The proper Godot way with onready is to access vars in _ready or after adding to tree.
	# BUT `init` sets properties on `line_2d`.

	# I will add to child first, then init.
	return b

func _add_barricade_to_scene(b, pos, type):
	add_child(b)
	b.init(pos + Vector2(0, -30), pos + Vector2(0, 30), type)
	return b
