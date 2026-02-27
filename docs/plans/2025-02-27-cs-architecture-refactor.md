# C/S 架构重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Godot 塔防项目重构为 C/S 架构，抽离纯逻辑数据层 API，为 AI Agent 接入做准备。

**Architecture:** 采用纯数据层分离方案，创建 SessionData 存储战局状态，BoardController 提供纯逻辑 API，UI 层只监听信号更新显示。

**Tech Stack:** Godot 4.5, GDScript

---

## Task 1: 创建 SessionData 类

**Files:**
- Create: `src/Scripts/Data/SessionData.gd`

**Step 1: 创建 SessionData 脚本**

创建 `src/Scripts/Data/SessionData.gd`：

```gdscript
class_name SessionData
extends Resource

# ===== 信号 =====
signal gold_changed(new_amount: int)
signal mana_changed(current: float, maximum: float)
signal core_health_changed(current: float, maximum: float)
signal wave_changed(wave: int)
signal wave_state_changed(is_active: bool)
signal bench_updated(bench_units: Dictionary)
signal grid_updated(grid_units: Dictionary)
signal shop_updated(shop_units: Array)

# ===== 资源系统 =====
var gold: int = 150:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)

var mana: float = 500.0:
	set(value):
		mana = clamp(value, 0, max_mana)
		mana_changed.emit(mana, max_mana)

var max_mana: float = 1000.0:
	set(value):
		max_mana = value
		mana_changed.emit(mana, max_mana)

var base_mana_rate: float = 10.0

# ===== 核心血量系统 =====
var core_health: float = 500.0:
	set(value):
		core_health = clamp(value, 0, max_core_health)
		core_health_changed.emit(core_health, max_core_health)

var max_core_health: float = 500.0:
	set(value):
		var diff = value - max_core_health
		max_core_health = value
		core_health += diff
		core_health_changed.emit(core_health, max_core_health)

var permanent_health_bonus: float = 0.0

# ===== 波次状态 =====
var wave: int = 1:
	set(value):
		wave = value
		wave_changed.emit(wave)

var is_wave_active: bool = false:
	set(value):
		is_wave_active = value
		wave_state_changed.emit(is_wave_active)

# ===== 棋盘状态 =====
# bench_units: { bench_index (0-7): UnitData }
var bench_units: Dictionary = {}:
	set(value):
		bench_units = value
		bench_updated.emit(bench_units)

# grid_units: { "x,y": UnitData }
var grid_units: Dictionary = {}:
	set(value):
		grid_units = value
		grid_updated.emit(grid_units)

# ===== 商店状态 =====
# shop_units: Array of 4 unit keys or null
var shop_units: Array = [null, null, null, null]:
	set(value):
		shop_units = value
		shop_updated.emit(shop_units)

var shop_locked: Array = [false, false, false, false]
var shop_refresh_cost: int = 10

# ===== 遗物/物品 =====
var artifacts: Array = []

# ===== 作弊标志 =====
var cheat_god_mode: bool = false
var cheat_infinite_resources: bool = false
var cheat_fast_cooldown: bool = false

# ===== 方法 =====
func reset():
	"""重置所有状态到新游戏初始状态"""
	gold = 150
	mana = 500.0
	max_mana = 1000.0
	core_health = 500.0
	max_core_health = 500.0
	permanent_health_bonus = 0.0
	wave = 1
	is_wave_active = false
	bench_units = {}
	grid_units = {}
	shop_units = [null, null, null, null]
	shop_locked = [false, false, false, false]
	artifacts = []

func can_afford(amount: int) -> bool:
	if cheat_infinite_resources:
		return true
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if cheat_infinite_resources:
		return true
	if gold >= amount:
		gold -= amount
		return true
	return false

func add_gold(amount: int):
	gold += amount

func update_mana(delta: float):
	if mana < max_mana:
		mana = min(max_mana, mana + base_mana_rate * delta)

func damage_core(amount: float):
	if cheat_god_mode and amount > 0:
		return
	core_health -= amount

func heal_core(amount: float):
	core_health = min(max_core_health, core_health + amount)

func get_bench_unit(index: int) -> Dictionary:
	return bench_units.get(index, null)

func set_bench_unit(index: int, unit_data: Dictionary):
	if unit_data == null:
		bench_units.erase(index)
	else:
		bench_units[index] = unit_data
	bench_updated.emit(bench_units)

func get_grid_unit(grid_pos: Vector2i) -> Dictionary:
	var key = "%d,%d" % [grid_pos.x, grid_pos.y]
	return grid_units.get(key, null)

func set_grid_unit(grid_pos: Vector2i, unit_data: Dictionary):
	var key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if unit_data == null:
		grid_units.erase(key)
	else:
		grid_units[key] = unit_data
	grid_updated.emit(grid_units)

func get_shop_unit(index: int) -> String:
	if index >= 0 and index < shop_units.size():
		return shop_units[index]
	return null

func set_shop_unit(index: int, unit_key: String):
	if index >= 0 and index < shop_units.size():
		shop_units[index] = unit_key
		shop_updated.emit(shop_units)

func is_shop_slot_locked(index: int) -> bool:
	if index >= 0 and index < shop_locked.size():
		return shop_locked[index]
	return false

func set_shop_slot_locked(index: int, locked: bool):
	if index >= 0 and index < shop_locked.size():
		shop_locked[index] = locked
```

