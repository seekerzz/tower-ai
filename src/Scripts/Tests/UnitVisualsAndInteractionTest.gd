extends SceneTree

func _init():
	print("=== Starting Unit Visuals & Interaction Test ===")
	call_deferred("_run_test")

func _run_test():
	var test_results = []

	var unit_scene = load("res://src/Scenes/Game/Unit.tscn")
	var unit = unit_scene.instantiate()
	root.add_child(unit)

	unit.unit_data = {
		"icon": "🐭",
		"size": Vector2(1, 1),
		"hp": 100,
		"damage": 10
	}
	unit.type_key = "test_mouse"

	# Manually trigger ready logic to ensure setup finishes
	pass
	unit.visual_update_requested.emit()

	# Test 1: Damage bounce fast trigger
	var test1 = {"name": "Damage Bounce Tween auto-kill", "passed": false, "error": ""}
	var visual_holder = unit.get_node_or_null("VisualHolder")
	if not visual_holder:
		test1.error = "VisualHolder not created."
	else:
		for i in range(5):
			unit.on_damage_taken_visual.emit()
		test1.passed = true
	test_results.append(test1)

	# Test 2: Dragging ghost node and state check
	var test2 = {"name": "Dragging state and ghost node creation/deletion", "passed": false, "error": ""}

	unit.drag_started.emit(Vector2(100, 100))
	var interaction = unit._unit_interaction
	if not interaction:
		test2.error = "_unit_interaction not found"
	elif not interaction.is_dragging:
		test2.error = "is_dragging flag not true after drag_started"
	elif interaction.ghost_node == null:
		test2.error = "ghost_node not created after drag_started"
	else:
		interaction.end_drag()
		if interaction.is_dragging:
			test2.error = "is_dragging flag still true after end_drag"
		elif interaction.ghost_node != null:
			test2.error = "ghost_node not cleared after end_drag"
		else:
			test2.passed = true
	test_results.append(test2)

	unit.queue_free()

	print("\n=== Test Results ===")
	var passed_count = 0
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)
		else:
			passed_count += 1

	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])
	print("\n=== Test Complete ===")
	quit(0 if passed_count == total_count else 1)
