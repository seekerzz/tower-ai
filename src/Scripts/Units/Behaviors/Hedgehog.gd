extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var reflect_percent: float = 0.3

func on_setup():
	reflect_percent = unit.unit_data.get("reflect_percent", 0.3)

func on_damage_taken(amount: float, source: Node) -> float:
	if source and is_instance_valid(source) and source.has_method("take_damage"):
		var reflect_damage = amount * reflect_percent
		# Reflect physical damage
		source.take_damage(reflect_damage, unit, "physical")
		unit.spawn_buff_effect("💢")

		if unit.level >= 3:
			_launch_spikes()

	return amount

func _launch_spikes():
	for i in range(3):
		var angle = i * (TAU / 3)

		# Using standard projectile logic (no gravity simulation in current Projectile.gd)
		var stats = {
			"damage": 20.0, # Base spike damage
			"proj_override": "stinger", # Using stinger visual as spike
			"speed": 300.0,
			"angle": angle,
			"pierce": 1,
			"damageType": "physical"
		}
		GameManager.combat_manager.spawn_projectile(unit, unit.global_position, null, stats)