**Step 2: 创建 Data 目录**

```bash
mkdir -p /home/zhangzhan/tower/src/Scripts/Data
```

**Step 3: 验证文件创建成功**

Run: `ls -la /home/zhangzhan/tower/src/Scripts/Data/`
Expected: `SessionData.gd` exists

**Step 4: Commit**

```bash
git add src/Scripts/Data/SessionData.gd
git commit -m "feat: add SessionData class for pure game state management"
```

---

## Task 2: 创建 BoardController 类

**Files:**
- Create: `src/Scripts/Controllers/BoardController.gd`

**Step 1: 创建 Controllers 目录和 BoardController**

创建 `src/Scripts/Controllers/BoardController.gd`：

```gdscript
class_name BoardController
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
var session_data: SessionData = null
var grid_manager = null

func _ready():
	# 尝试获取 GridManager 引用
	if GameManager.grid_manager:
		grid_manager = GameManager.grid_manager

func initialize(p_session_data: SessionData):
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
			if grid_manager.place_unit(unit_data["key"], grid_pos.x, grid_pos.y):
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

func _get_unit_at(zone: String, pos: Variant) -> Dictionary:
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
	if unit_data == null:
		operation_failed.emit("sell_unit", "No unit at position")
		return false

	var proto = Constants.UNIT_TYPES.get(unit_data["key"])
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
```

**Step 2: 创建 Controllers 目录**

```bash
mkdir -p /home/zhangzhan/tower/src/Scripts/Controllers
```

**Step 3: Commit**

```bash
git add src/Scripts/Controllers/BoardController.gd
git commit -m "feat: add BoardController with pure logic API for AI integration"
```

---

## Task 3: 修改 GameManager 使用 SessionData

**Files:**
- Modify: `src/Autoload/GameManager.gd`

**Step 1: 添加 SessionData 引用**

在 GameManager.gd 的顶部添加：

```gdscript
# ===== Session Data =====
var session_data: SessionData = null
```

**Step 2: 修改 _ready 函数初始化 SessionData**

在 `_ready()` 函数末尾添加：

```gdscript
	# Initialize SessionData
	var SessionDataScript = load("res://src/Scripts/Data/SessionData.gd")
	session_data = SessionDataScript.new()
```

**Step 3: 修改资源属性使用 SessionData**

将以下属性修改为从 SessionData 获取/设置：

