extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Toad - 蟾蜍
# 机制: 毒陷阱 - 主动技能放置毒陷阱
# L1: 1个陷阱，25s持续
# L2: 2个陷阱
# L3: 陷阱附加距离伤害Debuff

var max_traps: int = 1
var trap_duration: float = 25.0
var placed_traps: Array = []

func on_setup():
	if unit.level >= 2:
		max_traps = 2

func on_skill_executed_at(grid_pos: Vector2i):
	var world_pos = Vector2.ZERO
	if GameManager.grid_manager:
		var key = GameManager.grid_manager.get_tile_key(grid_pos.x, grid_pos.y)
		if GameManager.grid_manager.tiles.has(key):
			world_pos = GameManager.grid_manager.tiles[key].global_position
		else:
			world_pos = Vector2(grid_pos.x * 60, grid_pos.y * 60)
	else:
		world_pos = Vector2(grid_pos.x * 60, grid_pos.y * 60)

	_spawn_trap(world_pos)

func on_skill_activated():
	# If called without target (e.g. auto skill), pick a random position in range
	var r = unit.range_val
	var offset = Vector2(randf_range(-r, r), randf_range(-r, r))
	_spawn_trap(unit.global_position + offset)

func _spawn_trap(pos: Vector2):
	if placed_traps.size() >= max_traps:
		var old_trap = placed_traps.pop_front()
		if is_instance_valid(old_trap):
			old_trap.queue_free()

	var trap_scene = load("res://src/Scenes/Units/ToadTrap.tscn")
	if not trap_scene:
		return

	var trap = trap_scene.instantiate()
	trap.global_position = pos
	trap.duration = trap_duration
	trap.owner_toad = unit
	trap.level = unit.level

	# Add to scene
	unit.get_tree().current_scene.add_child(trap)
	placed_traps.append(trap)
	trap.trap_triggered.connect(_on_trap_triggered)

	# Emit signal for test logging
	GameManager.trap_placed.emit("poison", pos, unit)

	# 添加详细日志：记录陷阱位置、拥有者信息
	print("[Toad] 毒陷阱已放置 - 位置: %s, 拥有者等级: L%d, 最大陷阱数: %d, 当前陷阱数: %d" % [
		str(pos),
		unit.level,
		max_traps,
		placed_traps.size()
	])

func _on_trap_triggered(enemy, trap):
	# Remove from list if it's there (trap queues free itself)
	placed_traps.erase(trap)

	# Emit signal for test logging
	GameManager.trap_triggered.emit("poison", enemy, unit)

	# 添加详细日志：记录陷阱触发信息、中毒目标、中毒层数
	var enemy_name = enemy.name if enemy.has_method("get") and enemy.get("name") else enemy.name
	var enemy_type = enemy.type_key if enemy.has_method("get") and enemy.get("type_key") else "unknown"
	print("[Toad] 毒陷阱触发! 陷阱位置: %s, 中毒目标: %s (类型:%s), 中毒层数: 2" % [
		str(trap.global_position) if trap else "unknown",
		enemy_name,
		enemy_type
	])

	if enemy.has_method("add_poison_stacks"):
		enemy.add_poison_stacks(2)
		print("[Toad] 成功对 %s 添加 2 层中毒效果" % enemy_type)

	if unit.level >= 3:
		_apply_distance_damage_debuff(enemy)

func _apply_distance_damage_debuff(enemy):
	var debuff_script = load("res://src/Scripts/Effects/DistanceDamageDebuff.gd")
	if debuff_script:
		enemy.apply_status(debuff_script, {
			"duration": 2.5,
			"tick_interval": 0.5
		})
