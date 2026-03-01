extends Node2D

func _ready():
	print("Starting Bench Test Scene")

	# Wait for children to be ready
	await get_tree().process_frame

	var main_game = $MainGame
	var grid_manager = $MainGame/GridManager
	var shop = $MainGame/CanvasLayer/Shop

	# Verify Initial State via SessionData
	print("Bench Size: ", Constants.BENCH_SIZE)

	# Test 1: Add to bench via BoardController
	print("Test 1: Add to Bench")
	# Set up shop and buy a unit
	if GameManager.session_data:
		GameManager.session_data.set_shop_unit(0, "squirrel")
		ActionDispatcher.buy_unit(0)

	var bench_unit = GameManager.session_data.get_bench_unit(0) if GameManager.session_data else null
	if bench_unit != null and bench_unit.key == "squirrel":
		print("PASS: Added to bench")
	else:
		print("FAIL: Add to bench failed")
		get_tree().quit(1)

	# Test 2: Drag from Grid to Bench
	print("Test 2: Grid -> Bench")
	# First place a unit on grid
	grid_manager.place_unit("squirrel", 1, 1)

	var tile = grid_manager.tiles["1,1"]
	var unit = tile.unit
	if unit == null:
		print("FAIL: Could not place unit on grid")
		get_tree().quit(1)

	# Move unit from grid to bench using BoardController
	var result = ActionDispatcher.try_move_unit("grid", Vector2i(1, 1), "bench", 1)

	if result.success:
		print("PASS: Grid unit moved to bench")

		# Check if unit is still in tile
		if tile.unit == null:
			print("PASS: Grid tile cleared")
		else:
			print("FAIL: Grid tile not cleared")
			get_tree().quit(1)
			return

	else:
		print("FAIL: Move rejected - ", result.get("error_message", ""))
		get_tree().quit(1)

	# Test 3: Bench -> Grid
	print("Test 3: Bench -> Grid")
	# We have a unit in bench[0] ("squirrel")
	# We want to place it at -2,-2

	result = ActionDispatcher.try_move_unit("bench", 0, "grid", Vector2i(-2, -2))

	if result.success:
		if GameManager.session_data.get_bench_unit(0) == null:
			print("PASS: Removed from bench")
		else:
			print("FAIL: Not removed from bench")
			get_tree().quit(1)

		if grid_manager.tiles["-2,-2"].unit != null:
			print("PASS: Placed on grid")
		else:
			print("FAIL: Not placed on grid")
			get_tree().quit(1)
	else:
		print("FAIL: Bench drop failed - ", result.get("error_message", ""))
		get_tree().quit(1)

	print("ALL TESTS PASSED")
	get_tree().quit()
