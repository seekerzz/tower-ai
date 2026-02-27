extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name Phoenix

func on_skill_activated():
	if GameManager.grid_manager:
		GameManager.grid_manager.enter_skill_targeting(unit)

func on_skill_executed_at(grid_pos: Vector2i):
	var world_pos = Vector2.ZERO
	if GameManager.grid_manager:
		world_pos = GameManager.grid_manager.get_world_pos_from_grid(grid_pos)

	_cast_fire_rain(world_pos)

func _cast_fire_rain(center_pos: Vector2):
	var hit_enemies = 0
	var rain_duration = 3.0
	var damage_per_tick = unit.damage * 0.3
	var skill_range = unit.unit_data.get("skillRadius", 150.0)

	var timer = Timer.new()
	timer.wait_time = 0.5
	var ticks = 0
	var max_ticks = int(rain_duration / 0.5)

	timer.timeout.connect(func():
		ticks += 1
		var enemies = unit.get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if e.global_position.distance_to(center_pos) <= skill_range:
				e.take_damage(damage_per_tick, unit, "fire")
				hit_enemies += 1

		if unit.level >= 3:
			_restore_ally_mana(center_pos, skill_range)

		# Visual effect for tick
		GameManager.combat_manager.start_meteor_shower(center_pos, damage_per_tick)

		if ticks >= max_ticks:
			timer.stop()
			timer.queue_free()
			if unit.level >= 3:
				_on_fire_rain_end(hit_enemies)
	)

	unit.add_child(timer)
	timer.start()

func _restore_ally_mana(center: Vector2, radius: float):
	var allies = unit.get_tree().get_nodes_in_group("units")
	for ally in allies:
		if ally != unit and ally.global_position.distance_to(center) <= radius:
			GameManager.add_resource("mana", 5)
			GameManager.spawn_floating_text(ally.global_position, "+5", Color.BLUE)

func _on_fire_rain_end(total_hits: int):
	var bonus_orbs = min(floor(total_hits / 5), 2)
	# Logic to spawn temp orbs or resource
	if bonus_orbs > 0:
		GameManager.add_resource("mana", bonus_orbs * 20)
		GameManager.spawn_floating_text(unit.global_position, "+%d Mana Orbs" % (bonus_orbs * 20), Color.GOLD)
