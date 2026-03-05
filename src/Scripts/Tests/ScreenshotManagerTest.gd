extends SceneTree

var screenshot_manager = null
var test_dir = "logs/screenshots/"

func _init():
	print("=== Starting ScreenshotManagerTest ===")

	screenshot_manager = load("res://src/Autoload/ScreenshotManager.gd").new()
	if not screenshot_manager:
		printerr("Failed to load ScreenshotManager")
		quit(1)
		return

	root.add_child(screenshot_manager)

	# Wait a frame for setup
	await process_frame

	_run_tests()

func _run_tests():
	var tests = [
		{"name": "ScreenshotManager exists", "fn": _test_exists},
		{"name": "Methods decoupled", "fn": _test_decoupled_methods}
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

	var test_passed = (passed_count == tests.size())
	print("\n=== ScreenshotManagerTest Results ===")
	print("Total: %d/%d passed" % [passed_count, tests.size()])

	quit(0 if test_passed else 1)

func _test_exists() -> bool:
	return screenshot_manager != null

func _test_decoupled_methods() -> bool:
	return screenshot_manager.has_method("get_base64_screenshot") and screenshot_manager.has_method("save_screenshot_to_disk")
