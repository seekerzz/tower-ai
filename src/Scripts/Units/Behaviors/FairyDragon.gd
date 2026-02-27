extends "res://src/Scripts/Units/UnitBehavior.gd"

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target or not is_instance_valid(target):
		return

	var resistance = 1.0
	if "knockback_resistance" in target:
		resistance = target.knockback_resistance

	var base_chance = 0.0
	# Access unit_data safely to get mechanics for current level
	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		var stats = unit.unit_data["levels"][str(unit.level)]
		if stats.has("mechanics") and stats["mechanics"].has("teleport_base_chance"):
			base_chance = stats["mechanics"]["teleport_base_chance"]

	if base_chance <= 0.0:
		return

	var final_chance = base_chance / max(1.0, resistance)

	if randf() < final_chance:
		var direction = (target.global_position - unit.global_position).normalized()
		# Random distance between 2 and 3 tiles
		var distance = randf_range(2.0, 3.0) * Constants.TILE_SIZE

		# New position along the line from unit to target (extension)
		var target_pos = unit.global_position + (direction * distance)

		target.global_position = target_pos

		GameManager.spawn_floating_text(target.global_position, "Warp!", Color.VIOLET)
