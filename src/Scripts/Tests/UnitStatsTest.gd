extends Node

const UnitStatsClass = preload("res://src/Scripts/Components/UnitStats.gd")
const StatModifierClass = preload("res://src/Scripts/Components/StatModifier.gd")

func _ready() -> void:
	print("=== Running UnitStatsTest ===")
	var passed_all = true

	passed_all = passed_all and test_attack_speed_duration()
	passed_all = passed_all and test_same_source_refresh()
	passed_all = passed_all and test_mixed_modifiers()
	passed_all = passed_all and test_hp_logic()
	passed_all = passed_all and test_floating_point_precision()

	if passed_all:
		print("All UnitStats tests passed! 100% green.")
		get_tree().quit(0)
	else:
		print("Some UnitStats tests failed.")
		get_tree().quit(1)

func test_attack_speed_duration() -> bool:
	var stats = UnitStatsClass.new()
	stats.set_base_stat("atk_speed", 1.0)

	# Add a 5.0 second duration modifier (+0.5 flat)
	var mod = StatModifierClass.new(StatModifierClass.Type.FLAT, 0.5, 5.0, "buff_1")
	stats.add_modifier("atk_speed", mod)

	if not is_equal_approx(stats.get_stat("atk_speed"), 1.5):
		print("Failed test_attack_speed_duration: Initial value incorrect")
		return false

	# Simulate 2.0s
	stats._process(2.0)
	if not is_equal_approx(stats.get_stat("atk_speed"), 1.5):
		print("Failed test_attack_speed_duration: Value incorrect after 2.0s")
		return false

	# Simulate remaining 3.0s
	stats._process(3.0)
	if not is_equal_approx(stats.get_stat("atk_speed"), 1.0):
		print("Failed test_attack_speed_duration: Value did not revert to base correctly after duration")
		return false

	print("Passed test_attack_speed_duration")
	return true

func test_same_source_refresh() -> bool:
	var stats = UnitStatsClass.new()
	stats.set_base_stat("damage", 10.0)

	# Add a modifier
	var mod1 = StatModifierClass.new(StatModifierClass.Type.FLAT, 5.0, 5.0, "source_A")
	stats.add_modifier("damage", mod1)

	stats._process(3.0) # 2.0s remaining

	# Add another modifier from same source
	var mod2 = StatModifierClass.new(StatModifierClass.Type.FLAT, 5.0, 5.0, "source_A")
	stats.add_modifier("damage", mod2)

	if not is_equal_approx(stats.get_stat("damage"), 15.0):
		print("Failed test_same_source_refresh: Value stacked when it should have refreshed")
		return false

	# Wait 3.0s. If it didn't refresh, the modifier would expire (2.0s left from old one).
	stats._process(3.0)

	if not is_equal_approx(stats.get_stat("damage"), 15.0):
		print("Failed test_same_source_refresh: Modifier expired early, didn't refresh duration")
		return false

	# Wait remaining 2.0s
	stats._process(2.0)

	if not is_equal_approx(stats.get_stat("damage"), 10.0):
		print("Failed test_same_source_refresh: Modifier did not expire")
		return false

	print("Passed test_same_source_refresh")
	return true

func test_mixed_modifiers() -> bool:
	var stats = UnitStatsClass.new()
	stats.set_base_stat("attack", 20.0)

	# Base 20
	# Flat +10 = 30
	# Percent +50% (0.5) -> Final = 30 * (1 + 0.5) = 45

	var mod_flat = StatModifierClass.new(StatModifierClass.Type.FLAT, 10.0, 0.0, "flat_1")
	var mod_pct = StatModifierClass.new(StatModifierClass.Type.PERCENT, 0.5, 0.0, "pct_1")

	stats.add_modifier("attack", mod_flat)
	stats.add_modifier("attack", mod_pct)

	if not is_equal_approx(stats.get_stat("attack"), 45.0):
		print("Failed test_mixed_modifiers: Expected 45.0, got ", stats.get_stat("attack"))
		return false

	# Adding negative percent
	# Flat +10 = 30
	# Percent +50% - 20% = +30% -> Final = 30 * 1.3 = 39
	var mod_pct_neg = StatModifierClass.new(StatModifierClass.Type.PERCENT, -0.2, 0.0, "pct_2")
	stats.add_modifier("attack", mod_pct_neg)

	if not is_equal_approx(stats.get_stat("attack"), 39.0):
		print("Failed test_mixed_modifiers: Expected 39.0, got ", stats.get_stat("attack"))
		return false

	print("Passed test_mixed_modifiers")
	return true

var death_signaled = false
func _on_unit_death():
	death_signaled = true

func test_hp_logic() -> bool:
	death_signaled = false
	var stats = UnitStatsClass.new()
	stats.set_base_stat("hp", 100.0)

	stats.on_death.connect(_on_unit_death)

	stats.take_damage(30.0)
	if not is_equal_approx(stats.get_stat("hp"), 70.0):
		print("Failed test_hp_logic: Expected 70.0 hp")
		return false

	if death_signaled:
		print("Failed test_hp_logic: Death signaled prematurely")
		return false

	# Fatal damage
	stats.take_damage(100.0)
	if not is_equal_approx(stats.get_stat("hp"), 0.0):
		print("Failed test_hp_logic: HP not capped at 0")
		return false

	if not death_signaled:
		print("Failed test_hp_logic: Death signal not emitted")
		return false

	print("Passed test_hp_logic")
	return true

func test_floating_point_precision() -> bool:
	var stats = UnitStatsClass.new()
	stats.set_base_stat("magic", 100.0)

	for i in range(100):
		# Add buff
		var mod = StatModifierClass.new(StatModifierClass.Type.PERCENT, 0.333333, 1.0, "prec")
		stats.add_modifier("magic", mod)
		stats.get_stat("magic")
		# Expire buff
		stats._process(1.5)

	var final_val = stats.get_stat("magic")
	if not is_equal_approx(final_val, 100.0):
		print("Failed test_floating_point_precision: Value is ", final_val)
		return false

	print("Passed test_floating_point_precision")
	return true
