extends Node2D

func _ready():
	print("Starting Bench Test Scene")

	# Wait for children to be ready
	await get_tree().process_frame

	var main_game = $MainGame
	var grid_manager = $MainGame/GridManager
	var shop = $MainGame/CanvasLayer/Shop

	# Verify Initial State
	print("Bench Size: ", main_game.bench.size())

	# Test 1: Add to bench via API
	print("Test 1: Add to Bench")
	var success = main_game.add_to_bench("squirrel")
	if success and main_game.bench[0] != null and main_game.bench[0].key == "squirrel":
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

	# Check tiles before drop
	# Squirrel is 1x1. Placed at 1,1.
	# But place_unit handles size.
	# Let's check unit.grid_pos

	# Simulate drag drop
	# try_add_to_bench_from_grid calls queue_free().
	# But queue_free happens at end of frame.
	# And MainGame.gd:try_add_to_bench_from_grid DOES NOT call GridManager to clear tiles!
	# The logic in Unit.gd end_drag handles `grid_manager.handle_unit_drop`.
	# But `try_add_to_bench_from_grid` assumes the unit is just "added to bench".
	# It doesn't tell grid to remove it.
	# We need to fix MainGame.gd or Unit.gd logic to clear grid tiles when moving to bench.

	var dropped = main_game.try_add_to_bench_from_grid(unit)

	# We need to manually clear tiles if try_add_to_bench_from_grid doesn't do it.
	# But wait, the test says "FAIL: Grid tile not cleared".
	# That means unit is still referenced in tile.

	if dropped:
		print("PASS: Grid unit moved to bench")

		# Check if unit is still in tile
		# Since MainGame didn't clear tiles, we expect this to fail unless we fixed MainGame.

		# FORCE manual clear for this test script until I fix the code,
		# OR assert failure and fix code.
		# The task is to "Implement", so I should fix the code.

		if tile.unit == null:
			print("PASS: Grid tile cleared")
		else:
			print("FAIL: Grid tile not cleared")
			# We will fix this in MainGame.gd or Unit.gd
			# For now, let's quit to fail.
			get_tree().quit(1)
			return

	else:
		print("FAIL: Drop rejected")
		get_tree().quit(1)

	# Test 3: Bench -> Grid
	print("Test 3: Bench -> Grid")
	# We have a unit in bench[0] ("squirrel")
	# We want to place it at 2,2

	var ghost = Node2D.new()
	var target_x = -2 # Safe spot
	var target_y = -2
	var tile_size = 60
	var unit_w = 1
	var unit_h = 1

	var center_x = (target_x * tile_size) + ((unit_w-1) * tile_size * 0.5)
	var center_y = (target_y * tile_size) + ((unit_h-1) * tile_size * 0.5)

	ghost.global_position = grid_manager.to_global(Vector2(center_x, center_y))
	add_child(ghost)

	var placed = grid_manager.handle_bench_drop(ghost, "squirrel", 0)
	if placed:
		if main_game.bench[0] == null:
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
		print("FAIL: Bench drop failed")
		get_tree().quit(1)

	print("ALL TESTS PASSED")
	get_tree().quit()
