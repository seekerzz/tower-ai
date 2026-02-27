extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not is_instance_valid(target): return

	var lifesteal_pct = unit.unit_data.get("lifesteal_percent", 0.0)
	var heal_amt = damage * lifesteal_pct

	if heal_amt > 0:
		GameManager.heal_core(heal_amt)
		unit.heal(heal_amt)

	if unit.level >= 3:
		if target.has_method("add_bleed_stacks") and "bleed_stacks" in target and target.bleed_stacks > 0:
			target.take_damage(damage, unit, "physical")

		if target.hp <= 0:
			_explode_on_kill(target.global_position, damage * 0.4)

func _explode_on_kill(position: Vector2, damage: float):
	var radius = 80.0
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) <= radius:
			enemy.take_damage(damage, unit, "physical")

	GameManager.spawn_floating_text(position, "BOOM!", Color.ORANGE)
