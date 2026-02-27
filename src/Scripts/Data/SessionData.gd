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