```gdscript
# 修改 gold 属性
var gold: int:
	get:
		return session_data.gold if session_data else 150
	set(value):
		if session_data:
			session_data.gold = value

# 修改 mana 属性
var mana: float:
	get:
		return session_data.mana if session_data else 500.0
	set(value):
		if session_data:
			session_data.mana = value

# 修改 max_mana 属性
var max_mana: float:
	get:
		return session_data.max_mana if session_data else 1000.0
	set(value):
		if session_data:
			session_data.max_mana = value

# 修改 core_health 属性
var core_health: float:
	get:
		return session_data.core_health if session_data else 500.0
	set(value):
		if session_data:
			session_data.core_health = value

# 修改 max_core_health 属性
var max_core_health: float:
	get:
		return session_data.max_core_health if session_data else 500.0
	set(value):
		if session_data:
			session_data.max_core_health = value

# 修改 wave 属性
var wave: int:
	get:
		return session_data.wave if session_data else 1
	set(value):
		if session_data:
			session_data.wave = value

# 修改 is_wave_active 属性
var is_wave_active: bool:
	get:
		return session_data.is_wave_active if session_data else false
	set(value):
		if session_data:
			session_data.is_wave_active = value
```

**Step 4: 修改方法委托给 SessionData**

```gdscript
func spend_gold(amount: int) -> bool:
	if session_data:
		return session_data.spend_gold(amount)
	return false

func add_gold(amount: int):
	if session_data:
		session_data.add_gold(amount)

func heal_core(amount: float):
	if session_data:
		session_data.heal_core(amount)

func damage_core(amount: float):
	if session_data:
		session_data.damage_core(amount)
	# 原有逻辑...
	_check_game_over()

func _check_game_over():
	if session_data and session_data.core_health <= 0:
		session_data.core_health = 0
		session_data.is_wave_active = false
		if wave_system_manager:
			wave_system_manager.force_end_wave()
		if Engine.get_main_loop() and Engine.get_main_loop().get_root():
			Engine.get_main_loop().get_root().call_group("enemies", "queue_free")
		game_over.emit()
```

**Step 5: 修改 update_resources**

```gdscript
func update_resources(delta):
	if session_data:
		session_data.update_mana(delta)
		resource_changed.emit()
```

**Step 6: 修改 retry_wave**

```gdscript
func retry_wave():
	if session_data:
		session_data.core_health = session_data.max_core_health

	# Clear enemies
	if Engine.get_main_loop() and Engine.get_main_loop().get_root():
		Engine.get_main_loop().get_root().call_group("enemies", "queue_free")

	# Reset state
	if session_data:
		session_data.is_wave_active = false

	# 重置波次系统
	if wave_system_manager:
		wave_system_manager.reset()
		wave_system_manager.current_wave = wave

	# Notify systems
	wave_reset.emit()

	# Update UI
	resource_changed.emit()
```

**Step 7: Commit**

```bash
git add src/Autoload/GameManager.gd
git commit -m "refactor: GameManager now uses SessionData for state management"
```

---

## Task 4: 创建 BoardController 单例

**Files:**
- Modify: `project.godot`

**Step 1: 添加 BoardController 到 Autoload**

在 `project.godot` 的 `[autoload]` 部分添加：

```ini
BoardController="*res://src/Scripts/Controllers/BoardController.gd"
```

**Step 2: 修改 BoardController 自动初始化**

在 `BoardController.gd` 的 `_ready` 函数中添加：

```gdscript
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
```

**Step 3: Commit**

```bash
git add project.godot src/Scripts/Controllers/BoardController.gd
git commit -m "feat: add BoardController as autoload singleton"
```

---

## Task 5: 修改 Shop.gd 使用 BoardController

**Files:**
- Modify: `src/Scripts/UI/Shop.gd`

**Step 1: 修改 buy_unit 函数**

将 `buy_unit` 函数修改为调用 BoardController：

