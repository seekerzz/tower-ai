extends SceneTree

func _init():
	print("Running Unit Refactor tests...")
	var success = true

	# Fake autoloads to pass validation
	var cm = Node.new()
	cm.name = "Constants"
	self.root.add_child(cm)
	var gm = Node.new()
	gm.name = "GameManager"
	self.root.add_child(gm)

	var UnitClass = load("res://src/Scripts/Unit.gd")
	var VisualsClass = load("res://src/Scripts/Components/UnitVisuals.gd")
	var InteractionClass = load("res://src/Scripts/Components/UnitInteraction.gd")

	var unit = UnitClass.new()

	# Avoid executing actual behavior loads by stubbing type_key to invalid
	unit.type_key = "invalid_so_no_load"
	var v_holder = Node2D.new()
	v_holder.name = "VisualHolder"
	unit.add_child(v_holder)

	var visuals = VisualsClass.new()
	unit.add_child(visuals)
	visuals.unit = unit
	visuals.visual_holder = v_holder


	self.root.add_child(unit)

	visuals._on_damage_taken()
	for i in range(5):
		unit.damage_taken.emit()

	if visuals.damage_tween != null and visuals.damage_tween.is_valid():
		print("test_damage_taken_tween_safety PASSED")
	else:
		success = false
		print("test_damage_taken_tween_safety FAILED")

	var interaction = InteractionClass.new()
	unit.add_child(interaction)
	interaction.unit = unit

	interaction.start_drag(Vector2(100, 100))
	var initial_ghost = interaction.ghost_node

	if interaction.is_dragging and initial_ghost != null and is_instance_valid(initial_ghost):
		pass
	else:
		success = false

	interaction.end_drag()

	if not interaction.is_dragging and interaction.ghost_node == null and (not is_instance_valid(initial_ghost) or initial_ghost.is_queued_for_deletion()):
		print("test_drag_event_sequence_and_ghost_free PASSED")
	else:
		success = false
		print("test_drag_event_sequence_and_ghost_free FAILED")

	if success:
		print("All refactor tests passed!")
	else:
		print("Some refactor tests failed.")

	unit.queue_free()
	quit(0 if success else 1)
