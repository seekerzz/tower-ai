extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# LureSnake - 诱捕蛇
# 机制: 陷阱诱导 - 敌人触发陷阱后，被牵引向最近的另一个陷阱
# L1: 基础牵引速度 (100)
# L2: 牵引速度+50% (150)
# L3: 牵引后晕眩1秒

var _connected_traps: Array = []
var _processed_enemies: Dictionary = {}  # enemy_instance_id -> cooldown_timer

func on_setup():
	# 连接所有现有陷阱的信号
	_connect_to_all_traps()

func on_cleanup():
	# 断开所有信号连接
	_disconnect_from_all_traps()

func on_tick(delta: float):
	# 清理过期的敌人处理记录
	var to_remove = []
	for enemy_id in _processed_enemies:
		_processed_enemies[enemy_id] -= delta
		if _processed_enemies[enemy_id] <= 0:
			to_remove.append(enemy_id)
	for enemy_id in to_remove:
		_processed_enemies.erase(enemy_id)

	# 检查新放置的陷阱并连接
	_connect_to_all_traps()

func _connect_to_all_traps():
	if not GameManager.grid_manager:
		return

	var obstacles = GameManager.grid_manager.obstacles
	for grid_pos in obstacles:
		var trap = obstacles[grid_pos]
		if not is_instance_valid(trap):
			continue
		if not trap.has("type"):
			continue
		if not Constants.BARRICADE_TYPES.has(trap.type):
			continue
		if trap in _connected_traps:
			continue

		# 连接信号
		if trap.has_signal("trap_triggered"):
			if not trap.trap_triggered.is_connected(_on_trap_triggered):
				trap.trap_triggered.connect(_on_trap_triggered)
			_connected_traps.append(trap)

func _disconnect_from_all_traps():
	for trap in _connected_traps:
		if is_instance_valid(trap) and trap.has_signal("trap_triggered"):
			if trap.trap_triggered.is_connected(_on_trap_triggered):
				trap.trap_triggered.disconnect(_on_trap_triggered)
	_connected_traps.clear()

func _on_trap_triggered(enemy: Node2D, trap_pos: Vector2):
	if not is_instance_valid(enemy):
		return
	if not is_instance_valid(unit):
		return

	# 检查冷却时间，避免同一敌人被频繁处理
	var enemy_id = enemy.get_instance_id()
	if _processed_enemies.has(enemy_id):
		return

	# 获取当前等级的机制数据
	var mechanics = _get_mechanics()
	if mechanics.is_empty():
		return

	# 寻找最近的另一个陷阱
	var nearest_trap = _find_nearest_other_trap(trap_pos)
	if not nearest_trap:
		return

	# 计算牵引速度
	var base_speed = 100.0
	var speed_multiplier = mechanics.get("pull_speed_multiplier", 1.0)
	var pull_speed = base_speed * speed_multiplier
	var stun_duration = mechanics.get("stun_duration", 0.0)

	# 应用牵引效果
	var direction = (nearest_trap.global_position - enemy.global_position).normalized()

	# 如果敌人有knockback_velocity属性，应用牵引
	if "knockback_velocity" in enemy:
		enemy.knockback_velocity += direction * pull_speed

	# 显示牵引效果
	GameManager.spawn_floating_text(enemy.global_position, "Pulled!", Color.YELLOW)

	# L3: 牵引后晕眩
	if stun_duration > 0 and enemy.has_method("apply_stun"):
		enemy.apply_stun(stun_duration)

	# 设置冷却时间，避免同一敌人被频繁牵引
	_processed_enemies[enemy_id] = 0.5  # 0.5秒冷却

func _find_nearest_other_trap(exclude_pos: Vector2) -> Node2D:
	var nearest_trap = null
	var min_dist = 999999.0

	if not GameManager.grid_manager:
		return null

	# 获取所有障碍物（陷阱）
	var obstacles = GameManager.grid_manager.obstacles
	for grid_pos in obstacles:
		var trap = obstacles[grid_pos]
		if not is_instance_valid(trap):
			continue
		if not trap.has("type"):
			continue
		# 只考虑BARRICADE_TYPES中的陷阱
		if not Constants.BARRICADE_TYPES.has(trap.type):
			continue

		var dist = trap.global_position.distance_squared_to(exclude_pos)
		if dist > 100.0 and dist < min_dist:  # dist > 100.0 确保不是同一个陷阱 (约1.6格)
			min_dist = dist
			nearest_trap = trap

	return nearest_trap

func _get_mechanics() -> Dictionary:
	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		var stats = unit.unit_data["levels"][str(unit.level)]
		return stats.get("mechanics", {})
	return {}
