class_name BaseTotemMechanic
extends CoreMechanic

func get_nearest_enemies(count: int) -> Array:
    var enemies = get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return []

    # Sort by distance to core (GameManager.grid_manager.global_position usually or Vector2.ZERO if core is at 0,0)
    var core_pos = Vector2.ZERO
    if GameManager.grid_manager and is_instance_valid(GameManager.grid_manager):
         # Assuming core is at grid (0,0) which is local position.
         # Convert grid (0,0) to global.
         core_pos = GameManager.grid_manager.to_global(GameManager.grid_manager.grid_to_local(Vector2i(0,0)))

    enemies.sort_custom(func(a, b):
        return a.global_position.distance_squared_to(core_pos) < b.global_position.distance_squared_to(core_pos)
    )

    return enemies.slice(0, count)

func deal_damage(enemy, amount: float):
    if is_instance_valid(enemy):
        # Using GameManager as source since it's a global effect/totem effect managed by game
        enemy.take_damage(amount, GameManager, "physical")
