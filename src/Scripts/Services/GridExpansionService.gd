class_name GridExpansionService
extends RefCounted

var grid_manager: Node2D

func _init(owner: Node2D):
	grid_manager = owner

func toggle_expansion_mode():
	grid_manager.expansion_mode = !grid_manager.expansion_mode

	for key in grid_manager.tiles:
		if grid_manager.tiles[key].has_method("set_grid_visible"):
			grid_manager.tiles[key].set_grid_visible(grid_manager.expansion_mode)

	if grid_manager.expansion_mode:
		spawn_expansion_ghosts()
	else:
		clear_ghosts()

func spawn_expansion_ghosts():
	clear_ghosts()

	for key in grid_manager.tiles:
		var tile = grid_manager.tiles[key]

		if abs(tile.x) > 2 or abs(tile.y) > 2:
			continue

		if tile.state == "locked_inner" or tile.state == "locked_outer":
			var x = tile.x
			var y = tile.y
			var neighbors = [
				Vector2i(x+1, y), Vector2i(x-1, y),
				Vector2i(x, y+1), Vector2i(x, y-1)
			]

			var can_expand = false
			for n_pos in neighbors:
				var n_key = grid_manager.get_tile_key(n_pos.x, n_pos.y)
				if grid_manager.tiles.has(n_key):
					var n_tile = grid_manager.tiles[n_key]
					if n_tile.state == "unlocked":
						can_expand = true
						break

			if can_expand:
				var ghost = grid_manager.GHOST_TILE_SCRIPT.new()
				grid_manager.add_child(ghost)
				ghost.setup(tile.x, tile.y)

				var local_pos = grid_manager.grid_to_local(Vector2i(tile.x, tile.y))
				ghost.position = local_pos - (ghost.custom_minimum_size / 2)
				grid_manager.ghost_tiles.append(ghost)

func clear_ghosts():
	for ghost in grid_manager.ghost_tiles:
		ghost.queue_free()
	grid_manager.ghost_tiles.clear()

func _get_game_manager() -> Node:
	if Engine.get_main_loop() and Engine.get_main_loop() is SceneTree:
		return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameManager")
	return null

func on_ghost_clicked(x, y):
	var game_manager = _get_game_manager()
	if game_manager == null:
		return

	var cost = grid_manager.expansion_cost
	if game_manager.reward_manager and "rapid_expansion" in game_manager.reward_manager.acquired_artifacts:
		cost = int(cost * 0.7)

	if game_manager.gold >= cost:
		if game_manager.spend_gold(cost):
			grid_manager.expansion_cost += 10
			var key = grid_manager.get_tile_key(x, y)
			if grid_manager.tiles.has(key):
				var tile = grid_manager.tiles[key]
				tile.set_state("unlocked")
				if not grid_manager.active_territory_tiles.has(tile):
					grid_manager.active_territory_tiles.append(tile)

				if game_manager.reward_manager and "rapid_expansion" in game_manager.reward_manager.acquired_artifacts:
					game_manager.permanent_health_bonus += 50.0
					game_manager.max_core_health += 50.0
					game_manager.core_health += 50.0
					game_manager.resource_changed.emit()

			clear_ghosts()
			spawn_expansion_ghosts()
	else:
		var world_pos = grid_manager.get_world_pos_from_grid(Vector2i(x, y))
		game_manager.spawn_floating_text(world_pos, "Need Gold!", Color.RED)

func get_closest_unlocked_tile(world_pos: Vector2) -> Node2D:
	if grid_manager.active_territory_tiles.is_empty():
		var core_key = grid_manager.get_tile_key(0, 0)
		if grid_manager.tiles.has(core_key):
			return grid_manager.tiles[core_key]
		return null

	var closest_tile = null
	var min_dist_sq = INF

	for tile in grid_manager.active_territory_tiles:
		if not is_instance_valid(tile):
			continue
		if tile.state != "unlocked":
			continue

		var d2 = tile.global_position.distance_squared_to(world_pos)
		if d2 < min_dist_sq:
			min_dist_sq = d2
			closest_tile = tile

	return closest_tile
