extends SceneTree

var action_dispatcher = null
var test_passed = false

func _init():
	print("=== Starting ActionDispatcherTest ===")

	# Instantiate our mock ActionDispatcher
	action_dispatcher = load("res://src/Autoload/ActionDispatcher.gd").new()
	if not action_dispatcher:
		printerr("Failed to load ActionDispatcher")
		quit(1)
		return

	root.add_child(action_dispatcher)

	# Use process_frame to give it time to run _ready
	await process_frame

	_run_tests()

func _run_tests():
	var tests = [
		{"name": "ActionDispatcher exists", "fn": _test_exists},
		{"name": "No AIActionExecutor wait logic", "fn": _test_no_execution_status}
	]

	var passed_count = 0
	for test in tests:
		print("Running test: ", test.name)
		var result = test.fn.call()
		if result:
			print("✅ PASS: ", test.name)
			passed_count += 1
		else:
			print("❌ FAIL: ", test.name)

	test_passed = (passed_count == tests.size())
	print("\n=== ActionDispatcherTest Results ===")
	print("Total: %d/%d passed" % [passed_count, tests.size()])

	quit(0 if test_passed else 1)

func _test_exists() -> bool:
	return action_dispatcher != null

func _test_no_execution_status() -> bool:
	# ActionDispatcher should not have the stateful get_execution_status of AIActionExecutor
	return not action_dispatcher.has_method("get_execution_status")
