class_name ActionDispatcherTest
extends Node

var test_results = []

func _ready():
	print("=== ActionDispatcher API Test ===")
	await get_tree().process_frame

	_test_action_dispatcher_exists()
	_test_proxy_methods_exist()

	print("\n=== Test Results ===")
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)

	var passed_count = test_results.filter(func(r): return r.passed).size()
	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

func _test_action_dispatcher_exists():
	var result = {"name": "ActionDispatcher exists", "passed": false, "error": ""}
	if has_node("/root/ActionDispatcher"):
		result.passed = true
	else:
		result.error = "ActionDispatcher autoload not found"
	test_results.append(result)

func _test_proxy_methods_exist():
	var result = {"name": "Proxy methods exist", "passed": true, "error": ""}
	var dispatcher = get_node_or_null("/root/ActionDispatcher")
	if dispatcher:
		var methods = ["buy_unit", "refresh_shop", "try_move_unit", "sell_unit", "start_wave", "retry_wave"]
		for m in methods:
			if not dispatcher.has_method(m):
				result.passed = false
				result.error += m + " missing. "
	else:
		result.passed = false
		result.error = "Dispatcher not found"
	test_results.append(result)
