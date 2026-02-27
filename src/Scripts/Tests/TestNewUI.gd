extends Node2D

@onready var inventory_panel = $CanvasLayer/HBoxContainer/InventoryPanel
@onready var passive_bar = $CanvasLayer/HBoxContainer/PassiveSkillBar

# Mock Unit Class
class MockUnit:
	extends RefCounted
	var name = "MockUnit"
	var type_key = "viper"
	var production_timer = 1.0
	var unit_data = {}

	func _init(key):
		type_key = key
		name = key + str(randi())

# Mock InventoryManager
class MockInventoryManager:
	signal inventory_updated(data)
	var items = []

	func get_inventory():
		return items

	func set_items(new_items):
		items = new_items
		emit_signal("inventory_updated", items)

func _ready():
	# Setup Mock GameManager components if needed
	if !GameManager.has_method("get"):
		# In real run GameManager is autoload.
		# If we run this as a standalone scene via "Play Scene", GameManager is present.
		pass

	# Setup mock inventory manager
	var mock_inv = MockInventoryManager.new()
	# We need to inject this into GameManager or InventoryPanel.
	# InventoryPanel connects to GameManager.inventory_manager.
	# We can temporarily assign it to GameManager if allowed, or modify the panel to accept it.
	# Since GameManager is global, we can set it.
	if "inventory_manager" in GameManager:
		GameManager.inventory_manager = mock_inv
	else:
		# If property doesn't exist, we can't assign it easily without add_user_signal/set_script_property if it's not dynamic.
		# But GDScript objects are dynamic.
		GameManager.set_script(GameManager.get_script()) # Reload? No.
		# We can just set it if it's declared or if it allows dynamic properties.
		# GameManager.gd doesn't declare it.
		GameManager.set("inventory_manager", mock_inv)

	# Manually trigger update in panel in case ready was called before we set the manager
	inventory_panel.update_inventory([
		{"id": "meat", "count": 1},
		{"id": "fang", "count": 5},
		null,
		{"id": "poison", "count": 10}
	])

	# Setup Mock Units for Passive Bar
	# PassiveBar looks at monitored_units. We need to populate it manually for test
	# because GridManager isn't fully set up with tiles in this test scene.
	var unit1 = MockUnit.new("viper")
	var unit2 = MockUnit.new("scorpion")

	passive_bar.monitored_units = [unit1, unit2]
	passive_bar._create_card(unit1)
	passive_bar._create_card(unit2)

	# Start simulation loop
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(func(): _sim_loop(unit1, unit2))
	add_child(timer)

func _sim_loop(u1, u2):
	# Decrease timer
	u1.production_timer -= 0.1
	if u1.production_timer <= 0:
		u1.production_timer = 1.0

	u2.production_timer -= 0.05
	if u2.production_timer <= 0:
		u2.production_timer = 1.0
