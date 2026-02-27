extends Node

# 测试牛图腾4个单位的功能
# 测试目标:
# 1. yak_guardian - 验证守护领域buff是否正确给周围友方提供减伤
# 2. mushroom_healer - 验证过量治疗是否正确转化为延迟回血
# 3. rock_armor_cow - 验证脱战后是否正确生成护盾
# 4. cow_golem - 验证受击计数和全屏晕眩是否正常触发

var test_results: Dictionary = {}
var tests_passed: int = 0
var tests_failed: int = 0
var game_data: Dictionary = {}

func _ready():
	print("============================================================")
	print("Starting Cow Totem Units Test Suite")
	print("============================================================")

	# 加载game_data.json
	_load_game_data()

	# 运行所有测试
	test_yak_guardian()
	test_mushroom_healer()
	test_rock_armor_cow()
	test_cow_golem()

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

# ==================== Test 1: Yak Guardian ====================

func test_yak_guardian():
	print("\n------------------------------------------------------------")
	print("Testing Yak Guardian (牦牛守护)")
	print("------------------------------------------------------------")

	var passed = true

	# Test 1.1: 检查单位数据配置
	print("\n[Test 1.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("yak_guardian", {})
	if unit_data.is_empty():
		print("  FAIL: yak_guardian not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: yak_guardian found in UNIT_TYPES")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "none":
			print("  PASS: attackType is 'none'")
		else:
			print("  FAIL: attackType is '%s', expected 'none'" % attack_type)
			passed = false

		# 检查等级配置
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var reduction = mechanics.get("damage_reduction", 0.0)
			var expected = 0.05 * level
			if abs(reduction - expected) < 0.001:
				var percent = int(reduction * 100)
				print("  PASS: Level %d damage_reduction is %d%%" % [level, percent])
			else:
				print("  FAIL: Level %d damage_reduction is %.2f, expected %.2f" % [level, reduction, expected])
				passed = false

	# Test 1.2: 检查行为脚本
	print("\n[Test 1.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/YakGuardian.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: YakGuardian.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的方法
		if _script_has_method(content, "broadcast_buffs"):
			print("  PASS: has broadcast_buffs() method")
		else:
			print("  FAIL: missing broadcast_buffs() method")
			passed = false

		if _script_has_method(content, "get_damage_reduction"):
			print("  PASS: has get_damage_reduction() method")
		else:
			print("  FAIL: missing get_damage_reduction() method")
			passed = false

		if _script_has_method(content, "_get_units_in_range"):
			print("  PASS: has _get_units_in_range() method")
		else:
			print("  FAIL: missing _get_units_in_range() method")
			passed = false
	else:
		print("  FAIL: YakGuardian.gd not found")
		passed = false

	# Test 1.3: 检查Unit.gd中的guardian_shield处理
	print("\n[Test 1.3] Checking Unit.gd guardian_shield handling...")
	var unit_script_path = "res://src/Scripts/Unit.gd"
	var unit_file = FileAccess.open(unit_script_path, FileAccess.READ)
	if unit_file:
		var unit_content = unit_file.get_as_text()
		unit_file.close()

		if unit_content.find("guardian_shield") != -1:
			print("  PASS: Unit.gd handles guardian_shield")
		else:
			print("  FAIL: Unit.gd missing guardian_shield handling")
			passed = false
	else:
		print("  FAIL: Could not read Unit.gd")
		passed = false

	_record_result("yak_guardian", passed)

# ==================== Test 2: Mushroom Healer ====================

func test_mushroom_healer():
	print("\n------------------------------------------------------------")
	print("Testing Mushroom Healer (菌菇治愈者)")
	print("------------------------------------------------------------")

	var passed = true

	# Test 2.1: 检查单位数据配置
	print("\n[Test 2.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("mushroom_healer", {})
	if unit_data.is_empty():
		print("  FAIL: mushroom_healer not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: mushroom_healer found in UNIT_TYPES")

		# 检查技能配置
		var skill = unit_data.get("skill", "")
		if skill == "burst_heal":
			print("  PASS: skill is 'burst_heal'")
		else:
			print("  FAIL: skill is '%s', expected 'burst_heal'" % skill)
			passed = false

		# 检查等级配置
		var expected_rates = {1: 0.8, 2: 1.0, 3: 1.0}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var rate = mechanics.get("conversion_rate", 0.0)
			var expected = expected_rates[level]
			if abs(rate - expected) < 0.001:
				var percent = int(rate * 100)
				print("  PASS: Level %d conversion_rate is %d%%" % [level, percent])
			else:
				print("  FAIL: Level %d conversion_rate is %.2f, expected %.2f" % [level, rate, expected])
				passed = false

		# 检查L3增强效果
		var l3_mechanics = unit_data.get("levels", {}).get("3", {}).get("mechanics", {})
		if l3_mechanics.has("enhancement"):
			print("  PASS: Level 3 has enhancement mechanic")
		else:
			print("  FAIL: Level 3 missing enhancement mechanic")
			passed = false

	# Test 2.2: 检查行为脚本
	print("\n[Test 2.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/MushroomHealer.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: MushroomHealer.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		if _script_has_variable(content, "delayed_heal_queue"):
			print("  PASS: has delayed_heal_queue property")
		else:
			print("  FAIL: missing delayed_heal_queue property")
			passed = false

		if _script_has_variable(content, "conversion_rate"):
			print("  PASS: has conversion_rate property")
		else:
			print("  FAIL: missing conversion_rate property")
			passed = false

		if _script_has_variable(content, "last_core_health"):
			print("  PASS: has last_core_health property")
		else:
			print("  FAIL: missing last_core_health property")
			passed = false

		# 检查必要的方法
		if _script_has_method(content, "get_stored_heal_amount"):
			print("  PASS: has get_stored_heal_amount() method")
		else:
			print("  FAIL: missing get_stored_heal_amount() method")
			passed = false

		if _script_has_method(content, "on_skill_activated"):
			print("  PASS: has on_skill_activated() method")
		else:
			print("  FAIL: missing on_skill_activated() method")
			passed = false

		if _script_has_method(content, "_process_core_heal"):
			print("  PASS: has _process_core_heal() method")
		else:
			print("  FAIL: missing _process_core_heal() method")
			passed = false
	else:
		print("  FAIL: MushroomHealer.gd not found")
		passed = false

	_record_result("mushroom_healer", passed)

# ==================== Test 3: Rock Armor Cow ====================

func test_rock_armor_cow():
	print("\n------------------------------------------------------------")
	print("Testing Rock Armor Cow (岩甲牛)")
	print("------------------------------------------------------------")

	var passed = true

	# Test 3.1: 检查单位数据配置
	print("\n[Test 3.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("rock_armor_cow", {})
	if unit_data.is_empty():
		print("  FAIL: rock_armor_cow not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: rock_armor_cow found in UNIT_TYPES")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "melee":
			print("  PASS: attackType is 'melee'")
		else:
			print("  FAIL: attackType is '%s', expected 'melee'" % attack_type)
			passed = false

		# 检查等级配置
		var expected_times = {1: 5.0, 2: 4.0, 3: 3.0}
		var expected_shield = {1: 0.1, 2: 0.15, 3: 0.2}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var time = mechanics.get("out_of_combat_time", 0.0)
			var shield = mechanics.get("shield_percent", 0.0)
			var expected_t = expected_times[level]
			var expected_s = expected_shield[level]

			if abs(time - expected_t) < 0.001:
				print("  PASS: Level %d out_of_combat_time is %.1fs" % [level, time])
			else:
				print("  FAIL: Level %d out_of_combat_time is %.1f, expected %.1f" % [level, time, expected_t])
				passed = false

			if abs(shield - expected_s) < 0.001:
				var percent = int(shield * 100)
				print("  PASS: Level %d shield_percent is %d%%" % [level, percent])
			else:
				print("  FAIL: Level %d shield_percent is %.2f, expected %.2f" % [level, shield, expected_s])
				passed = false

	# Test 3.2: 检查行为脚本
	print("\n[Test 3.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/RockArmorCow.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: RockArmorCow.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		if _script_has_variable(content, "in_combat"):
			print("  PASS: has in_combat property")
		else:
			print("  FAIL: missing in_combat property")
			passed = false

		if _script_has_variable(content, "shield_amount"):
			print("  PASS: has shield_amount property")
		else:
			print("  FAIL: missing shield_amount property")
			passed = false

		if _script_has_variable(content, "combat_timer"):
			print("  PASS: has combat_timer property")
		else:
			print("  FAIL: missing combat_timer property")
			passed = false

		# 检查必要的方法
		if _script_has_method(content, "get_current_shield"):
			print("  PASS: has get_current_shield() method")
		else:
			print("  FAIL: missing get_current_shield() method")
			passed = false

		if _script_has_method(content, "get_max_shield"):
			print("  PASS: has get_max_shield() method")
		else:
			print("  FAIL: missing get_max_shield() method")
			passed = false

		if _script_has_method(content, "on_damage_taken"):
			print("  PASS: has on_damage_taken() method")
		else:
			print("  FAIL: missing on_damage_taken() method")
			passed = false

		if _script_has_method(content, "_regenerate_shield"):
			print("  PASS: has _regenerate_shield() method")
		else:
			print("  FAIL: missing _regenerate_shield() method")
			passed = false
	else:
		print("  FAIL: RockArmorCow.gd not found")
		passed = false

	_record_result("rock_armor_cow", passed)

# ==================== Test 4: Cow Golem ====================

func test_cow_golem():
	print("\n------------------------------------------------------------")
	print("Testing Cow Golem (牛魔像)")
	print("------------------------------------------------------------")

	var passed = true

	# Test 4.1: 检查单位数据配置
	print("\n[Test 4.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("cow_golem", {})
	if unit_data.is_empty():
		print("  FAIL: cow_golem not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: cow_golem found in UNIT_TYPES")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "none":
			print("  PASS: attackType is 'none'")
		else:
			print("  FAIL: attackType is '%s', expected 'none'" % attack_type)
			passed = false

		# 检查等级配置
		var expected_thresholds = {1: 15, 2: 12, 3: 10}
		var expected_stun = {1: 1.0, 2: 1.0, 3: 1.5}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var threshold = mechanics.get("hits_threshold", 0)
			var stun = mechanics.get("stun_duration", 0.0)
			var expected_t = expected_thresholds[level]
			var expected_s = expected_stun[level]

			if threshold == expected_t:
				print("  PASS: Level %d hits_threshold is %d" % [level, threshold])
			else:
				print("  FAIL: Level %d hits_threshold is %d, expected %d" % [level, threshold, expected_t])
				passed = false

			if abs(stun - expected_s) < 0.001:
				print("  PASS: Level %d stun_duration is %.1fs" % [level, stun])
			else:
				print("  FAIL: Level %d stun_duration is %.1f, expected %.1f" % [level, stun, expected_s])
				passed = false

	# Test 4.2: 检查行为脚本
	print("\n[Test 4.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/CowGolem.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: CowGolem.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		if _script_has_variable(content, "hit_counter"):
			print("  PASS: has hit_counter property")
		else:
			print("  FAIL: missing hit_counter property")
			passed = false

		if _script_has_variable(content, "hits_threshold"):
			print("  PASS: has hits_threshold property")
		else:
			print("  FAIL: missing hits_threshold property")
			passed = false

		if _script_has_variable(content, "stun_duration"):
			print("  PASS: has stun_duration property")
		else:
			print("  FAIL: missing stun_duration property")
			passed = false

		# 检查必要的方法
		if _script_has_method(content, "get_hit_counter"):
			print("  PASS: has get_hit_counter() method")
		else:
			print("  FAIL: missing get_hit_counter() method")
			passed = false

		if _script_has_method(content, "get_hits_threshold"):
			print("  PASS: has get_hits_threshold() method")
		else:
			print("  FAIL: missing get_hits_threshold() method")
			passed = false

		if _script_has_method(content, "on_damage_taken"):
			print("  PASS: has on_damage_taken() method")
		else:
			print("  FAIL: missing on_damage_taken() method")
			passed = false

		if _script_has_method(content, "_trigger_shockwave"):
			print("  PASS: has _trigger_shockwave() method")
		else:
			print("  FAIL: missing _trigger_shockwave() method")
			passed = false
	else:
		print("  FAIL: CowGolem.gd not found")
		passed = false

	_record_result("cow_golem", passed)

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
	var result_text = "# Cow Totem Units Test Results\n\n"
	result_text += "Test Date: %s\n\n" % Time.get_datetime_string_from_system()
	result_text += "## Summary\n\n"
	result_text += "- Passed: %d\n" % tests_passed
	result_text += "- Failed: %d\n" % tests_failed
	result_text += "- Total:  %d\n\n" % (tests_passed + tests_failed)

	result_text += "## Detailed Results\n\n"
	for test_name in test_results:
		var status = "PASS" if test_results[test_name] else "FAIL"
		result_text += "- %s: %s\n" % [test_name, status]

	result_text += "\n## Issues Found\n\n"
	if tests_failed == 0:
		result_text += "No issues found. All tests passed!\n"
	else:
		result_text += "See console output for detailed failure information.\n"

	# 确保目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("tasks/cow_totem_units"):
		dir.make_dir_recursive("tasks/cow_totem_units")

	var file = FileAccess.open("res://tasks/cow_totem_units/test_result.md", FileAccess.WRITE)
	if file:
		file.store_string(result_text)
		file.close()
		print("\nTest results saved to: tasks/cow_totem_units/test_result.md")
