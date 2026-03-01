extends Control

var slot_index: int = -1

func _can_drop_data(_at_position, data):
	if !data or !data.has("source"): return false
	if data.source == "grid": return true
	return false

func _drop_data(_at_position, data):
	if data.source == "grid":
		var grid_pos = data.unit.grid_pos if data.unit.has_method("get") and data.unit.get("grid_pos") else null
		if grid_pos != null:
			if get_node_or_null("/root/ActionDispatcher"):
				get_node("/root/ActionDispatcher").execute_action({
					"type": "move_unit",
					"from_zone": "grid",
					"from_pos": {"x": grid_pos.x, "y": grid_pos.y},
					"to_zone": "bench",
					"to_pos": slot_index
				})
			else:
				BoardController.try_move_unit("grid", grid_pos, "bench", slot_index)
