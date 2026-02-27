extends Control

var slot_index: int = -1

func _can_drop_data(_at_position, data):
	if !data or !data.has("source"): return false
	if data.source == "grid": return true
	return false

func _drop_data(_at_position, data):
	if data.source == "grid":
		if GameManager.main_game and GameManager.main_game.has_method("move_unit_from_grid_to_bench"):
			GameManager.main_game.move_unit_from_grid_to_bench(data.unit, slot_index)