```gdscript
func buy_unit(index, unit_key, card_ref):
	# 调用 BoardController API
	var success = BoardController.buy_unit(index)
	if success:
		card_ref.modulate = Color(0.5, 0.5, 0.5)
		card_ref.mouse_filter = MOUSE_FILTER_IGNORE
```

**Step 2: 修改 refresh_shop 函数**

将 `refresh_shop` 函数修改为调用 BoardController：

```gdscript
func refresh_shop(force: bool = false):
	if force:
		# 强制刷新不走 BoardController（免费刷新）
		_perform_refresh()
	else:
		# 调用 BoardController API
		BoardController.refresh_shop()

func _perform_refresh():
	# 获取可用单位池
	var player_faction = GameManager.core_type
	var available_units = _get_units_for_faction(player_faction)

	var new_items = []
	for i in range(SHOP_SIZE):
		if shop_items.size() > i and shop_locked[i]:
			new_items.append(shop_items[i])
		else:
			new_items.append(available_units.pick_random())

	shop_items = new_items
	_update_shop_ui()

func _update_shop_ui():
	for child in shop_container.get_children():
		child.queue_free()

	for i in range(SHOP_SIZE):
		create_shop_card(i, shop_items[i])
```

**Step 3: 连接 BoardController 信号**

在 `_ready` 函数中添加：

```gdscript
	# 连接 BoardController 信号
	BoardController.shop_refreshed.connect(_on_shop_refreshed)
	BoardController.unit_purchased.connect(_on_unit_purchased)

func _on_shop_refreshed(new_shop_units: Array):
	shop_items = new_shop_units
	_update_shop_ui()

func _on_unit_purchased(unit_key: String, target_zone: String, target_pos: Variant):
	# 更新商店 UI 显示已购买
	for i in range(shop_items.size()):
		if shop_items[i] == unit_key:
			# 找到对应的 card 并更新显示
			pass
```

**Step 4: Commit**

```bash
git add src/Scripts/UI/Shop.gd
git commit -m "refactor: Shop.gd now uses BoardController API"
```

---

## Task 6: 修改 MainGame.gd 使用 BoardController

**Files:**
- Modify: `src/Scripts/MainGame.gd`

**Step 1: 修改 add_to_bench 函数**

```gdscript
func add_to_bench(unit_key: String) -> bool:
	"""添加单位到备战区 - 现在通过 BoardController 操作 SessionData"""
	if GameManager.session_data:
		for i in range(Constants.BENCH_SIZE):
			if GameManager.session_data.get_bench_unit(i) == null:
				var unit_data = {"key": unit_key, "level": 1}
				GameManager.session_data.set_bench_unit(i, unit_data)
				update_bench_ui()
				return true
	return false
```

**Step 2: 修改 remove_from_bench 函数**

```gdscript
func remove_from_bench(index: int):
	if GameManager.session_data:
		GameManager.session_data.set_bench_unit(index, null)
		update_bench_ui()
```

**Step 3: 连接 BoardController 信号更新 UI**

在 `_ready` 函数中添加：

```gdscript
	# 连接 BoardController 信号
	BoardController.unit_moved.connect(_on_unit_moved)
	BoardController.unit_sold.connect(_on_unit_sold)

func _on_unit_moved(from_zone: String, from_pos: Variant,
                    to_zone: String, to_pos: Variant, unit_data: Dictionary):
	update_bench_ui()

func _on_unit_sold(zone: String, pos: Variant, gold_refund: int):
	update_bench_ui()
```

**Step 4: Commit**

```bash
git add src/Scripts/MainGame.gd
git commit -m "refactor: MainGame.gd now uses BoardController for bench operations"
```

---

## Task 7: 修改 Bench.gd 使用 BoardController

**Files:**
- Modify: `src/Scripts/UI/Bench.gd`

**Step 1: 连接 SessionData 信号**

