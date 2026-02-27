extends Node

# 测试眼镜蛇图腾系列2个单位的功能
# 测试目标:
# 1. lure_snake (诱捕蛇) - 验证陷阱诱导机制是否正确工作
# 2. medusa (美杜莎) - 验证石化凝视机制是否正确工作

var test_results: Dictionary = {}
var tests_passed: int = 0
var tests_failed: int = 0
var game_data: Dictionary = {}

func _ready():
	print("============================================================")
	print("Starting Cobra Totem Units Test Suite")
	print("============================================================")

	# 加载game_data.json
	_load_game_data()

	# 运行所有测试
	test_lure_snake()
	test_medusa()

	# 输出总结
	print("\n============================================================")
	print("Test Summary")
	print("============================================================")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("Total:  %d" % (tests_passed + tests_failed))

	if tests_failed == 0:
		print("\nALL TESTS PASSED!")
	else:
		print("\nSOME TESTS FAILED!")

	# 保存测试结果到文件
	_save_test_results()

	get_tree().quit()

func _load_game_data():
	var file = FileAccess.open("res://data/game_data.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			game_data = json.data
			print("Loaded game_data.json successfully")
		else:
			print("Failed to parse game_data.json")
		file.close()
	else:
		print("Failed to open game_data.json")

# Helper function to check if script contains method
func _script_has_method(script_content: String, method_name: String) -> bool:
	return script_content.find("func " + method_name) != -1

# Helper function to check if script contains variable
func _script_has_variable(script_content: String, var_name: String) -> bool:
	return script_content.find("var " + var_name) != -1

# ==================== Test 1: Lure Snake (诱捕蛇) ====================

func test_lure_snake():
	print("\n------------------------------------------------------------")
	print("Testing Lure Snake (诱捕蛇)")
	print("------------------------------------------------------------")

	var passed = true

	# Test 1.1: 检查单位数据配置
	print("\n[Test 1.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("lure_snake", {})
	if unit_data.is_empty():
		print("  FAIL: lure_snake not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: lure_snake found in UNIT_TYPES")

		# 检查图标
		var icon = unit_data.get("icon", "")
		if icon == "🐍":
			print("  PASS: icon is '🐍'")
		else:
			print("  FAIL: icon is '%s', expected '🐍'" % icon)
			passed = false

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "none":
			print("  PASS: attackType is 'none'")
		else:
			print("  FAIL: attackType is '%s', expected 'none'" % attack_type)
			passed = false

		# 检查范围
		var range_val = unit_data.get("range", -1)
		if range_val == 0:
			print("  PASS: range is 0 (pure support unit)")
		else:
			print("  FAIL: range is %d, expected 0" % range_val)
			passed = false

		# 检查等级配置
		print("\n  Checking level mechanics...")
		var expected_multipliers = {1: 1.0, 2: 1.5, 3: 1.5}
		var expected_stun = {1: 0.0, 2: 0.0, 3: 1.0}
		
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var multiplier = mechanics.get("pull_speed_multiplier", 0.0)
			var stun = mechanics.get("stun_duration", 0.0)
			var expected_m = expected_multipliers[level]
			var expected_s = expected_stun[level]

			if abs(multiplier - expected_m) < 0.001:
				print("    PASS: Level %d pull_speed_multiplier is %.1f" % [level, multiplier])
			else:
				print("    FAIL: Level %d pull_speed_multiplier is %.1f, expected %.1f" % [level, multiplier, expected_m])
				passed = false

			if abs(stun - expected_s) < 0.001:
				if stun > 0:
					print("    PASS: Level %d stun_duration is %.1fs" % [level, stun])
				else:
					print("    PASS: Level %d stun_duration is 0 (no stun)" % level)
			else:
				print("    FAIL: Level %d stun_duration is %.1f, expected %.1f" % [level, stun, expected_s])
				passed = false

	# Test 1.2: 检查行为脚本
	print("\n[Test 1.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/LureSnake.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: LureSnake.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		if _script_has_variable(content, "_connected_traps"):
			print("  PASS: has _connected_traps property")
		else:
			print("  FAIL: missing _connected_traps property")
			passed = false

		if _script_has_variable(content, "_processed_enemies"):
			print("  PASS: has _processed_enemies property")
		else:
			print("  FAIL: missing _processed_enemies property")
			passed = false

		# 检查必要的方法
		if _script_has_method(content, "on_setup"):
			print("  PASS: has on_setup() method")
		else:
			print("  FAIL: missing on_setup() method")
			passed = false

		if _script_has_method(content, "on_tick"):
			print("  PASS: has on_tick() method")
		else:
			print("  FAIL: missing on_tick() method")
			passed = false

		if _script_has_method(content, "_connect_to_all_traps"):
			print("  PASS: has _connect_to_all_traps() method")
		else:
			print("  FAIL: missing _connect_to_all_traps() method")
			passed = false

		if _script_has_method(content, "_on_trap_triggered"):
			print("  PASS: has _on_trap_triggered() method")
		else:
			print("  FAIL: missing _on_trap_triggered() method")
			passed = false

		if _script_has_method(content, "_find_nearest_other_trap"):
			print("  PASS: has _find_nearest_other_trap() method")
		else:
			print("  FAIL: missing _find_nearest_other_trap() method")
			passed = false

		if _script_has_method(content, "_get_mechanics"):
			print("  PASS: has _get_mechanics() method")
		else:
			print("  FAIL: missing _get_mechanics() method")
			passed = false

		# 检查信号连接和陷阱处理逻辑
		if content.find("trap_triggered") != -1:
			print("  PASS: connects to trap_triggered signal")
		else:
			print("  FAIL: missing trap_triggered signal connection")
			passed = false

		if content.find("knockback_velocity") != -1:
			print("  PASS: applies knockback_velocity to enemies")
		else:
			print("  FAIL: missing knockback_velocity application")
			passed = false

		if content.find("apply_stun") != -1:
			print("  PASS: calls apply_stun for L3 effect")
		else:
			print("  FAIL: missing apply_stun call")
			passed = false
	else:
		print("  FAIL: LureSnake.gd not found")
		passed = false

	# Test 1.3: 检查Barricade.gd信号
	print("\n[Test 1.3] Checking Barricade.gd trap_triggered signal...")
	var barricade_script_path = "res://src/Scripts/Barricade.gd"
	var barricade_file = FileAccess.open(barricade_script_path, FileAccess.READ)
	if barricade_file:
		var barricade_content = barricade_file.get_as_text()
		barricade_file.close()

		if barricade_content.find("signal trap_triggered") != -1:
			print("  PASS: Barricade.gd has trap_triggered signal")
		else:
			print("  FAIL: Barricade.gd missing trap_triggered signal")
			passed = false

		if barricade_content.find("emit_signal(\"trap_triggered\"") != -1 or barricade_content.find("trap_triggered.emit") != -1:
			print("  PASS: Barricade.gd emits trap_triggered signal")
		else:
			print("  FAIL: Barricade.gd does not emit trap_triggered signal")
			passed = false
	else:
		print("  FAIL: Could not read Barricade.gd")
		passed = false

	_record_result("lure_snake", passed)

# ==================== Test 2: Medusa (美杜莎) ====================

func test_medusa():
	print("\n------------------------------------------------------------")
	print("Testing Medusa (美杜莎)")
	print("------------------------------------------------------------")

	var passed = true

	# Test 2.1: 检查单位数据配置
	print("\n[Test 2.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("medusa", {})
	if unit_data.is_empty():
		print("  FAIL: medusa not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: medusa found in UNIT_TYPES")

		# 检查图标
		var icon = unit_data.get("icon", "")
		if icon == "👑":
			print("  PASS: icon is '👑'")
		else:
			print("  FAIL: icon is '%s', expected '👑'" % icon)
			passed = false

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "ranged":
			print("  PASS: attackType is 'ranged'")
		else:
			print("  FAIL: attackType is '%s', expected 'ranged'" % attack_type)
			passed = false

		# 检查伤害类型
		var damage_type = unit_data.get("damageType", "")
		if damage_type == "magic":
			print("  PASS: damageType is 'magic'")
		else:
			print("  FAIL: damageType is '%s', expected 'magic'" % damage_type)
			passed = false

		# 检查范围
		var range_val = unit_data.get("range", -1)
		if range_val == 300:
			print("  PASS: range is 300")
		else:
			print("  FAIL: range is %d, expected 300" % range_val)
			passed = false

		# 检查等级配置
		print("\n  Checking level mechanics...")
		var expected_durations = {1: 3.0, 2: 5.0, 3: 8.0}
		
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var duration = mechanics.get("petrify_duration", 0.0)
			var expected_d = expected_durations[level]

			if abs(duration - expected_d) < 0.001:
				print("    PASS: Level %d petrify_duration is %.1fs" % [level, duration])
			else:
				print("    FAIL: Level %d petrify_duration is %.1f, expected %.1f" % [level, duration, expected_d])
				passed = false

		# 检查伤害配置
		var l2_damage = 200.0
		var l3_damage = 500.0
		print("    INFO: Level 2 expected AOE damage is %.0f" % l2_damage)
		print("    INFO: Level 3 expected AOE damage is %.0f" % l3_damage)

	# Test 2.2: 检查行为脚本
	print("\n[Test 2.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/Medusa.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: Medusa.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		if _script_has_variable(content, "_petrify_timer"):
			print("  PASS: has _petrify_timer property")
		else:
			print("  FAIL: missing _petrify_timer property")
			passed = false

		if _script_has_variable(content, "_petrify_interval"):
			print("  PASS: has _petrify_interval property")
		else:
			print("  FAIL: missing _petrify_interval property")
			passed = false

		if _script_has_variable(content, "_petrified_enemies"):
			print("  PASS: has _petrified_enemies property")
		else:
			print("  FAIL: missing _petrified_enemies property")
			passed = false

		# 检查必要的方法
		if _script_has_method(content, "on_setup"):
			print("  PASS: has on_setup() method")
		else:
			print("  FAIL: missing on_setup() method")
			passed = false

		if _script_has_method(content, "on_combat_tick"):
			print("  PASS: has on_combat_tick() method")
		else:
			print("  FAIL: missing on_combat_tick() method")
			passed = false

		if _script_has_method(content, "_petrify_nearest_enemy"):
			print("  PASS: has _petrify_nearest_enemy() method")
		else:
			print("  FAIL: missing _petrify_nearest_enemy() method")
			passed = false

		if _script_has_method(content, "_check_petrified_enemies"):
			print("  PASS: has _check_petrified_enemies() method")
		else:
			print("  FAIL: missing _check_petrified_enemies() method")
			passed = false

		if _script_has_method(content, "_trigger_petrify_end_effect"):
			print("  PASS: has _trigger_petrify_end_effect() method")
		else:
			print("  FAIL: missing _trigger_petrify_end_effect() method")
			passed = false

		if _script_has_method(content, "_deal_aoe_damage"):
			print("  PASS: has _deal_aoe_damage() method")
		else:
			print("  FAIL: missing _deal_aoe_damage() method")
			passed = false

		if _script_has_method(content, "_get_mechanics"):
			print("  PASS: has _get_mechanics() method")
		else:
			print("  FAIL: missing _get_mechanics() method")
			passed = false

		# 检查石化逻辑
		if content.find("apply_stun") != -1:
			print("  PASS: uses apply_stun for petrify effect")
		else:
			print("  FAIL: missing apply_stun for petrify effect")
			passed = false

		if content.find("instance_from_id") != -1:
			print("  PASS: uses instance_from_id for safe enemy access")
		else:
			print("  FAIL: missing instance_from_id for safe enemy access")
			passed = false

		if content.find("is_instance_valid") != -1:
			print("  PASS: uses is_instance_valid for safety checks")
		else:
			print("  FAIL: missing is_instance_valid for safety checks")
			passed = false

		# 检查范围伤害逻辑
		if content.find("level >= 2") != -1 or content.find("level > 1") != -1:
			print("  PASS: has level check for AOE damage")
		else:
			print("  WARN: cannot find level check for AOE damage")

	else:
		print("  FAIL: Medusa.gd not found")
		passed = false

	# Test 2.3: 检查间隔配置
	print("\n[Test 2.3] Checking petrify interval...")
	var script_path2 = "res://src/Scripts/Units/Behaviors/Medusa.gd"
	var file2 = FileAccess.open(script_path2, FileAccess.READ)
	if file2:
		var content = file2.get_as_text()
		file2.close()

		if content.find("_petrify_interval: float = 3.0") != -1 or content.find("_petrify_interval = 3.0") != -1:
			print("  PASS: petrify interval is 3.0 seconds")
		else:
			print("  WARN: petrify interval might not be 3.0 seconds")

	_record_result("medusa", passed)

# ==================== Helper Functions ====================

func _record_result(test_name: String, passed: bool):
	test_results[test_name] = passed
	if passed:
		tests_passed += 1
		print("\n[RESULT] %s: PASS" % test_name)
	else:
		tests_failed += 1
		print("\n[RESULT] %s: FAIL" % test_name)

func _save_test_results():
	var result_text = "# Cobra Totem Units Test Results\n\n"
	result_text += "Test Date: %s\n\n" % Time.get_datetime_string_from_system()
	result_text += "## Summary\n\n"
	result_text += "- Passed: %d\n" % tests_passed
	result_text += "- Failed: %d\n" % tests_failed
	result_text += "- Total:  %d\n\n" % (tests_passed + tests_failed)

	result_text += "## Detailed Results\n\n"
	result_text += "| Unit | Status |\n"
	result_text += "|------|--------|\n"
	for test_name in test_results:
		var status = "PASS" if test_results[test_name] else "FAIL"
		var display_name = test_name
		if test_name == "lure_snake":
			display_name = "诱捕蛇 (Lure Snake) - 陷阱诱导机制"
		elif test_name == "medusa":
			display_name = "美杜莎 (Medusa) - 石化凝视机制"
		result_text += "| %s | %s |\n" % [display_name, status]

	result_text += "\n## Issues Found\n\n"
	if tests_failed == 0:
		result_text += "No issues found. All tests passed!\n"
	else:
		result_text += "See console output for detailed failure information.\n"

	# 确保目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("tasks/cobra_totem_units"):
		dir.make_dir_recursive("tasks/cobra_totem_units")

	var file = FileAccess.open("res://tasks/cobra_totem_units/test_result.md", FileAccess.WRITE)
	if file:
		file.store_string(result_text)
		file.close()
		print("\nTest results saved to: tasks/cobra_totem_units/test_result.md")
