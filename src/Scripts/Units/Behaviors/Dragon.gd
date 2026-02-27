extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name Dragon

var black_hole_enemies = []

func on_skill_activated():
	if GameManager.grid_manager:
		GameManager.grid_manager.enter_skill_targeting(unit)

func on_skill_executed_at(grid_pos: Vector2i):
	var world_pos = Vector2.ZERO
	if GameManager.grid_manager:
		world_pos = GameManager.grid_manager.get_world_pos_from_grid(grid_pos)

	_create_black_hole(world_pos)

func _create_black_hole(pos: Vector2):
	var duration = 4.0 if unit.level < 2 else 6.0
	var radius = 100.0 if unit.level < 3 else 120.0

	var extra_stats = {
		"duration": duration,
		"skillRadius": radius,
		"skillStrength": unit.unit_data.get("skillStrength", 3000.0),
		"skillColor": unit.unit_data.get("skillColor", "#330066"),
		"damage": 0,
		"hide_visuals": false,
		"type": "black_hole_field"
	}

	var projectile = null
	if GameManager.combat_manager:
		projectile = GameManager.combat_manager.spawn_projectile(unit, pos, null, extra_stats)

	if unit.level >= 3:
		GameManager.apply_global_buff("skill_mana_cost_reduction", 0.30)
		GameManager.spawn_floating_text(unit.global_position, "Mana Cost -30%", Color.BLUE)

		var buff_timer = unit.get_tree().create_timer(duration)
		buff_timer.timeout.connect(func():
			GameManager.remove_global_buff("skill_mana_cost_reduction")
			_cast_meteor_fall(pos, black_hole_enemies.size())
		)

	# Track enemies
	# Since projectile handles pulling, we can just rely on size at end or track here.
	# But we don't have easy access to projectile's internal enemy list.
	# We can assume meteor fall depends on duration end.
	# For enemy count, we might need a way to query projectile.

	# Simpler: Meteor fall just happens at location. Number of meteors depends on enemies caught?
	# The task says: `_cast_meteor_fall(black_hole.global_position, black_hole_enemies.size())`
	# We can't easily get `black_hole_enemies` without modifying Projectile to expose it.
	# So I will make `black_hole_enemies` tracking approximate by checking enemies in range at end.

func _cast_meteor_fall(center: Vector2, count_factor: int):
	# Recalculate count based on enemies currently near center
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var caught_count = 0
	for e in enemies:
		if e.global_position.distance_to(center) < 150.0:
			caught_count += 1

	var meteor_count = max(3, caught_count)

	for i in range(meteor_count):
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var target_pos = center + offset
		var start_pos = target_pos + Vector2(0, -800)

		var stats = {
			"is_meteor": true,
			"ground_pos": target_pos,
			"damage": unit.damage * 2.0
		}

		if GameManager.combat_manager:
			GameManager.combat_manager.spawn_projectile(unit, start_pos, null, stats)

		await unit.get_tree().create_timer(0.2).timeout
