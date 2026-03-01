extends SceneTree

func _initialize():
	print("--- Starting Test ---")

	var gm_script = load("res://src/Autoload/GameManager.gd")
	var gm = gm_script.new()
	root.add_child(gm)
	gm.name = "GameManager"

	call_deferred("_run_test")

func _run_test():
	var gm = root.get_node("GameManager")
	var rm = gm.reward_manager
	if rm == null:
		print("FAILED: RewardManager is null!")
		quit()
		return

	# Check starting health
	var initial_max = gm.max_core_health
	var initial_cur = gm.core_health
	print("Initial max core health: ", initial_max)
	print("Initial core health: ", initial_cur)

	# Try to add life_core
	rm.add_reward("life_core")

	# Check ending health
	print("New max core health: ", gm.max_core_health)
	print("New core health: ", gm.core_health)

	if gm.max_core_health == initial_max + 200.0 and gm.core_health == initial_cur + 200.0:
		print("SUCCESS: life_core effect correctly applied.")
	else:
		print("FAILED: life_core effect was not correctly applied.")

	quit()
