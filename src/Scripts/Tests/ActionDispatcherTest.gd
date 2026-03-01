extends SceneTree
class_name ActionDispatcherTest

func _init():
	print("=== ActionDispatcher Functional Test ===")

	await process_frame
	await process_frame

	var test_results = []

	var dispatcher = root.get_node_or_null("ActionDispatcher")
	var board_controller = root.get_node_or_null("BoardController")

	# Try a mock buy_unit call to check routing
	# Setup fake shop data since GameManager is involved
	var gm = root.get_node_or_null("GameManager")
	if gm and gm.session_data:
		gm.session_data.add_gold(100)
		gm.session_data.set_shop_unit(0, "wolf")

	var result1 = {"name": "execute_action returns success structure", "passed": false, "error": ""}
	if dispatcher:
		var result = dispatcher.execute_action({"type": "buy_unit", "shop_index": 0})
		if result.has("success"):
			result1.passed = true
		else:
			result1.error = "Result is missing success key"
	else:
		result1.error = "ActionDispatcher not found"
	test_results.append(result1)

	var result2 = {"name": "execute_action handles unknown actions safely", "passed": false, "error": ""}
	if dispatcher:
		var result = dispatcher.execute_action({"type": "invalid_action"})
		if result.success == false and result.has("error_message"):
			result2.passed = true
		else:
			result2.error = "Invalid action was not properly handled"
	else:
		result2.error = "ActionDispatcher not found"
	test_results.append(result2)

	print("\n=== Test Results ===")
	var passed_count = 0
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)
		if result.passed:
			passed_count += 1

	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

	quit(0 if passed_count == total_count else 1)
