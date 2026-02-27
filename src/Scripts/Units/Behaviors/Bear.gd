extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func on_skill_activated():
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if unit.global_position.distance_to(enemy.global_position) <= unit.range_val:
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(2.0)
