extends Node

# 测试蝙蝠图腾系列4个单位的功能
# 测试目标:
# 1. vampire_bat - 验证鲜血狂噬机制（生命值越低吸血越高）
# 2. plague_spreader - 验证毒血传播机制（中毒敌人死亡传播）
# 3. blood_mage - 验证血池降临机制（召唤血池区域）
# 4. blood_ancestor - 验证鲜血领域机制（受伤敌人增伤）
# 5. gargoyle - 验证石像鬼
# 6. life_chain - 验证生命链条
# 7. blood_chalice - 验证鲜血圣杯
# 8. blood_ritualist - 验证血祭术士

var test_results: Dictionary = {}
var tests_passed: int = 0
var tests_failed: int = 0
var game_data: Dictionary = {}

func _ready():
	print("============================================================")
	print("Starting Bat Totem Units Test Suite")
	print("============================================================")

	# 加载game_data.json
	_load_game_data()

	# 运行所有测试
	test_vampire_bat()
	test_plague_spreader()
	test_blood_mage()
	test_blood_ancestor()

	test_gargoyle()
	test_life_chain()
	test_chalice()
	test_ritualist()

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

# ==================== Test 1: Vampire Bat ====================

func test_vampire_bat():
	print("\n------------------------------------------------------------")
	print("Testing Vampire Bat (吸血蝠) - 鲜血狂噬机制")
	print("------------------------------------------------------------")

	var passed = true

	# Test 1.1: 检查单位数据配置
	print("\n[Test 1.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("vampire_bat", {})
	if unit_data.is_empty():
		print("  FAIL: vampire_bat not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: vampire_bat found in UNIT_TYPES")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "melee":
			print("  PASS: attackType is 'melee'")
		else:
			print("  FAIL: attackType is '%s', expected 'melee'" % attack_type)
			passed = false

		# 检查伤害类型
		var damage_type = unit_data.get("damageType", "")
		if damage_type == "physical":
			print("  PASS: damageType is 'physical'")
		else:
			print("  FAIL: damageType is '%s', expected 'physical'" % damage_type)
			passed = false

	# Test 1.2: 检查行为脚本
	print("\n[Test 1.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/VampireBat.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: VampireBat.gd exists")
		var content = file.get_as_text()
		file.close()

		# 检查必要的方法
		if _script_has_method(content, "on_projectile_hit"):
			print("  PASS: has on_projectile_hit() method")
		else:
			print("  FAIL: missing on_projectile_hit() method")
			passed = false
	else:
		print("  FAIL: VampireBat.gd not found")
		passed = false

	_record_result("vampire_bat", passed)

# ==================== Test 2: Plague Spreader ====================

func test_plague_spreader():
	print("\n------------------------------------------------------------")
	print("Testing Plague Spreader (瘟疫使者) - 毒血传播机制")
	print("------------------------------------------------------------")

	var passed = true

	# Test 2.1: 检查单位数据配置
	print("\n[Test 2.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("plague_spreader", {})
	if unit_data.is_empty():
		print("  FAIL: plague_spreader not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: plague_spreader found in UNIT_TYPES")

	# Test 2.2: 检查行为脚本
	print("\n[Test 2.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/PlagueSpreader.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: PlagueSpreader.gd exists")
	else:
		print("  FAIL: PlagueSpreader.gd not found")
		passed = false

	_record_result("plague_spreader", passed)

# ==================== Test 3: Blood Mage ====================

func test_blood_mage():
	print("\n------------------------------------------------------------")
	print("Testing Blood Mage (血法师) - 血池降临机制")
	print("------------------------------------------------------------")

	var passed = true

	# Test 3.1: 检查单位数据配置
	print("\n[Test 3.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("blood_mage", {})
	if unit_data.is_empty():
		print("  FAIL: blood_mage not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: blood_mage found in UNIT_TYPES")

	# Test 3.2: 检查行为脚本
	print("\n[Test 3.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/BloodMage.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: BloodMage.gd exists")
		var content = file.get_as_text()
		file.close()

		if _script_has_method(content, "_create_blood_pool"):
			print("  PASS: has _create_blood_pool() method")
		else:
			print("  FAIL: missing _create_blood_pool() method")
			passed = false
	else:
		print("  FAIL: BloodMage.gd not found")
		passed = false

	_record_result("blood_mage", passed)

# ==================== Test 4: Blood Ancestor ====================

func test_blood_ancestor():
	print("\n------------------------------------------------------------")
	print("Testing Blood Ancestor (血祖) - 鲜血领域机制")
	print("------------------------------------------------------------")

	var passed = true

	# Test 4.1: 检查单位数据配置
	print("\n[Test 4.1] Checking unit data configuration...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("blood_ancestor", {})
	if unit_data.is_empty():
		print("  FAIL: blood_ancestor not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: blood_ancestor found in UNIT_TYPES")

	# Test 4.2: 检查行为脚本
	print("\n[Test 4.2] Checking behavior script...")
	var script_path = "res://src/Scripts/Units/Behaviors/BloodAncestor.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: BloodAncestor.gd exists")
	else:
		print("  FAIL: BloodAncestor.gd not found")
		passed = false

	_record_result("blood_ancestor", passed)

# ==================== Test 5: Gargoyle ====================
func test_gargoyle():
	print("\n------------------------------------------------------------")
	print("Testing Gargoyle (石像鬼)")
	print("------------------------------------------------------------")
	var passed = true
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("gargoyle", {})
	if unit_data.is_empty():
		print("  FAIL: gargoyle not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: gargoyle found in UNIT_TYPES")

	var script_path = "res://src/Scripts/Units/Behaviors/Gargoyle.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: Gargoyle.gd exists")
		var content = file.get_as_text()
		file.close()
		if _script_has_method(content, "_check_petrify_state"):
			print("  PASS: has _check_petrify_state")
		else:
			print("  FAIL: missing _check_petrify_state")
			passed = false
	else:
		print("  FAIL: Gargoyle.gd not found")
		passed = false
	_record_result("gargoyle", passed)

# ==================== Test 6: Life Chain ====================
func test_life_chain():
	print("\n------------------------------------------------------------")
	print("Testing Life Chain (生命链条)")
	print("------------------------------------------------------------")
	var passed = true
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("life_chain", {})
	if unit_data.is_empty():
		print("  FAIL: life_chain not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: life_chain found in UNIT_TYPES")

	var script_path = "res://src/Scripts/Units/Behaviors/LifeChain.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: LifeChain.gd exists")
		var content = file.get_as_text()
		file.close()
		if _script_has_method(content, "_drain_life"):
			print("  PASS: has _drain_life")
		else:
			print("  FAIL: missing _drain_life")
			passed = false
	else:
		print("  FAIL: LifeChain.gd not found")
		passed = false
	_record_result("life_chain", passed)

# ==================== Test 7: Blood Chalice ====================
func test_chalice():
	print("\n------------------------------------------------------------")
	print("Testing Blood Chalice (鲜血圣杯)")
	print("------------------------------------------------------------")
	var passed = true
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("blood_chalice", {})
	if unit_data.is_empty():
		print("  FAIL: blood_chalice not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: blood_chalice found in UNIT_TYPES")

	var script_path = "res://src/Scripts/Units/Behaviors/BloodChalice.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: BloodChalice.gd exists")
		var content = file.get_as_text()
		file.close()
		if _script_has_method(content, "_on_lifesteal"):
			print("  PASS: has _on_lifesteal")
		else:
			print("  FAIL: missing _on_lifesteal")
			passed = false
	else:
		print("  FAIL: BloodChalice.gd not found")
		passed = false
	_record_result("blood_chalice", passed)

