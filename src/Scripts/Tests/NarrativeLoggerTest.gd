class_name NarrativeLoggerTest
extends Node

var test_results = []
var emitted_json = null

func _ready():
	print("=== NarrativeLogger API Test ===")
	await get_tree().process_frame

	_test_narrative_logger_exists()
	_test_format_and_capture()

	print("\n=== Test Results ===")
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)

	var passed_count = test_results.filter(func(r): return r.passed).size()
	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

func _test_narrative_logger_exists():
	var result = {"name": "NarrativeLogger exists", "passed": false, "error": ""}
	if has_node("/root/NarrativeLogger"):
		result.passed = true
	else:
		result.error = "NarrativeLogger autoload not found"
	test_results.append(result)

func _test_format_and_capture():
	var result = {"name": "Log Dictionary Format", "passed": false, "error": ""}
	var logger = get_node_or_null("/root/NarrativeLogger")
	if logger:
		if logger.has_method("_create_log_entry"):
			var entry = logger._create_log_entry("test_event", {"some_data": 1}, "This is a test narrative.")
			if "narrative" in entry and entry.narrative == "This is a test narrative.":
				result.passed = true
			else:
				result.error = "Format incorrect: " + str(entry)
		else:
			result.error = "_create_log_entry method not found"
	else:
		result.error = "Logger not found"
	test_results.append(result)
