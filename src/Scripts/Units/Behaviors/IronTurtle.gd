extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var damage_reduction: float = 20.0

func on_setup():
	damage_reduction = unit.unit_data.get("flat_amount", 20.0)

func on_damage_taken(amount: float, source: Node) -> float:
	var reduced = max(0, amount - damage_reduction)

	if unit.level >= 3 and reduced <= 0 and amount > 0:
		var heal_amount = GameManager.max_core_health * 0.005
		GameManager.heal_core(heal_amount)
		unit.spawn_buff_effect("💖")

	# Apply reflection damage if source is valid
	if source and is_instance_valid(source) and source.has_method("take_damage"):
		# Reflection is handled by the damage system, not here
		pass

	return reduced
