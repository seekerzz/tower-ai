extends Control

func _can_drop_data(_at_position, data):
	# Only accept drag data from the bench
	if data and data.has("source") and data.source == "bench":
		return true
	return false

func _drop_data(_at_position, data):
	# Handle selling the bench unit
	var key = data.key
	var proto = Constants.UNIT_TYPES[key]
	var cost = proto.cost
	var refund = floor(cost * 0.5)

	GameManager.add_gold(refund)

	if GameManager.main_game:
		GameManager.main_game.remove_from_bench(data.index)

	# Show floating text at the center of the sell zone
	var center_pos = global_position + size / 2
	GameManager.spawn_floating_text(center_pos, "+%d G" % refund, Color.GOLD)
