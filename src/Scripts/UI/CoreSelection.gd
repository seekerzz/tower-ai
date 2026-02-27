extends Control

const CoreCardScene = preload("res://src/Scenes/UI/CoreCard.tscn")

@onready var container = $ScrollContainer/HBoxContainer

func _ready():
	var args = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for arg in args:
		if arg.begins_with("--run-test="):
			var case_id = arg.split("=")[1]
			call_deferred("_launch_test_mode", case_id)
			return

	_create_cards()

func _launch_test_mode(case_id: String):
	print("[Test] Launching: ", case_id)

	var suite_script = load("res://src/Scripts/Tests/TestSuite.gd")
	if !suite_script:
		printerr("[Test] Failed to load TestSuite.gd")
		return

	var suite = suite_script.new()
	var config = suite.get_test_config(case_id)

	if config.is_empty():
		printerr("[Test] Unknown test case: ", case_id)
		get_tree().quit()
		return

	GameManager.set_test_scenario(config)
	_on_core_selected(config.get("core_type", "cornucopia"))

func _create_cards():
	var core_data = {}
	if GameManager.data_manager and GameManager.data_manager.data.has("CORE_TYPES"):
		core_data = GameManager.data_manager.data["CORE_TYPES"]
	else:
		print("Error: CORE_TYPES not found in DataManager!")
		return

	for key in core_data.keys():
		var data = core_data[key]
		var card = CoreCardScene.instantiate()

		container.add_child(card)
		card.setup(key, data)
		card.card_selected.connect(_on_core_selected)

func _on_core_selected(core_key: String):
	GameManager.core_type = core_key

	# Load MainGame scene
	var main_game_scene = load("res://src/Scenes/Game/MainGame.tscn")
	if main_game_scene:
		get_tree().change_scene_to_packed(main_game_scene)
	else:
		print("Error: MainGame scene not found!")