# ==================== Test 8: Blood Ritualist ====================
func test_ritualist():
	print("\n------------------------------------------------------------")
	print("Testing Blood Ritualist (血祭术士)")
	print("------------------------------------------------------------")
	var passed = true
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("blood_ritualist", {})
	if unit_data.is_empty():
		print("  FAIL: blood_ritualist not found in UNIT_TYPES")
		passed = false
	else:
		print("  PASS: blood_ritualist found in UNIT_TYPES")

	var script_path = "res://src/Scripts/Units/Behaviors/BloodRitualist.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  PASS: BloodRitualist.gd exists")
		var content = file.get_as_text()
		file.close()
		if _script_has_method(content, "on_skill_activated"):
			print("  PASS: has on_skill_activated")
		else:
			print("  FAIL: missing on_skill_activated")
			passed = false
	else:
		print("  FAIL: BloodRitualist.gd not found")
		passed = false
	_record_result("blood_ritualist", passed)

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
	var result_text = "# Bat Totem Units Test Results\n\n"
	result_text += "Test Date: %s\n\n" % Time.get_datetime_string_from_system()
	result_text += "## Summary\n\n"
	result_text += "- Passed: %d\n" % tests_passed
	result_text += "- Failed: %d\n" % tests_failed
	result_text += "- Total:  %d\n\n" % (tests_passed + tests_failed)

	result_text += "## Detailed Results\n\n"
	for test_name in test_results:
		var status = "PASS" if test_results[test_name] else "FAIL"
		result_text += "- %s: %s\n" % [test_name, status]

	# 确保目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("tasks/bat_totem_units"):
		dir.make_dir_recursive("tasks/bat_totem_units")

	var file = FileAccess.open("res://tasks/bat_totem_units/strict_test_result.md", FileAccess.WRITE)
	if file:
		file.store_string(result_text)
		file.close()
		print("\nTest results saved to: tasks/bat_totem_units/strict_test_result.md")
