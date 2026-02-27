extends Node2D

var grid_manager

func _ready():
	print("--- Starting TestTrapPlacement ---")

	# Verify GameManager presence (AutoLoad)
	if not has_node("/root/GameManager"):
		printerr("ERROR: GameManager AutoLoad not found. This test must be run in a context where AutoLoads are loaded (e.g. as a Scene).")
		return

	# Setup GridManager
	var gm_script = load("res://src/Scripts/GridManager.gd")
	grid_manager = gm_script.new()
	grid_manager.name = "TestGridManager"
	add_child(grid_manager)

	# Wait for _ready to complete
	await get_tree().process_frame

	test_can_place_item()
	# Because test_preview_update has awaits, we await it
	await test_preview_update()

	print("--- All Tests Completed ---")
	get_tree().quit()

func test_can_place_item():
	print("Running Test_Can_Place_Item")

	# Force create a test tile at (10, 10) to avoid conflict with initial grid
	# (10,10) is likely outside normal map, but GridManager handles arbitrary coordinates if we add them to tiles.
	# But create_tile checks bounds? No, just keys.
	grid_manager.create_tile(10, 10, "normal", "unlocked")
	var tile = grid_manager.tiles[grid_manager.get_tile_key(10, 10)]

	# 1. Test Empty Ground -> True
	var res = grid_manager.can_place_item_at(Vector2i(10, 10), "poison_trap")
	_assert(res, "Should allow placing trap on empty unlocked tile")

	# 2. Test Obstacle -> False
	var obs = Node2D.new()
	grid_manager.register_obstacle(Vector2i(10, 10), obs)
	res = grid_manager.can_place_item_at(Vector2i(10, 10), "poison_trap")
	_assert(not res, "Should NOT allow placing trap on obstacle")
	grid_manager.remove_obstacle(obs)
	obs.free()

	# 3. Test Unit -> False
	var unit = Node2D.new() # Mock Unit
	tile.unit = unit
	res = grid_manager.can_place_item_at(Vector2i(10, 10), "poison_trap")
	_assert(not res, "Should NOT allow placing trap on unit")
	tile.unit = null
	unit.free()

	# 4. Test Core Zone (Unlocked) -> False
	# We rely on existing grid generation for Core Zone testing.
	# (0,0) is core.
	if grid_manager.tiles.has("0,0"):
		res = grid_manager.can_place_item_at(Vector2i(0, 0), "poison_trap")
		_assert(not res, "Should NOT allow placing trap on Core")

func test_preview_update():
	print("Running Test_Preview_Update")

	var pos = Vector2i(10, 10)
	# Ensure it's valid
	var tile = grid_manager.tiles[grid_manager.get_tile_key(10, 10)]
	tile.unit = null

	# Call update
	# Mock world position
	var world_pos = Vector2(pos.x * 60, pos.y * 60)
	grid_manager.update_placement_preview(pos, world_pos, "poison_trap")

	var cursor = grid_manager.placement_preview_cursor
	_assert(cursor != null, "Cursor should be created")
	_assert(cursor.visible == true, "Cursor should be visible")
	_assert(cursor.position == Vector2(pos.x * 60, pos.y * 60), "Cursor position incorrect")

	var visual = cursor.get_node("Visual")
	# Should be green
	_assert(visual.color == Color(0, 1, 0, 0.4), "Visual should be green (valid)")

	# Make it invalid (Obstacle) and update
	var obs = Node2D.new()
	grid_manager.register_obstacle(pos, obs)
	grid_manager.update_placement_preview(pos, world_pos, "poison_trap")
	_assert(visual.color == Color(1, 0, 0, 0.4), "Visual should be red (invalid)")
	grid_manager.remove_obstacle(obs)
	obs.free()

	# Test Timeout
	print("Waiting for timeout...")
	# Wait for frames
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(cursor.visible == false, "Cursor should hide after timeout")

func _assert(condition, message):
	if not condition:
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)
