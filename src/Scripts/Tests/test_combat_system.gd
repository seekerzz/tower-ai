extends SceneTree

var stats
var combat
var mock_unit
var mock_target

func _init():
	print("--- Running Test: Combat System ---")

	mock_unit = Node2D.new()
	mock_unit.name = "MockUnit"

	mock_target = Node2D.new()
	mock_target.name = "MockTarget"

	var StatsClass = load("res://src/Scripts/Units/Components/UnitStats.gd")
	if not StatsClass:
		print("FAILED: Could not load UnitStats.gd")
		quit(1)
		return
	stats = StatsClass.new()
	stats.unit = mock_unit

	var CombatClass = load("res://src/Scripts/Units/Components/CombatController.gd")
	if not CombatClass:
		print("FAILED: Could not load CombatController.gd")
		quit(1)
		return
	combat = CombatClass.new()
	combat.unit = mock_unit

	test_stats_deduction()
	test_stats_healing()
	test_attack_triggering()

	print("--- All Combat System Tests Passed ---")
	quit(0)

func test_stats_deduction():
	stats.max_hp = 100
	stats.current_hp = 100
	stats.take_damage(20)
	assert(stats.current_hp == 80, "HP should be 80 after 20 damage")

func test_stats_healing():
	stats.max_hp = 100
	stats.current_hp = 50
	stats.heal(30)
	assert(stats.current_hp == 80, "HP should be 80 after 30 healing")
	stats.heal(50)
	assert(stats.current_hp == 100, "HP should cap at 100 after 50 healing")

func test_attack_triggering():
	# Mocking attack call
	# Currently it might just fail because _do_melee_attack is not implemented or combat_manager is missing
	combat._do_melee_attack(mock_target)
	combat._do_standard_ranged_attack(mock_target)
