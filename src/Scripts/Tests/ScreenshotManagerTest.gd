class_name ScreenshotManagerTest
extends Node

var test_results = []

func _ready():
	print("=== ScreenshotManager Test ===")
	await get_tree().process_frame

	_test_screenshot_manager_exists()
	_test_trigger_methods_exist()

	print("\n=== Test Results ===")
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)

	var passed_count = test_results.filter(func(r): return r.passed).size()
	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

func _test_screenshot_manager_exists():
	var result = {"name": "ScreenshotManager exists", "passed": false, "error": ""}
	if has_node("/root/ScreenshotManager"):
		result.passed = true
	else:
		result.error = "ScreenshotManager autoload not found"
	test_results.append(result)

func _test_trigger_methods_exist():
	var result = {"name": "Trigger methods exist", "passed": true, "error": ""}
	var manager = get_node_or_null("/root/ScreenshotManager")
	if manager:
		if not manager.has_method("_take_screenshot"):
			result.passed = false
			result.error = "_take_screenshot method missing"
	else:
		result.passed = false
		result.error = "Manager not found"
	test_results.append(result)
