extends Node

# ===== 信号 =====
signal unit_moved(from_zone: String, from_pos: Variant,
                  to_zone: String, to_pos: Variant, unit_data: Dictionary)
signal unit_sold(zone: String, pos: Variant, gold_refund: int)
signal unit_purchased(unit_key: String, target_zone: String, target_pos: Variant)
signal shop_refreshed(shop_units: Array)
signal operation_failed(operation: String, reason: String)

# ===== 常量 =====
const ZONE_BENCH = "bench"
const ZONE_GRID = "grid"
const ZONE_SHOP = "shop"

# ===== 依赖 =====
var session_data = null  # SessionData instance
var grid_manager = null

func _ready():
	# 尝试获取 GridManager 引用
	if GameManager.grid_manager:
		grid_manager = GameManager.grid_manager

	# 等待 GameManager 初始化完成
	if GameManager.session_data:
		initialize(GameManager.session_data)
	else:
		# 延迟初始化
		await get_tree().process_frame
		if GameManager.session_data:
			initialize(GameManager.session_data)

func initialize(p_session_data):
	"""初始化 BoardController，传入 SessionData 实例"""
	session_data = p_session_data

# ===== 商店操作 =====

func buy_unit(shop_index: int) -> bool:
	"""
	购买商店中的单位
	@param shop_index: 商店槽位索引 (0-3)
	@return: 是否购买成功
	"""
	if session_data == null:
		operation_failed.emit("buy_unit", "SessionData not initialized")
		return false

	if session_data.is_wave_active:
		operation_failed.emit("buy_unit", "Cannot buy during wave")
		return false

	var unit_key = session_data.get_shop_unit(shop_index)
	if unit_key == null:
		operation_failed.emit("buy_unit", "Shop slot empty")
		return false

	var proto = Constants.UNIT_TYPES.get(unit_key)
	if proto == null:
		operation_failed.emit("buy_unit", "Invalid unit type")
		return false

	var cost = proto.get("cost", 0)

	# 特殊处理：meat 物品
	if unit_key == "meat":
		if GameManager.inventory_manager and not GameManager.inventory_manager.is_full():
			if session_data.spend_gold(cost):
				GameManager.inventory_manager.add_item({"item_id": "meat", "count": 1})
				session_data.set_shop_unit(shop_index, null)
				unit_purchased.emit(unit_key, "inventory", 0)
				return true
		else:
			operation_failed.emit("buy_unit", "Inventory full")
			return false

	# 标准单位：尝试添加到备战区
	var target_bench_index = _find_empty_bench_slot()
	if target_bench_index == -1:
		operation_failed.emit("buy_unit", "Bench full")
		return false

	if not session_data.spend_gold(cost):
		operation_failed.emit("buy_unit", "Not enough gold")
		return false

	# 创建单位数据
	var unit_data = {
		"key": unit_key,
		"level": 1,
		"grid_pos": null
	}

	session_data.set_bench_unit(target_bench_index, unit_data)
	session_data.set_shop_unit(shop_index, null)
	unit_purchased.emit(unit_key, ZONE_BENCH, target_bench_index)

	return true

func refresh_shop() -> bool:
	"""
	刷新商店
	@return: 是否刷新成功
	"""
	if session_data == null:
		operation_failed.emit("refresh_shop", "SessionData not initialized")
		return false

	if session_data.is_wave_active:
		operation_failed.emit("refresh_shop", "Cannot refresh during wave")
		return false

	var cost = session_data.shop_refresh_cost
	if not session_data.spend_gold(cost):
		operation_failed.emit("refresh_shop", "Not enough gold")
		return false

	# 获取可用单位池
	var player_faction = GameManager.core_type if GameManager.core_type else ""
	var available_units = _get_units_for_faction(player_faction)

	var new_shop = [null, null, null, null]
	for i in range(4):
		if session_data.is_shop_slot_locked(i):
			new_shop[i] = session_data.get_shop_unit(i)
		else:
			new_shop[i] = available_units.pick_random()

	# 更新商店状态
	for i in range(4):
		session_data.set_shop_unit(i, new_shop[i])

	shop_refreshed.emit(new_shop)
	return true

func _get_units_for_faction(faction: String) -> Array:
	var result = []
	for unit_key in Constants.UNIT_TYPES.keys():
		var unit_data = Constants.UNIT_TYPES[unit_key]
		var unit_faction = unit_data.get("faction", "universal")
		if unit_faction == faction or unit_faction == "universal":
			result.append(unit_key)
	if result.is_empty():
		return Constants.UNIT_TYPES.keys()
	return result

