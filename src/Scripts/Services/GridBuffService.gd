class_name GridBuffService
extends RefCounted

var grid_manager: Node2D

func _init(owner: Node2D):
	grid_manager = owner

func recalculate_buffs():
	var processed_units = []
	for key in grid_manager.tiles:
		var tile = grid_manager.tiles[key]
		if tile.unit and not (tile.unit in processed_units):
			tile.unit.reset_stats()
			processed_units.append(tile.unit)

	for unit in processed_units:
		if unit.behavior:
			unit.behavior.broadcast_buffs()

		# Interaction Buffs
		var info = unit.get_interaction_info()
		if info.has_interaction and unit.interaction_target_pos != null:
			if grid_manager.is_neighbor(unit, unit.interaction_target_pos):
				apply_buff_to_specific_pos(unit.interaction_target_pos, info.buff_id, unit)

				if unit.unit_data.get("interaction_pattern") == "neighbor_pair":
					var neighbors = grid_manager._get_clockwise_neighbors(unit.grid_pos)
					var idx = neighbors.find(unit.interaction_target_pos)
					if idx != -1:
						var next_idx = (idx + 1) % neighbors.size()
						apply_buff_to_specific_pos(neighbors[next_idx], info.buff_id, unit)

	for unit in processed_units:
		unit.update_visuals()

	grid_manager.grid_updated.emit()

func apply_buff_to_specific_pos(target_pos: Vector2i, buff_id: String, provider_unit: Node2D = null):
	var key = grid_manager.get_tile_key(target_pos.x, target_pos.y)
	if grid_manager.tiles.has(key):
		var tile = grid_manager.tiles[key]
		var target_unit = tile.unit
		if target_unit == null and tile.occupied_by != Vector2i.ZERO:
			var origin_key = grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
			if grid_manager.tiles.has(origin_key):
				target_unit = grid_manager.tiles[origin_key].unit

		if target_unit:
			target_unit.apply_buff(buff_id, provider_unit)
