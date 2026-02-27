extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var active_pools: Array = []

func on_skill_activated():
	if GameManager.grid_manager:
		GameManager.grid_manager.enter_skill_targeting(unit)

func on_skill_executed_at(grid_pos: Vector2i):
	if not GameManager.grid_manager:
		return

	var world_pos = GameManager.grid_manager.get_world_pos_from_grid(grid_pos)
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var pool_size = mechanics.get("pool_size", 1)
	var heal_efficiency = mechanics.get("heal_efficiency", 1.0)

	_create_blood_pool(world_pos, pool_size, heal_efficiency)

func _create_blood_pool(center_pos: Vector2, size: int, efficiency: float):
	var pool_duration = 8.0
	var tile_size = Constants.TILE_SIZE
	var pool_radius = (size * tile_size) / 2.0

	var pool_node = Node2D.new()
	pool_node.name = "BloodPool"
	pool_node.global_position = center_pos

	var visual = ColorRect.new()
	visual.color = Color(0.6, 0.0, 0.0, 0.4)
	visual.size = Vector2(pool_radius * 2, pool_radius * 2)
	visual.position = -visual.size / 2

	pool_node.add_child(visual)
	if GameManager.combat_manager:
		GameManager.combat_manager.add_child(pool_node)

		var pool_data = {
			"node": pool_node,
			"center": center_pos,
			"radius": pool_radius,
			"efficiency": efficiency,
			"timer": pool_duration
		}
		active_pools.append(pool_data)
		GameManager.spawn_floating_text(center_pos, "Blood Pool!", Color.RED)
		_start_pool_processing(pool_data)

func _start_pool_processing(pool_data: Dictionary):
	var timer = pool_data.timer
	var node = pool_data.node

	while timer > 0 and is_instance_valid(unit) and is_instance_valid(node):
		await unit.get_tree().create_timer(1.0).timeout
		timer -= 1.0

		if not is_instance_valid(unit) or not is_instance_valid(node):
			break

		var enemies = unit.get_tree().get_nodes_in_group("enemies")
		var total_damage_dealt = 0.0

		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue

			var dist = pool_data.center.distance_to(enemy.global_position)
			if dist <= pool_data.radius:
				var damage = unit.damage * 0.5 * pool_data.efficiency # Buffed from 0.3 to 0.5 due to 1s interval
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, unit, "magic")
					total_damage_dealt += damage

				if unit.level >= 3:
					if enemy.has_method("add_bleed_stacks"):
						enemy.add_bleed_stacks(1, unit)

		if total_damage_dealt > 0:
			var heal_amount = total_damage_dealt * 0.5 * pool_data.efficiency
			GameManager.heal_core(heal_amount)
			GameManager.spawn_floating_text(pool_data.center, "+%d HP" % int(heal_amount), Color.GREEN)

	if is_instance_valid(node):
		node.queue_free()

	if pool_data in active_pools:
		active_pools.erase(pool_data)

func on_cleanup():
	# Create a copy of the array to avoid modification during iteration
	var pools_to_cleanup = active_pools.duplicate()
	active_pools.clear()

	for pool_data in pools_to_cleanup:
		var node = pool_data.get("node")
		if is_instance_valid(node):
			node.queue_free()
