extends SceneTree

var buff_manager
var mock_unit
var mock_source

func _init():
	print("--- Running Test: Buff System ---")

	# Setting up mocks
	mock_unit = Node2D.new()
	mock_unit.name = "MockUnit"
	mock_source = Node2D.new()
	mock_source.name = "MockSource"

	# Instantiate BuffManager
	var BuffManagerClass = load("res://src/Scripts/Units/Components/BuffManager.gd")
	if not BuffManagerClass:
		print("FAILED: Could not load BuffManager.gd")
		quit(1)
		return
	buff_manager = BuffManagerClass.new()
	buff_manager.unit = mock_unit

	test_initialization()
	test_apply_buff()
	test_stacking()
	test_logging()

	print("--- All Buff System Tests Passed ---")
	quit(0)

func test_initialization():
	assert(buff_manager.active_buffs.size() == 0, "active_buffs should be empty on init")
	assert(buff_manager.buff_sources.size() == 0, "buff_sources should be empty on init")

func test_apply_buff():
	buff_manager.add_buff("range", mock_source)
	assert(buff_manager.active_buffs.has("range"), "Buff 'range' should be applied")
	assert(buff_manager.buff_sources["range"] == mock_source, "Source for 'range' should be mock_source")

func test_stacking():
	# Assuming bounce can stack
	buff_manager.add_buff("bounce", mock_source)
	buff_manager.add_buff("bounce", mock_source)
	assert(buff_manager.active_buffs.has("bounce"), "Buff 'bounce' should be applied")
	# More specific stacking assertions depend on exact implementation

func test_logging():
	# Since AILogger and AIManager are globals or autoloads, we might need to mock them if they aren't available in test context,
	# but for headless initial test failure, we just expect the method calls to either fail or work if implemented.
	buff_manager.add_buff("speed", mock_source)
	pass
