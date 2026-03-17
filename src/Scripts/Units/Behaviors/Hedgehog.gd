extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var reflect_chance: float = 0.25

func on_setup():
	reflect_chance = 0.25
	if unit.level >= 2:
		reflect_chance = 0.40

func on_post_damage_applied(context: DamageContext):
	var amount = context.final_damage
	var source = context.source

	# Reflect logic
	if randf() < reflect_chance and source and is_instance_valid(source) and source.has_method("take_damage"):
		var reflect_damage = amount
		# Reflect physical damage
		source.take_damage(reflect_damage, unit, "physical")
		unit.spawn_buff_effect("💢")

		print("[Hedgehog Debug] Reflected %.1f damage to %s" % [reflect_damage, source.name])

		if unit.level >= 3:
			_launch_spikes()

# DEPRECATED
func on_damage_taken(amount: float, _source: Node) -> float:
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
