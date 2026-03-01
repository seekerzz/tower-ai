extends Control

func _can_drop_data(_at_position, data):
	# Only accept drag data from the bench
	if data and data.has("source") and data.source == "bench":
		return true
	return false

func _drop_data(_at_position, data):
	var index = data.index

	if get_node_or_null("/root/ActionDispatcher"):
		get_node("/root/ActionDispatcher").execute_action({
			"type": "sell_unit",
			"zone": "bench",
			"pos": index
		})
	elif BoardController:
		BoardController.sell_unit("bench", index)
