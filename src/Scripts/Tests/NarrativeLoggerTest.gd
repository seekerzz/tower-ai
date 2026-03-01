extends SceneTree

var narrative_logger = null

func _init():
	print("=== Starting NarrativeLoggerTest ===")

	narrative_logger = load("res://src/Autoload/NarrativeLogger.gd").new()
	if not narrative_logger:
		printerr("Failed to load NarrativeLogger")
		quit(1)
		return

	root.add_child(narrative_logger)

	await process_frame

	_run_tests()

func _run_tests():
	var tests = [
		{"name": "NarrativeLogger exists", "fn": _test_exists},
		{"name": "Generates valid dictionary", "fn": _test_generation}
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
	print("\n=== NarrativeLoggerTest Results ===")
	print("Total: %d/%d passed" % [passed_count, tests.size()])

	quit(0 if test_passed else 1)

func _test_exists() -> bool:
	return narrative_logger != null

func _test_generation() -> bool:
	if not narrative_logger.has_method("_build_narrative_dict"):
		printerr("_build_narrative_dict method not found")
		return false

	var result = narrative_logger._build_narrative_dict("WaveStarted", "波次开始了！", {"wave": 1})

	if typeof(result) != TYPE_DICTIONARY:
		printerr("Result is not a dictionary")
		return false

	if not result.has("event") or result["event"] != "WaveStarted":
		printerr("Missing or incorrect 'event' key")
		return false

	if not result.has("narrative") or result["narrative"] != "波次开始了！":
		printerr("Missing or incorrect 'narrative' key")
		return false

	if not result.has("data") or typeof(result["data"]) != TYPE_DICTIONARY:
		printerr("Missing or incorrect 'data' key")
		return false

	return true
