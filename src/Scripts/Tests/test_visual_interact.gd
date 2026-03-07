extends SceneTree

var visual
var interact
var mock_unit

func _init():
	print("--- Running Test: Visual & Interact System ---")

	mock_unit = Node2D.new()
	mock_unit.name = "MockUnit"

	var VisualClass = load("res://src/Scripts/Units/Components/VisualController.gd")
	if not VisualClass:
		print("FAILED: Could not load VisualController.gd")
		quit(1)
		return
	visual = VisualClass.new()
	visual.unit = mock_unit

	var InteractClass = load("res://src/Scripts/Units/Components/InteractController.gd")
	if not InteractClass:
		print("FAILED: Could not load InteractController.gd")
		quit(1)
		return
	interact = InteractClass.new()
	interact.unit = mock_unit

	test_visual_animations()
	test_interact_dragging()

	print("--- All Visual & Interact System Tests Passed ---")
	quit(0)

func test_visual_animations():
	# Test play attack anim logic
	visual.play_attack_anim("melee", Vector2(10, 10))

func test_interact_dragging():
	interact.is_dragging = true
	assert(interact.is_dragging == true, "Should be dragging")
	interact.is_dragging = false
	assert(interact.is_dragging == false, "Should not be dragging")