func _find_empty_bench_slot() -> int:
	for i in range(Constants.BENCH_SIZE):
		if session_data.get_bench_unit(i) == null:
			return i
	return -1

# ===== 单位移动 =====

func try_move_unit(from_zone: String, from_pos: Variant,
                   to_zone: String, to_pos: Variant) -> bool:
	"""
	尝试移动单位
	@param from_zone: 来源区域 ("bench", "grid")
	@param from_pos: 来源位置 (bench索引 或 Vector2i)
	@param to_zone: 目标区域 ("bench", "grid")
	@param to_pos: 目标位置 (bench索引 或 Vector2i)
	@return: 是否移动成功
	"""
	if session_data == null:
		operation_failed.emit("try_move_unit", "SessionData not initialized")
		return false

	if session_data.is_wave_active:
		operation_failed.emit("try_move_unit", "Cannot move during wave")
		return false

	# 获取来源单位
	var unit_data = _get_unit_at(from_zone, from_pos)
	if unit_data == null:
		operation_failed.emit("try_move_unit", "No unit at source position")
		return false

	# 检查目标位置
	var target_unit = _get_unit_at(to_zone, to_pos)

	# 如果目标有单位，尝试合并或交换
	if target_unit != null:
		# 检查是否可以合并
		if _can_merge(unit_data, target_unit):
			_perform_merge(from_zone, from_pos, to_zone, to_pos, unit_data, target_unit)
			return true

		# 检查是否可以交换
		if from_zone == ZONE_BENCH and to_zone == ZONE_BENCH:
			_perform_swap(from_zone, from_pos, to_zone, to_pos, unit_data, target_unit)
			return true

		operation_failed.emit("try_move_unit", "Target occupied and cannot merge")
		return false

	# 目标为空，执行移动
	if to_zone == ZONE_GRID:
		# 检查网格放置是否有效
		if not _can_place_on_grid(to_pos):
			operation_failed.emit("try_move_unit", "Cannot place at grid position")
			return false

		# 实际放置单位到网格
		if grid_manager:
			var grid_pos = to_pos as Vector2i
			var unit_key = unit_data.get("key", "")
			if grid_manager.place_unit(unit_key, grid_pos.x, grid_pos.y):
				_remove_unit_from_zone(from_zone, from_pos)
				unit_data["grid_pos"] = grid_pos
				session_data.set_grid_unit(grid_pos, unit_data)
				unit_moved.emit(from_zone, from_pos, to_zone, to_pos, unit_data)
				return true
			else:
				operation_failed.emit("try_move_unit", "Grid placement failed")
				return false
		else:
			operation_failed.emit("try_move_unit", "GridManager not available")
			return false

	elif to_zone == ZONE_BENCH:
		# 移动到备战区
		var bench_index = to_pos as int
		_remove_unit_from_zone(from_zone, from_pos)
		unit_data["grid_pos"] = null
		session_data.set_bench_unit(bench_index, unit_data)

		# 如果是从网格移动，需要从网格移除
		if from_zone == ZONE_GRID:
			_remove_from_grid(from_pos)

		unit_moved.emit(from_zone, from_pos, to_zone, to_pos, unit_data)
		return true

	return false

func _get_unit_at(zone: String, pos: Variant):
	match zone:
		ZONE_BENCH:
			return session_data.get_bench_unit(pos as int)
		ZONE_GRID:
			return session_data.get_grid_unit(pos as Vector2i)
	return null

func _remove_unit_from_zone(zone: String, pos: Variant):
	match zone:
		ZONE_BENCH:
			session_data.set_bench_unit(pos as int, null)
		ZONE_GRID:
			session_data.set_grid_unit(pos as Vector2i, null)

func _remove_from_grid(grid_pos: Vector2i):
	if grid_manager:
		var key = "%d,%d" % [grid_pos.x, grid_pos.y]
		if grid_manager.tiles.has(key):
			var tile = grid_manager.tiles[key]
			if tile.unit:
				grid_manager.remove_unit_from_grid(tile.unit)

func _can_place_on_grid(grid_pos: Vector2i) -> bool:
	if grid_manager == null:
		return false
	var key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if not grid_manager.tiles.has(key):
		return false
	var tile = grid_manager.tiles[key]
	if tile.state != "unlocked":
		return false
	if tile.type == "core":
		return false
	if tile.unit != null:
		return false
	return true

