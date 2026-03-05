extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func broadcast_buffs():
	var buff = unit.unit_data.get("buff_id", "")
	if buff == "":
		buff = unit.unit_data.get("buffProvider", "")

	if buff == "": return

	var neighbors = unit._get_neighbor_units()
	for neighbor in neighbors:
		if neighbor != unit:
			neighbor.apply_buff(buff, unit)
