extends Node

# --- Mock Classes ---
class MockInventoryManager:
	var items = {} # slot -> item
	var removed_slots = []

	func remove_item(slot_index):
		removed_slots.append(slot_index)

class MockUnit:
	var devour_count = 0

	func devour(food_unit):
		devour_count += 1

	func has_node(name):
		return false

	func get_node_or_null(name):
		return null

class MockTile:
	var unit = null
	var x = 0
	var y = 0
	var occupied_by = Vector2i.ZERO

class MockGridManager:
	pass

# --- Test Script ---

var UnitDragHandlerScript = preload("res://src/Scripts/UI/UnitDragHandler.gd")
var TileDropHandlerScript = preload("res://src/Scripts/UI/TileDropHandler.gd")

func _ready():
	print("Running TestUnitFeeding...")

	setup_mocks()

	test_can_drop_meat_on_unit()
	test_can_drop_trap_on_unit()
	test_drop_meat_on_unit_action()
	test_tile_drop_ignores_meat()

	print("All tests passed!")
	get_tree().quit()

func setup_mocks():
	# Mock InventoryManager
	# We rely on GameManager being autoloaded and accessible.
	# We temporarily swap inventory_manager.

	if !GameManager.inventory_manager:
		GameManager.inventory_manager = MockInventoryManager.new()
	else:
		# If real one exists, we can still swap it for test safety if we want,
		# or assumes it behaves if we just want to verify method calls.
		# Ideally we swap it.
		GameManager.inventory_manager = MockInventoryManager.new()


func test_can_drop_meat_on_unit():
	var handler = UnitDragHandlerScript.new()
	var mock_unit = MockUnit.new()
	handler.setup(mock_unit)

	var data = { "source": "inventory", "item": { "item_id": "meat" } }
	var result = handler._can_drop_data(Vector2.ZERO, data)

	assert(result == true, "Should allow dropping meat on unit")
	print("Test_Can_Drop_Meat_On_Unit: PASS")

	handler.free()

func test_can_drop_trap_on_unit():
	var handler = UnitDragHandlerScript.new()
	var mock_unit = MockUnit.new()
	handler.setup(mock_unit)

	var data = { "source": "inventory", "item": { "item_id": "poison_trap" } }
	var result = handler._can_drop_data(Vector2.ZERO, data)

	assert(result == false, "Should NOT allow dropping trap on unit")
	print("Test_Can_Drop_Trap_On_Unit: PASS")

	handler.free()

func test_drop_meat_on_unit_action():
	var handler = UnitDragHandlerScript.new()
	var mock_unit = MockUnit.new()
	handler.setup(mock_unit)

	# Reset mock inventory
	var mock_inv = MockInventoryManager.new()
	GameManager.inventory_manager = mock_inv

	var data = { "source": "inventory", "item": { "item_id": "meat" }, "slot_index": 5 }

	handler._drop_data(Vector2.ZERO, data)

	assert(mock_unit.devour_count == 1, "Unit should have devoured")
	assert(mock_inv.removed_slots.has(5), "Item should be removed from slot 5")
	print("Test_Drop_Meat_On_Unit_Action: PASS")

	handler.free()

func test_tile_drop_ignores_meat():
	var handler = TileDropHandlerScript.new()
	var mock_tile = MockTile.new()
	mock_tile.unit = MockUnit.new() # Tile has a unit
	handler.setup(mock_tile)

	# Reset mock inventory
	var mock_inv = MockInventoryManager.new()
	GameManager.inventory_manager = mock_inv

	var data = { "source": "inventory", "item": { "item_id": "meat" }, "slot_index": 2 }

	# Call _handle_inventory_drop directly or via _drop_data
	# Note: TileDropHandler._handle_inventory_drop is private-ish but accessible in GDScript
	if handler.has_method("_handle_inventory_drop"):
		handler._handle_inventory_drop(data)

	# Assert nothing happened
	# If logic was removed, no remove_item called
	assert(mock_inv.removed_slots.is_empty(), "Meat drop on Tile should NOT remove item (UnitDragHandler handles it)")

	print("Test_TileDrop_Ignores_Meat: PASS")

	handler.free()
