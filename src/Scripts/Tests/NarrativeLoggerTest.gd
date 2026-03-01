extends SceneTree
class_name NarrativeLoggerTest

func _init():
	print("=== NarrativeLogger Functional Test ===")

	await process_frame
	await process_frame

	var test_results = []
	var logger = root.get_node_or_null("NarrativeLogger")

	var emitted_data = {}

	if logger:
		logger.narrative_generated.connect(func(type, data):
			emitted_data["type"] = type
			emitted_data["data"] = data
		)

		# Test log_action
		logger.log_action("Test narrative", {"key": "value"})

	var result1 = {"name": "log_action emits correctly formatted dict", "passed": false, "error": ""}
	if emitted_data.has("data"):
		var data = emitted_data["data"]
		if data.has("event") and data.has("narrative") and data.has("data") and data.has("timestamp"):
			if data["event"] == "Action" and data["narrative"] == "Test narrative" and data["data"].has("key"):
				result1.passed = true
			else:
				result1.error = "Data contents mismatch"
		else:
			result1.error = "Missing one or more required keys"
	else:
		result1.error = "No signal data received"
	test_results.append(result1)

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