在 `_ready` 函数中添加：

```gdscript
func _ready():
	if slots_container:
		slots_container.add_theme_constant_override("h_separation", 10)
		slots_container.add_theme_constant_override("v_separation", 10)
		var parent = slots_container.get_parent()
		if parent is PanelContainer:
			var style = StyleBoxEmpty.new()
			parent.add_theme_stylebox_override("panel", style)

	# 连接 SessionData 信号
	if GameManager.session_data:
		GameManager.session_data.bench_updated.connect(_on_bench_updated)

func _on_bench_updated(bench_units: Dictionary):
	# 转换为数组格式
	var bench_array = []
	bench_array.resize(Constants.BENCH_SIZE)
	bench_array.fill(null)
	for index in bench_units.keys():
		if index >= 0 and index < Constants.BENCH_SIZE:
			bench_array[index] = bench_units[index]
	update_bench_ui(bench_array)
```

**Step 2: Commit**

```bash
git add src/Scripts/UI/Bench.gd
git commit -m "refactor: Bench.gd now listens to SessionData signals"
```

---

## Task 8: 修改 MainGUI.gd 使用 SessionData 信号

**Files:**
- Modify: `src/Scripts/UI/MainGUI.gd`

**Step 1: 修改 _ready 函数连接 SessionData 信号**

```gdscript
func _ready():
	# ... 现有代码 ...

	# 连接 SessionData 信号（替代 GameManager.resource_changed）
	if GameManager.session_data:
		GameManager.session_data.gold_changed.connect(_on_gold_changed)
		GameManager.session_data.mana_changed.connect(_on_mana_changed)
		GameManager.session_data.core_health_changed.connect(_on_core_health_changed)
		GameManager.session_data.wave_changed.connect(_on_wave_changed)

	# 保留 GameManager 信号用于其他事件
	GameManager.resource_changed.connect(update_ui)
	GameManager.wave_started.connect(update_ui)
	GameManager.wave_ended.connect(update_ui)
	# ... 其余代码 ...

func _on_gold_changed(new_amount: int):
	if gold_label:
		gold_label.text = "💰 %d" % new_amount
	if combat_gold_label:
		combat_gold_label.text = "💰 %d" % new_amount

func _on_mana_changed(current: float, maximum: float):
	if mana_bar:
		mana_bar.value = (current / maximum) * 100
	if mana_label:
		mana_label.text = "💧 %d/%d" % [int(current), int(maximum)]

func _on_core_health_changed(current: float, maximum: float):
	if hp_bar:
		var target_hp = (current / maximum) * 100
		create_tween().tween_property(hp_bar, "value", target_hp, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hp_label:
		hp_label.text = "❤️ %d/%d" % [int(current), int(maximum)]

func _on_wave_changed(new_wave: int):
	if wave_label:
		wave_label.text = "Wave %d" % new_wave
```

**Step 2: Commit**

```bash
git add src/Scripts/UI/MainGUI.gd
git commit -m "refactor: MainGUI.gd now listens to SessionData signals for resource updates"
```

---

## Task 9: 创建测试脚本验证 API

**Files:**
- Create: `src/Scripts/Tests/BoardControllerTest.gd`

**Step 1: 创建测试脚本**

