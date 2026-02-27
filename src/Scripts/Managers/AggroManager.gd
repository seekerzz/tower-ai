extends Node

var taunting_units: Dictionary = {}

signal target_changed(enemy: Node2D, new_target: Node2D)
signal taunt_started(unit: Node2D, radius: float)
signal taunt_ended(unit: Node2D)

func apply_taunt(unit: Node2D, radius: float, duration: float):
	if !is_instance_valid(unit): return

	taunting_units[unit] = radius
	taunt_started.emit(unit, radius)
	print("[AggroManager] Taunt started: ", unit.name if "name" in unit else unit, " radius=", radius, " duration=", duration)

	if duration > 0:
		await get_tree().create_timer(duration).timeout
		remove_taunt(unit)

func remove_taunt(unit: Node2D):
	if taunting_units.has(unit):
		taunting_units.erase(unit)
		taunt_ended.emit(unit)
		print("[AggroManager] Taunt ended: ", unit.name if "name" in unit else unit)

func get_target_for_enemy(enemy: Node2D) -> Node2D:
	if taunting_units.is_empty():
		return null

	var closest_unit: Node2D = null
	var min_dist: float = INF
	var units_to_remove = []

	for unit in taunting_units:
		if is_instance_valid(unit):
			var radius = taunting_units[unit]
			var dist = enemy.global_position.distance_to(unit.global_position)

			if dist <= radius:
				if dist < min_dist:
					min_dist = dist
					closest_unit = unit
		else:
			units_to_remove.append(unit)

	for u in units_to_remove:
		taunting_units.erase(u)

	return closest_unit
