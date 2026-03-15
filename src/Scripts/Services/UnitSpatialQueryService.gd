extends RefCounted
class_name UnitSpatialQueryService

var unit: Node2D

func _init(target_unit: Node2D):
	unit = target_unit

func get_neighbor_units() -> Array:
	var list: Array = []
	if !GameManager.grid_manager:
		return list

	var cx = unit.grid_pos.x
	var cy = unit.grid_pos.y

	var neighbors_pos: Array = [
		Vector2i(cx - 1, cy - 1),
		Vector2i(cx, cy - 1),
		Vector2i(cx + 1, cy - 1),
		Vector2i(cx - 1, cy),
		Vector2i(cx + 1, cy),
		Vector2i(cx - 1, cy + 1),
		Vector2i(cx, cy + 1),
		Vector2i(cx + 1, cy + 1)
	]

	for n_pos in neighbors_pos:
		var key = GameManager.grid_manager.get_tile_key(n_pos.x, n_pos.y)
		if GameManager.grid_manager.tiles.has(key):
			var tile = GameManager.grid_manager.tiles[key]
			var u = tile.unit
			if u == null and tile.occupied_by != Vector2i.ZERO:
				var origin_key = GameManager.grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if GameManager.grid_manager.tiles.has(origin_key):
					u = GameManager.grid_manager.tiles[origin_key].unit

			if u and is_instance_valid(u) and not (u in list):
				list.append(u)
	return list

func get_units_in_cell_range(center_unit: Node2D, cell_range: int, excluded_unit: Node2D = unit) -> Array:
	var result: Array = []
	if not GameManager.grid_manager:
		return result

	if not ("grid_pos" in center_unit):
		return result

	var center_x = center_unit.grid_pos.x
	var center_y = center_unit.grid_pos.y

	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		if tile.unit and is_instance_valid(tile.unit) and tile.unit != excluded_unit:
			var dist = abs(tile.x - center_x) + abs(tile.y - center_y)
			if dist <= cell_range:
				result.append(tile.unit)

	return result