func _can_merge(unit_a: Dictionary, unit_b: Dictionary) -> bool:
	return unit_a["key"] == unit_b["key"] and unit_a["level"] == unit_b["level"]

func _perform_merge(from_zone: String, from_pos: Variant,
                    to_zone: String, to_pos: Variant,
                    source_unit: Dictionary, target_unit: Dictionary):
	# 移除来源单位
	_remove_unit_from_zone(from_zone, from_pos)
	if from_zone == ZONE_GRID:
		_remove_from_grid(from_pos)

	# 升级目标单位
	target_unit["level"] += 1
	if to_zone == ZONE_GRID:
		session_data.set_grid_unit(to_pos as Vector2i, target_unit)
		# 更新网格中的单位节点
		_update_unit_level_on_grid(to_pos as Vector2i, target_unit["level"])
	else:
		session_data.set_bench_unit(to_pos as int, target_unit)

	unit_moved.emit(from_zone, from_pos, to_zone, to_pos, target_unit)

func _update_unit_level_on_grid(grid_pos: Vector2i, new_level: int):
	if grid_manager:
		var key = "%d,%d" % [grid_pos.x, grid_pos.y]
		if grid_manager.tiles.has(key):
			var tile = grid_manager.tiles[key]
			if tile.unit and tile.unit.has_method("set_level"):
				tile.unit.set_level(new_level)

func _perform_swap(zone_a: String, pos_a: Variant,
                   zone_b: String, pos_b: Variant,
                   unit_a: Dictionary, unit_b: Dictionary):
	session_data.set_bench_unit(pos_a as int, unit_b)
	session_data.set_bench_unit(pos_b as int, unit_a)
	unit_moved.emit(zone_a, pos_a, zone_b, pos_b, unit_b)
	unit_moved.emit(zone_b, pos_b, zone_a, pos_a, unit_a)

# ===== 出售单位 =====

func sell_unit(zone: String, pos: Variant) -> bool:
	"""
	出售单位
	@param zone: 区域 ("bench", "grid")
	@param pos: 位置 (bench索引 或 Vector2i)
	@return: 是否出售成功
	"""
	if session_data == null:
		operation_failed.emit("sell_unit", "SessionData not initialized")
		return false

	if session_data.is_wave_active:
		operation_failed.emit("sell_unit", "Cannot sell during wave")
		return false

	var unit_data = _get_unit_at(zone, pos)
	if unit_data == null or not unit_data is Dictionary:
		operation_failed.emit("sell_unit", "No unit at position")
		return false

	var unit_key = unit_data.get("key", "")
	var proto = Constants.UNIT_TYPES.get(unit_key)
	if proto == null:
		operation_failed.emit("sell_unit", "Invalid unit type")
		return false

	var base_cost = proto.get("cost", 0)
	var level = unit_data.get("level", 1)

	# 计算退款：基础价格 * 等级 * 50%
	var refund = int(base_cost * level * 0.5)

	# 移除单位
	_remove_unit_from_zone(zone, pos)
	if zone == ZONE_GRID:
		_remove_from_grid(pos)

	# 添加金币
	session_data.add_gold(refund)

	unit_sold.emit(zone, pos, refund)
	return true

# ===== 波次控制 =====

func start_wave() -> bool:
	"""
	开始波次
	@return: 是否成功开始
	"""
	if session_data == null:
		operation_failed.emit("start_wave", "SessionData not initialized")
		return false

	if session_data.is_wave_active:
		operation_failed.emit("start_wave", "Wave already active")
		return false

	session_data.is_wave_active = true

	# 委托给 GameManager 的波次系统
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.start_wave(session_data.wave)

	return true

func retry_wave():
	"""
	重试当前波次
	"""
	if session_data == null:
		return

	# 完全恢复核心血量
	session_data.core_health = session_data.max_core_health

	# 清除敌人
	if Engine.get_main_loop() and Engine.get_main_loop().get_root():
		Engine.get_main_loop().get_root().call_group("enemies", "queue_free")

	# 重置波次状态
	session_data.is_wave_active = false

	# 重置波次系统
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.reset()
		GameManager.wave_system_manager.current_wave = session_data.wave

	# 发射信号通知 UI
	GameManager.wave_reset.emit()
