class_name BaseTotemMechanic
extends CoreMechanic

func get_nearest_enemies(count: int) -> Array:
    var enemies = get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return []

    # 过滤掉无效节点和尚未初始化完成的节点
    var valid_enemies = []
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.is_node_ready():
            valid_enemies.append(enemy)

    if valid_enemies.is_empty():
        return []

    # Sort by distance to core (GameManager.grid_manager.global_position usually or Vector2.ZERO if core is at 0,0)
    var core_pos = Vector2.ZERO
    if GameManager.grid_manager and is_instance_valid(GameManager.grid_manager):
         # Assuming core is at grid (0,0) which is local position.
         # Convert grid (0,0) to global.
         core_pos = GameManager.grid_manager.to_global(GameManager.grid_manager.grid_to_local(Vector2i(0,0)))

    valid_enemies.sort_custom(func(a, b):
        if not is_instance_valid(a) or not is_instance_valid(b):
            return false
        return a.global_position.distance_squared_to(core_pos) < b.global_position.distance_squared_to(core_pos)
    )

    return valid_enemies.slice(0, count)

func deal_damage(enemy, amount: float):
    # 检查敌人是否有效且已完成初始化（避免攻击半成品敌人导致崩溃）
    if is_instance_valid(enemy) and enemy.is_node_ready():
        # Using GameManager as source since it's a global effect/totem effect managed by game
        enemy.take_damage(amount, GameManager, "physical")
