extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name ForestSprite

var debuff_types: Array[String] = ["poison", "burn", "bleed", "slow"]

func get_debuff_chance() -> float:
	if unit.level >= 3:
		return 0.15
	elif unit.level >= 2:
		return 0.12
	return 0.08

func broadcast_buffs():
	var range_val = 150.0
	var units = unit.get_tree().get_nodes_in_group("units")
	for u in units:
		if u == unit: continue
		if u.global_position.distance_to(unit.global_position) <= range_val:
			if u.has_method("apply_buff"):
				u.apply_buff("forest_blessing", unit)

func on_tick(delta: float):
	# Periodically rebroadcast to catch new units or moving units
	# broadcast_buffs() is called by Unit.gd on stat reset, but might not be enough if units move dynamically
	# However, standard behavior relies on broadcast_buffs chain.
	# We can just rely on standard flow.
	pass
