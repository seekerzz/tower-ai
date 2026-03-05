extends Control

var slot_index: int = -1

func _can_drop_data(_at_position, data):
	if !data or !data.has("source"): return false
	if data.source == "grid": return true
	return false

func _drop_data(_at_position, data):
	if data.source == "grid":
		# Use BoardController to move unit from grid to bench
		var grid_pos = data.unit.grid_pos if data.unit.has_method("get") and data.unit.get("grid_pos") else null
		if grid_pos != null:
			BoardController.try_move_unit("grid", grid_pos, "bench", slot_index)
