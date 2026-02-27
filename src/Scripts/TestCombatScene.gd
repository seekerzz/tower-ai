extends Node2D

@onready var grid_manager = $GridManager
@onready var combat_manager = $CombatManager
const UNIT_SCENE = preload("res://src/Scenes/Game/Unit.tscn")
const ENEMY_SCENE = preload("res://src/Scenes/Game/Enemy.tscn")

func _ready():
	# 1. Sunflower (Production)
	grid_manager.place_unit("plant", -2, 0)

	# 2. Lion (Roar)
	grid_manager.place_unit("lion", 2, 0)

	# 3. Dragon (Breath)
	grid_manager.place_unit("dragon", 0, -2)

	# 4. Eel (Lightning Chain)
	grid_manager.place_unit("eel", 0, 2)

	# --- Spawns ---

	# Cannon Target (Right)
	spawn_test_enemy(Vector2(900, 360), "slime")

	# Void Targets (Top) - Cluster to suck
	spawn_test_enemy(Vector2(600, 100), "slime")
	spawn_test_enemy(Vector2(680, 100), "slime")

	# Tesla Targets (Bottom) - Chain
	spawn_test_enemy(Vector2(600, 600), "slime")
	spawn_test_enemy(Vector2(650, 600), "slime")
	spawn_test_enemy(Vector2(700, 600), "slime")

	# Start Wave manually
	GameManager.is_wave_active = true

	# Run for 5 seconds to observe production and mechanics
	await get_tree().create_timer(5.0).timeout
	print("Test Finished")
	get_tree().quit()

func spawn_test_enemy(pos, type):
	var enemy = ENEMY_SCENE.instantiate()
	enemy.setup(type, 1)
	enemy.global_position = pos
	combat_manager.add_child(enemy)

func _process(delta):
	pass
