extends SceneTree

func _init():
	print("=== Starting BoardController API Test ===")

	# Wait for all autoloads to initialize
	await process_frame
	await process_frame

	var test_results = []

	# Test 1: SessionData exists
	var gm = root.get_node_or_null("GameManager")
	var bc = root.get_node_or_null("BoardController")
	var ad = root.get_node_or_null("ActionDispatcher")

	# Test 1: SessionData exists
	var result1 = {"name": "SessionData exists", "passed": false, "error": ""}
	if gm and gm.session_data:
		result1.passed = true
	else:
		result1.error = "GameManager.session_data is null"
	test_results.append(result1)

	# Test 2: BoardController exists
	var result2 = {"name": "BoardController exists", "passed": false, "error": ""}
	if bc:
		result2.passed = true
	else:
		result2.error = "BoardController is null"
	test_results.append(result2)

	# Test 3: buy_unit API exists
	var result3 = {"name": "buy_unit API exists", "passed": false, "error": ""}
	if ad and ad.has_method("buy_unit"):
		result3.passed = true
	else:
		result3.error = "ActionDispatcher.buy_unit method not found"
	test_results.append(result3)

	# Test 4: refresh_shop API exists
	var result4 = {"name": "refresh_shop API exists", "passed": false, "error": ""}
	if ad and ad.has_method("refresh_shop"):
		result4.passed = true
	else:
		result4.error = "ActionDispatcher.refresh_shop method not found"
	test_results.append(result4)

	# Test 5: try_move_unit API exists
	var result5 = {"name": "try_move_unit API exists", "passed": false, "error": ""}
	if ad and ad.has_method("try_move_unit"):
		result5.passed = true
	else:
		result5.error = "ActionDispatcher.try_move_unit method not found"
	test_results.append(result5)

	# Test 6: sell_unit API exists
	var result6 = {"name": "sell_unit API exists", "passed": false, "error": ""}
	if ad and ad.has_method("sell_unit"):
		result6.passed = true
	else:
		result6.error = "ActionDispatcher.sell_unit method not found"
	test_results.append(result6)

	# Test 7: start_wave API exists
	var result7 = {"name": "start_wave API exists", "passed": false, "error": ""}
	if ad and ad.has_method("start_wave"):
		result7.passed = true
	else:
		result7.error = "ActionDispatcher.start_wave method not found"
	test_results.append(result7)

	# Test 8: SessionData signals exist
	var result8 = {"name": "SessionData signals exist", "passed": false, "error": ""}
	if gm and gm.session_data and gm.session_data.has_signal("gold_changed"):
		result8.passed = true
	else:
		result8.error = "SessionData signals not found"
	test_results.append(result8)

	# Run ActionDispatcherTest
	var dispatcher_script = load("res://src/Scripts/Tests/ActionDispatcherTest.gd")
	if dispatcher_script:
		var node = dispatcher_script.new()
		root.add_child(node)

	# Run NarrativeLoggerTest
	var logger_script = load("res://src/Scripts/Tests/NarrativeLoggerTest.gd")
	if logger_script:
		var node = logger_script.new()
		root.add_child(node)

	# Run ScreenshotManagerTest
	var screenshot_script = load("res://src/Scripts/Tests/ScreenshotManagerTest.gd")
	if screenshot_script:
		var node = screenshot_script.new()
		root.add_child(node)

	# Allow tests to process
	await process_frame
	await process_frame

	# Print results
	print("\n=== Test Results ===")
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)

	var passed_count = 0
	for r in test_results:
		if r.passed:
			passed_count += 1
	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

	# Exit after tests
	print("\n=== Test Complete ===")
	quit(0 if passed_count == total_count else 1)
