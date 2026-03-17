extends SceneTree

func _init():
	call_deferred("run_test")

func run_test():
	print("\n--- Starting Damage Lifecycle Test ---\n")

	var root = get_root()

	test_iron_turtle_reduction(root)
	test_hedgehog_reflection(root)
	test_firefly_blind(root)

	print("\n--- Damage Lifecycle Test Finished ---\n")
	quit()

func test_iron_turtle_reduction(parent):
	print("[Test] Testing Iron Turtle Reduction...")
	var unit = create_unit("iron_turtle", parent)
	if not unit: return

	# Test Level 1 (DR 15)
	unit.level = 1
	unit.behavior.on_setup()
	unit.take_damage(50.0) # Expected 50 - 15 = 35

	# Test Level 2 (DR 25)
	unit.level = 2
	unit.behavior.on_setup()
	unit.take_damage(50.0) # Expected 50 - 25 = 25

	unit.free()

func test_hedgehog_reflection(parent):
	print("[Test] Testing Hedgehog Reflection...")
	var unit = create_unit("hedgehog", parent)
	if not unit: return
	unit.behavior.reflect_chance = 1.0 # Force reflection for test

	var mock_enemy = CharacterBody2D.new()
	mock_enemy.name = "MockEnemy"
	mock_enemy.set_script(load("res://src/Scripts/Enemy.gd"))
	parent.add_child(mock_enemy)

	unit.take_damage(20.0, mock_enemy)

	mock_enemy.free()
	unit.free()

func test_firefly_blind(parent):
	print("[Test] Testing Firefly Blind & Miss...")
	var firefly = create_unit("firefly", parent)
	var turtle = create_unit("iron_turtle", parent)
	if not firefly or not turtle: return

	var mock_enemy = CharacterBody2D.new()
	mock_enemy.name = "BlindedEnemy"
	mock_enemy.set_script(load("res://src/Scripts/Enemy.gd"))
	parent.add_child(mock_enemy)

	# Firefly hits enemy to blind it
	firefly.behavior.on_projectile_hit(mock_enemy, 0.0, null)

	print("[Test] Enemy blind_timer: ", mock_enemy.blind_timer)

	# Turtle takes damage from blinded enemy
	# We'll trigger it multiple times to see "Miss" in logs (since it's 50% chance)
	for i in range(10):
		turtle.take_damage(10.0, mock_enemy)

	mock_enemy.free()
	turtle.free()
	firefly.free()

func create_unit(key: String, parent):
	var unit_scene = load("res://src/Scenes/Game/Unit.tscn")
	var unit_instance = unit_scene.instantiate()
	parent.add_child(unit_instance)
	if unit_instance.has_method("setup"):
		unit_instance.setup(key)
		return unit_instance
	else:
		print("Error: Unit instance does not have setup method")
		unit_instance.free()
		return null
