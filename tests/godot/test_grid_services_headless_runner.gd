extends SceneTree

const ROOT := "/workspace/tower-ai"

class MockUnit:
	extends Node2D
	var reset_called := 0
	var update_called := 0
	var applied: Array = []
	var behavior = null
	var interaction_target_pos = null
	var unit_data := {"interaction_pattern": "none"}
	var grid_pos := Vector2i.ZERO

	func reset_stats() -> void:
		reset_called += 1

	func get_interaction_info() -> Dictionary:
		return {"has_interaction": false}

	func update_visuals() -> void:
		update_called += 1

	func apply_buff(buff_id: String, provider_unit: Node2D = null) -> void:
		applied.append({"buff_id": buff_id, "provider": provider_unit})

class MockTile:
	extends Node2D
	var x: int
	var y: int
	var state: String
	var unit = null
	var occupied_by := Vector2i.ZERO
	var grid_visible_calls := 0

	func _init(px: int = 0, py: int = 0, pstate: String = "unlocked") -> void:
		x = px
		y = py
		state = pstate

	func set_state(s: String) -> void:
		state = s

	func set_grid_visible(_visible: bool) -> void:
		grid_visible_calls += 1

class GhostTileMock:
	extends Node2D
	var custom_minimum_size := Vector2(60, 60)
	var setup_xy := Vector2i.ZERO

	func setup(x: int, y: int) -> void:
		setup_xy = Vector2i(x, y)

class DummyGrid:
	extends Node2D
	signal grid_updated

	var tiles: Dictionary = {}
	var ghost_tiles: Array = []
	var expansion_mode := false
	var expansion_cost := 50
	var active_territory_tiles: Array = []
	var GHOST_TILE_SCRIPT = GhostTileMock

	func get_tile_key(x: int, y: int) -> String:
		return "%d,%d" % [x, y]

	func is_neighbor(_unit, _target) -> bool:
		return true

	func _get_clockwise_neighbors(_pos: Vector2i) -> Array:
		return []

	func grid_to_local(grid_pos: Vector2i) -> Vector2:
		return Vector2(grid_pos.x * 60, grid_pos.y * 60)

	func get_world_pos_from_grid(grid_pos: Vector2i) -> Vector2:
		return grid_to_local(grid_pos)

var _failed := false

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failed = true
		printerr("[HEADLESS TEST FAIL] %s" % msg)

func _assert_gridmanager_delegation_text() -> void:
	var path := ROOT + "/src/Scripts/GridManager.gd"
	var txt := FileAccess.get_file_as_string(path)
	_assert(txt.length() > 0, "Cannot read GridManager.gd")
	_assert(txt.contains("grid_buff_service.recalculate_buffs()"), "Missing recalculate delegation")
	_assert(txt.contains("grid_buff_service.apply_buff_to_specific_pos(target_pos, buff_id, provider_unit)"), "Missing specific buff delegation")
	_assert(txt.contains("grid_expansion_service.toggle_expansion_mode()"), "Missing expansion toggle delegation")
	_assert(txt.contains("grid_expansion_service.spawn_expansion_ghosts()"), "Missing spawn ghost delegation")
	_assert(txt.contains("grid_expansion_service.clear_ghosts()"), "Missing clear ghost delegation")
	_assert(txt.contains("grid_expansion_service.on_ghost_clicked(x, y)"), "Missing ghost click delegation")
	_assert(txt.contains("return grid_expansion_service.get_closest_unlocked_tile(world_pos)"), "Missing closest tile delegation")

func _test_buff_service() -> void:
	var buff_script = load(ROOT + "/src/Scripts/Services/GridBuffService.gd")
	_assert(buff_script != null, "Cannot load GridBuffService")

	var grid := DummyGrid.new()
	var unit_a := MockUnit.new()
	var unit_b := MockUnit.new()
	var provider := MockUnit.new()

	var t1 := MockTile.new(0, 0, "unlocked")
	t1.unit = unit_a
	var t2 := MockTile.new(1, 0, "unlocked")
	t2.unit = unit_b

	grid.tiles[grid.get_tile_key(0, 0)] = t1
	grid.tiles[grid.get_tile_key(1, 0)] = t2

	var svc = buff_script.new(grid)
	svc.recalculate_buffs()
	_assert(unit_a.reset_called == 1 and unit_b.reset_called == 1, "recalculate_buffs should reset units")
	_assert(unit_a.update_called == 1 and unit_b.update_called == 1, "recalculate_buffs should update visuals")

	svc.apply_buff_to_specific_pos(Vector2i(1, 0), "atk_up", provider)
	_assert(unit_b.applied.size() == 1, "apply_buff_to_specific_pos should apply buff")
	_assert(unit_b.applied[0].buff_id == "atk_up", "applied buff id mismatch")

func _test_expansion_service() -> void:
	var exp_script = load(ROOT + "/src/Scripts/Services/GridExpansionService.gd")
	_assert(exp_script != null, "Cannot load GridExpansionService")

	var grid := DummyGrid.new()
	var core := MockTile.new(0, 0, "unlocked")
	core.global_position = Vector2.ZERO
	var locked := MockTile.new(1, 0, "locked_inner")
	locked.global_position = Vector2(60, 0)

	grid.tiles[grid.get_tile_key(0, 0)] = core
	grid.tiles[grid.get_tile_key(1, 0)] = locked
	grid.active_territory_tiles = [core]

	var svc = exp_script.new(grid)
	svc.toggle_expansion_mode()
	_assert(grid.expansion_mode == true, "toggle_expansion_mode should switch state")
	_assert(core.grid_visible_calls == 1 and locked.grid_visible_calls == 1, "toggle_expansion_mode should update tile visuals")
	_assert(grid.ghost_tiles.size() == 1, "spawn_expansion_ghosts should create ghost for eligible tile")

	# clear ghosts
	svc.clear_ghosts()
	_assert(grid.ghost_tiles.is_empty(), "clear_ghosts should empty ghost list")

	# closest tile
	var far := MockTile.new(3, 0, "unlocked")
	far.global_position = Vector2(300, 0)
	grid.active_territory_tiles = [far, core]
	var closest = svc.get_closest_unlocked_tile(Vector2(10, 0))
	_assert(closest == core, "get_closest_unlocked_tile should return nearest unlocked tile")

func _init() -> void:
	_assert_gridmanager_delegation_text()
	_test_buff_service()
	_test_expansion_service()
	if _failed:
		printerr("[HEADLESS TEST RESULT] FAILED")
		quit(1)
		return
	print("[HEADLESS TEST PASS] Grid services runtime + GridManager delegation checks passed")
	quit(0)