```gdscript
class_name BoardControllerTest
extends Node

var test_results = []

func _ready():
	print("=== BoardController API Test ===")

	# 等待一帧确保所有节点初始化
	await get_tree().process_frame

	# 运行测试
	_test_session_data_exists()
	_test_board_controller_exists()
	_test_buy_unit_api()
	_test_refresh_shop_api()
	_test_move_unit_api()

	# 输出结果
	print("\n=== Test Results ===")
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)

	var passed_count = test_results.filter(func(r): return r.passed).size()
	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

func _test_session_data_exists():
	var result = {"name": "SessionData exists", "passed": false, "error": ""}
	if GameManager.session_data:
		result.passed = true
	else:
		result.error = "GameManager.session_data is null"
	test_results.append(result)

func _test_board_controller_exists():
	var result = {"name": "BoardController exists", "passed": false, "error": ""}
	if BoardController:
		result.passed = true
	else:
		result.error = "BoardController is null"
	test_results.append(result)

func _test_buy_unit_api():
	var result = {"name": "buy_unit API exists", "passed": false, "error": ""}
	if BoardController.has_method("buy_unit"):
		result.passed = true
	else:
		result.error = "BoardController.buy_unit method not found"
	test_results.append(result)

func _test_refresh_shop_api():
	var result = {"name": "refresh_shop API exists", "passed": false, "error": ""}
	if BoardController.has_method("refresh_shop"):
		result.passed = true
	else:
		result.error = "BoardController.refresh_shop method not found"
	test_results.append(result)

func _test_move_unit_api():
	var result = {"name": "try_move_unit API exists", "passed": false, "error": ""}
	if BoardController.has_method("try_move_unit"):
		result.passed = true
	else:
		result.error = "BoardController.try_move_unit method not found"
	test_results.append(result)
```

**Step 2: 修改 MainGame.gd 在测试模式下运行测试**

在 `_attach_test_runner` 函数中添加：

```gdscript
func _attach_test_runner():
	# 运行 BoardController 测试
	var test_script = load("res://src/Scripts/Tests/BoardControllerTest.gd")
	if test_script:
		var test_runner = test_script.new()
		add_child(test_runner)
	else:
		printerr("[MainGame] Failed to load BoardControllerTest.gd")
```

**Step 3: Commit**

```bash
git add src/Scripts/Tests/BoardControllerTest.gd src/Scripts/MainGame.gd
git commit -m "test: add BoardController API test script"
```

---

## Task 10: 命令行测试验证

**Step 1: 创建测试运行脚本**

创建 `run_test.sh`：

```bash
#!/bin/bash
cd /home/zhangzhan/tower
echo "Running Godot in test mode..."
godot --path . --headless --debug 2>&1 | tee test_output.log &
PID=$!
sleep 10
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo ""
echo "=== Checking test results ==="
if grep -q "BoardController API Test" test_output.log; then
    echo "✅ Test script executed"
else
    echo "❌ Test script not found in output"
fi

if grep -q "SessionData exists.*PASS" test_output.log; then
    echo "✅ SessionData test passed"
else
    echo "❌ SessionData test failed"
fi

if grep -q "BoardController exists.*PASS" test_output.log; then
    echo "✅ BoardController test passed"
else
    echo "❌ BoardController test failed"
fi

if grep -q "Null Reference" test_output.log; then
    echo "❌ Null Reference errors found:"
    grep "Null Reference" test_output.log | head -5
fi

if grep -q "Method not found" test_output.log; then
    echo "❌ Method not found errors:"
    grep "Method not found" test_output.log | head -5
fi
```

**Step 2: 运行测试**

```bash
chmod +x run_test.sh
./run_test.sh
```

**Step 3: 修复发现的错误**

根据测试输出修复任何 Null Reference 或 Method not found 错误。

**Step 4: Commit**

```bash
git add run_test.sh
git commit -m "test: add command line test runner script"
```

---

## 总结

重构完成后：

1. **SessionData** - 纯数据层，存储所有战局状态
2. **BoardController** - 纯逻辑层，提供 AI 可调用的 API
3. **UI 层** - 只监听信号，不直接修改数据

AI Agent 可以通过以下 API 与游戏交互：
- `BoardController.buy_unit(shop_index: int) -> bool`
- `BoardController.refresh_shop() -> bool`
- `BoardController.try_move_unit(from_zone, from_pos, to_zone, to_pos) -> bool`
- `BoardController.sell_unit(zone, pos) -> bool`
- `BoardController.start_wave() -> bool`
