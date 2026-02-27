extends Node

# 鹰图腾系列单位测试套件
# 测试目标:
# 1. storm_eagle (风暴鹰) - 雷暴召唤机制
# 2. gale_eagle (疾风鹰) - 风刃连击机制
# 3. harpy_eagle (角雕) - 三连爪击机制
# 4. vulture (秃鹫) - 腐食增益机制

var test_results: Dictionary = {}
var tests_passed: int = 0
var tests_failed: int = 0
var game_data: Dictionary = {}
var test_date: String = ""

func _ready():
	test_date = Time.get_datetime_string_from_system()
	print("============================================================")
	print("鹰图腾系列单位测试套件 - Eagle Totem Units Test Suite")
	print("测试时间: %s" % test_date)
	print("============================================================")

	# 加载game_data.json
	_load_game_data()

	# 运行所有测试
	test_storm_eagle()
	test_gale_eagle()
	test_harpy_eagle()
	test_vulture()

	# 输出总结
	print("\n============================================================")
	print("测试结果汇总")
	print("============================================================")
	print("通过: %d" % tests_passed)
	print("失败: %d" % tests_failed)
	print("总计: %d" % (tests_passed + tests_failed))

	if tests_failed == 0:
		print("\n✅ 所有测试通过！")
	else:
		print("\n❌ 部分测试失败！")

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
			print("✅ 成功加载 game_data.json")
		else:
			print("❌ 解析 game_data.json 失败")
		file.close()
	else:
		print("❌ 无法打开 game_data.json")

# Helper function to check if script contains method
func _script_has_method(script_content: String, method_name: String) -> bool:
	return script_content.find("func " + method_name) != -1

# Helper function to check if script contains variable
func _script_has_variable(script_content: String, var_name: String) -> bool:
	return script_content.find("var " + var_name) != -1

# ==================== Test 1: Storm Eagle (风暴鹰) ====================

func test_storm_eagle():
	print("\n------------------------------------------------------------")
	print("测试 Storm Eagle (风暴鹰) - 雷暴召唤机制")
	print("------------------------------------------------------------")

	var passed = true
	var errors: Array = []

	# Test 1.1: 检查单位数据配置
	print("\n[测试 1.1] 检查单位数据配置...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("storm_eagle", {})
	if unit_data.is_empty():
		passed = false
		errors.append("storm_eagle 未在 UNIT_TYPES 中找到")
		print("  ❌ FAIL: storm_eagle 未找到")
	else:
		print("  ✅ PASS: storm_eagle 已配置")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "ranged":
			print("  ✅ PASS: attackType 是 'ranged'")
		else:
			passed = false
			errors.append("attackType 错误: %s, 应为 'ranged'" % attack_type)
			print("  ❌ FAIL: attackType 是 '%s', 应为 'ranged'" % attack_type)

		# 检查弹丸类型
		var proj = unit_data.get("proj", "")
		if proj == "lightning":
			print("  ✅ PASS: proj 是 'lightning'")
		else:
			passed = false
			errors.append("proj 错误: %s, 应为 'lightning'" % proj)
			print("  ❌ FAIL: proj 是 '%s', 应为 'lightning'" % proj)

		# 检查等级配置 - charges_needed
		var expected_charges = {1: 5, 2: 4, 3: 3}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var charges = mechanics.get("charges_needed", 0)
			var expected = expected_charges[level]
			if charges == expected:
				print("  ✅ PASS: 等级 %d charges_needed = %d" % [level, charges])
			else:
				passed = false
				errors.append("等级 %d charges_needed 错误: %d, 应为 %d" % [level, charges, expected])
				print("  ❌ FAIL: 等级 %d charges_needed = %d, 应为 %d" % [level, charges, expected])

		# 检查L3 lightning_can_crit
		var l3_mechanics = unit_data.get("levels", {}).get("3", {}).get("mechanics", {})
		if l3_mechanics.get("lightning_can_crit", false) == true:
			print("  ✅ PASS: 等级 3 lightning_can_crit = true")
		else:
			passed = false
			errors.append("等级 3 lightning_can_crit 应为 true")
			print("  ❌ FAIL: 等级 3 lightning_can_crit 应为 true")

	# Test 1.2: 检查行为脚本
	print("\n[测试 1.2] 检查行为脚本...")
	var script_path = "res://src/Scripts/Units/Behaviors/StormEagle.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  ✅ PASS: StormEagle.gd 存在")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		var required_vars = ["charge_stacks", "charges_needed", "lightning_damage", "can_crit"]
		for var_name in required_vars:
			if _script_has_variable(content, var_name):
				print("  ✅ PASS: 包含属性 %s" % var_name)
			else:
				passed = false
				errors.append("缺少属性 %s" % var_name)
				print("  ❌ FAIL: 缺少属性 %s" % var_name)

		# 检查必要的方法
		var required_methods = ["_on_global_crit", "_trigger_lightning_storm", "_spawn_lightning_on_enemy", "on_cleanup"]
		for method_name in required_methods:
			if _script_has_method(content, method_name):
				print("  ✅ PASS: 包含方法 %s()" % method_name)
			else:
				passed = false
				errors.append("缺少方法 %s()" % method_name)
				print("  ❌ FAIL: 缺少方法 %s()" % method_name)

		# 检查继承
		if content.find("extends DefaultBehavior") != -1:
			print("  ✅ PASS: 继承自 DefaultBehavior")
		else:
			passed = false
			errors.append("未继承 DefaultBehavior")
			print("  ❌ FAIL: 未继承 DefaultBehavior")
	else:
		passed = false
		errors.append("StormEagle.gd 未找到")
		print("  ❌ FAIL: StormEagle.gd 未找到")

	# Test 1.3: 检查GameManager信号
	print("\n[测试 1.3] 检查 GameManager 信号...")
	var gm_path = "res://src/Autoload/GameManager.gd"
	var gm_file = FileAccess.open(gm_path, FileAccess.READ)
	if gm_file:
		var gm_content = gm_file.get_as_text()
		gm_file.close()
		if gm_content.find("projectile_crit") != -1:
			print("  ✅ PASS: GameManager 包含 projectile_crit 信号")
		else:
			passed = false
			errors.append("GameManager 缺少 projectile_crit 信号")
			print("  ❌ FAIL: GameManager 缺少 projectile_crit 信号")
	else:
		passed = false
		errors.append("无法读取 GameManager.gd")
		print("  ❌ FAIL: 无法读取 GameManager.gd")

	_record_result("storm_eagle", passed, errors)

# ==================== Test 2: Gale Eagle (疾风鹰) ====================

func test_gale_eagle():
	print("\n------------------------------------------------------------")
	print("测试 Gale Eagle (疾风鹰) - 风刃连击机制")
	print("------------------------------------------------------------")

	var passed = true
	var errors: Array = []

	# Test 2.1: 检查单位数据配置
	print("\n[测试 2.1] 检查单位数据配置...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("gale_eagle", {})
	if unit_data.is_empty():
		passed = false
		errors.append("gale_eagle 未在 UNIT_TYPES 中找到")
		print("  ❌ FAIL: gale_eagle 未找到")
	else:
		print("  ✅ PASS: gale_eagle 已配置")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "ranged":
			print("  ✅ PASS: attackType 是 'ranged'")
		else:
			passed = false
			errors.append("attackType 错误: %s, 应为 'ranged'" % attack_type)
			print("  ❌ FAIL: attackType 是 '%s', 应为 'ranged'" % attack_type)

		# 检查弹丸类型
		var proj = unit_data.get("proj", "")
		if proj == "feather":
			print("  ✅ PASS: proj 是 'feather'")
		else:
			passed = false
			errors.append("proj 错误: %s, 应为 'feather'" % proj)
			print("  ❌ FAIL: proj 是 '%s', 应为 'feather'" % proj)

		# 检查等级配置
		var expected_blades = {1: 2, 2: 3, 3: 4}
		var expected_damage = {1: 0.6, 2: 0.7, 3: 0.8}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var blade_count = mechanics.get("wind_blade_count", 0)
			var damage_pct = mechanics.get("damage_per_blade", 0.0)
			var expected_b = expected_blades[level]
			var expected_d = expected_damage[level]

			if blade_count == expected_b:
				print("  ✅ PASS: 等级 %d wind_blade_count = %d" % [level, blade_count])
			else:
				passed = false
				errors.append("等级 %d wind_blade_count 错误: %d, 应为 %d" % [level, blade_count, expected_b])
				print("  ❌ FAIL: 等级 %d wind_blade_count = %d, 应为 %d" % [level, blade_count, expected_b])

			if abs(damage_pct - expected_d) < 0.001:
				print("  ✅ PASS: 等级 %d damage_per_blade = %.0f%%" % [level, damage_pct * 100])
			else:
				passed = false
				errors.append("等级 %d damage_per_blade 错误: %.2f, 应为 %.2f" % [level, damage_pct, expected_d])
				print("  ❌ FAIL: 等级 %d damage_per_blade = %.2f, 应为 %.2f" % [level, damage_pct, expected_d])

	# Test 2.2: 检查行为脚本
	print("\n[测试 2.2] 检查行为脚本...")
	var script_path = "res://src/Scripts/Units/Behaviors/GaleEagle.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  ✅ PASS: GaleEagle.gd 存在")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		var required_vars = ["wind_blade_count", "damage_per_blade", "spread_angle"]
		for var_name in required_vars:
			if _script_has_variable(content, var_name):
				print("  ✅ PASS: 包含属性 %s" % var_name)
			else:
				passed = false
				errors.append("缺少属性 %s" % var_name)
				print("  ❌ FAIL: 缺少属性 %s" % var_name)

		# 检查必要的方法
		var required_methods = ["on_combat_tick", "_do_wind_blade_attack", "_fire_wind_blades", "_update_mechanics"]
		for method_name in required_methods:
			if _script_has_method(content, method_name):
				print("  ✅ PASS: 包含方法 %s()" % method_name)
			else:
				passed = false
				errors.append("缺少方法 %s()" % method_name)
				print("  ❌ FAIL: 缺少方法 %s()" % method_name)

		# 检查继承
		if content.find("extends DefaultBehavior") != -1:
			print("  ✅ PASS: 继承自 DefaultBehavior")
		else:
			passed = false
			errors.append("未继承 DefaultBehavior")
			print("  ❌ FAIL: 未继承 DefaultBehavior")
	else:
		passed = false
		errors.append("GaleEagle.gd 未找到")
		print("  ❌ FAIL: GaleEagle.gd 未找到")

	_record_result("gale_eagle", passed, errors)

# ==================== Test 3: Harpy Eagle (角雕) ====================

func test_harpy_eagle():
	print("\n------------------------------------------------------------")
	print("测试 Harpy Eagle (角雕) - 三连爪击机制")
	print("------------------------------------------------------------")

	var passed = true
	var errors: Array = []

	# Test 3.1: 检查单位数据配置
	print("\n[测试 3.1] 检查单位数据配置...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("harpy_eagle", {})
	if unit_data.is_empty():
		passed = false
		errors.append("harpy_eagle 未在 UNIT_TYPES 中找到")
		print("  ❌ FAIL: harpy_eagle 未找到")
	else:
		print("  ✅ PASS: harpy_eagle 已配置")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "melee":
			print("  ✅ PASS: attackType 是 'melee'")
		else:
			passed = false
			errors.append("attackType 错误: %s, 应为 'melee'" % attack_type)
			print("  ❌ FAIL: attackType 是 '%s', 应为 'melee'" % attack_type)

		# 检查等级配置
		var expected_damage = {1: 0.6, 2: 0.7, 3: 0.8}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var damage_pct = mechanics.get("damage_per_claw", 0.0)
			var expected_d = expected_damage[level]

			if abs(damage_pct - expected_d) < 0.001:
				print("  ✅ PASS: 等级 %d damage_per_claw = %.0f%%" % [level, damage_pct * 100])
			else:
				passed = false
				errors.append("等级 %d damage_per_claw 错误: %.2f, 应为 %.2f" % [level, damage_pct, expected_d])
				print("  ❌ FAIL: 等级 %d damage_per_claw = %.2f, 应为 %.2f" % [level, damage_pct, expected_d])

		# 检查L3 third_claw_bleed
		var l3_mechanics = unit_data.get("levels", {}).get("3", {}).get("mechanics", {})
		if l3_mechanics.get("third_claw_bleed", false) == true:
			print("  ✅ PASS: 等级 3 third_claw_bleed = true")
		else:
			passed = false
			errors.append("等级 3 third_claw_bleed 应为 true")
			print("  ❌ FAIL: 等级 3 third_claw_bleed 应为 true")

		# 检查L1和L2 third_claw_bleed为false
		for level in [1, 2]:
			var mechanics = unit_data.get("levels", {}).get(str(level), {}).get("mechanics", {})
			if mechanics.get("third_claw_bleed", false) == false:
				print("  ✅ PASS: 等级 %d third_claw_bleed = false" % level)
			else:
				passed = false
				errors.append("等级 %d third_claw_bleed 应为 false" % level)
				print("  ❌ FAIL: 等级 %d third_claw_bleed 应为 false" % level)

	# Test 3.2: 检查行为脚本
	print("\n[测试 3.2] 检查行为脚本...")
	var script_path = "res://src/Scripts/Units/Behaviors/HarpyEagle.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  ✅ PASS: HarpyEagle.gd 存在")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		var required_vars = ["claw_count", "damage_per_claw", "third_claw_bleed", "_current_claw", "_combo_target"]
		for var_name in required_vars:
			if _script_has_variable(content, var_name):
				print("  ✅ PASS: 包含属性 %s" % var_name)
			else:
				passed = false
				errors.append("缺少属性 %s" % var_name)
				print("  ❌ FAIL: 缺少属性 %s" % var_name)

		# 检查必要的方法
		var required_methods = ["start_attack_sequence", "_start_claw_attack", "_calculate_damage", "_apply_bleed"]
		for method_name in required_methods:
			if _script_has_method(content, method_name):
				print("  ✅ PASS: 包含方法 %s()" % method_name)
			else:
				passed = false
				errors.append("缺少方法 %s()" % method_name)
				print("  ❌ FAIL: 缺少方法 %s()" % method_name)

		# 检查继承
		if content.find("extends FlyingMeleeBehavior") != -1:
			print("  ✅ PASS: 继承自 FlyingMeleeBehavior")
		else:
			passed = false
			errors.append("未继承 FlyingMeleeBehavior")
			print("  ❌ FAIL: 未继承 FlyingMeleeBehavior")

		# 检查流血效果引用
		if content.find("BleedEffect") != -1:
			print("  ✅ PASS: 引用了 BleedEffect")
		else:
			passed = false
			errors.append("未引用 BleedEffect")
			print("  ❌ FAIL: 未引用 BleedEffect")
	else:
		passed = false
		errors.append("HarpyEagle.gd 未找到")
		print("  ❌ FAIL: HarpyEagle.gd 未找到")

	_record_result("harpy_eagle", passed, errors)

# ==================== Test 4: Vulture (秃鹫) ====================

func test_vulture():
	print("\n------------------------------------------------------------")
	print("测试 Vulture (秃鹫) - 腐食增益机制")
	print("------------------------------------------------------------")

	var passed = true
	var errors: Array = []

	# Test 4.1: 检查单位数据配置
	print("\n[测试 4.1] 检查单位数据配置...")
	var unit_types = game_data.get("UNIT_TYPES", {})
	var unit_data = unit_types.get("vulture", {})
	if unit_data.is_empty():
		passed = false
		errors.append("vulture 未在 UNIT_TYPES 中找到")
		print("  ❌ FAIL: vulture 未找到")
	else:
		print("  ✅ PASS: vulture 已配置")

		# 检查攻击类型
		var attack_type = unit_data.get("attackType", "")
		if attack_type == "melee":
			print("  ✅ PASS: attackType 是 'melee'")
		else:
			passed = false
			errors.append("attackType 错误: %s, 应为 'melee'" % attack_type)
			print("  ❌ FAIL: attackType 是 '%s', 应为 'melee'" % attack_type)

		# 检查等级配置
		var expected_bonus = {1: 0.05, 2: 0.1, 3: 0.1}
		var expected_lifesteal = {1: 0.0, 2: 0.0, 3: 0.2}
		for level in [1, 2, 3]:
			var level_data = unit_data.get("levels", {}).get(str(level), {})
			var mechanics = level_data.get("mechanics", {})
			var bonus = mechanics.get("damage_bonus_percent", 0.0)
			var lifesteal = mechanics.get("lifesteal_percent", 0.0)
			var expected_b = expected_bonus[level]
			var expected_l = expected_lifesteal[level]

			if abs(bonus - expected_b) < 0.001:
				print("  ✅ PASS: 等级 %d damage_bonus_percent = %d%%" % [level, int(bonus * 100)])
			else:
				passed = false
				errors.append("等级 %d damage_bonus_percent 错误: %.2f, 应为 %.2f" % [level, bonus, expected_b])
				print("  ❌ FAIL: 等级 %d damage_bonus_percent = %.2f, 应为 %.2f" % [level, bonus, expected_b])

			if abs(lifesteal - expected_l) < 0.001:
				print("  ✅ PASS: 等级 %d lifesteal_percent = %d%%" % [level, int(lifesteal * 100)])
			else:
				passed = false
				errors.append("等级 %d lifesteal_percent 错误: %.2f, 应为 %.2f" % [level, lifesteal, expected_l])
				print("  ❌ FAIL: 等级 %d lifesteal_percent = %.2f, 应为 %.2f" % [level, lifesteal, expected_l])

		# 检查检测范围
		for level in [1, 2, 3]:
			var mechanics = unit_data.get("levels", {}).get(str(level), {}).get("mechanics", {})
			var detection_range = mechanics.get("detection_range", 0)
			if detection_range == 300:
				print("  ✅ PASS: 等级 %d detection_range = 300" % level)
			else:
				passed = false
				errors.append("等级 %d detection_range 错误: %d, 应为 300" % [level, detection_range])
				print("  ❌ FAIL: 等级 %d detection_range = %d, 应为 300" % [level, detection_range])

	# Test 4.2: 检查行为脚本
	print("\n[测试 4.2] 检查行为脚本...")
	var script_path = "res://src/Scripts/Units/Behaviors/Vulture.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		print("  ✅ PASS: Vulture.gd 存在")
		var content = file.get_as_text()
		file.close()

		# 检查必要的属性
		var required_vars = ["damage_bonus_percent", "lifesteal_percent", "buff_duration",
							 "detection_range", "buff_active", "buff_timer"]
		for var_name in required_vars:
			if _script_has_variable(content, var_name):
				print("  ✅ PASS: 包含属性 %s" % var_name)
			else:
				passed = false
				errors.append("缺少属性 %s" % var_name)
				print("  ❌ FAIL: 缺少属性 %s" % var_name)

		# 检查必要的方法
		var required_methods = ["_load_mechanics", "_on_enemy_died",
							   "_trigger_scavenger_buff", "on_level_up", "on_cleanup"]
		for method_name in required_methods:
			if _script_has_method(content, method_name):
				print("  ✅ PASS: 包含方法 %s()" % method_name)
			else:
				passed = false
				errors.append("缺少方法 %s()" % method_name)
				print("  ❌ FAIL: 缺少方法 %s()" % method_name)

		# 检查继承
		if content.find("extends FlyingMeleeBehavior") != -1:
			print("  ✅ PASS: 继承自 FlyingMeleeBehavior")
		else:
			passed = false
			errors.append("未继承 FlyingMeleeBehavior")
			print("  ❌ FAIL: 未继承 FlyingMeleeBehavior")
	else:
		passed = false
		errors.append("Vulture.gd 未找到")
		print("  ❌ FAIL: Vulture.gd 未找到")

	_record_result("vulture", passed, errors)

# ==================== Helper Functions ====================

func _record_result(test_name: String, passed: bool, errors: Array):
	test_results[test_name] = {
		"passed": passed,
		"errors": errors
	}
	if passed:
		tests_passed += 1
		print("\n[结果] %s: ✅ PASS" % test_name)
	else:
		tests_failed += 1
		print("\n[结果] %s: ❌ FAIL" % test_name)
		for error in errors:
			print("    - %s" % error)

func _save_test_results():
	var result_text = "# 鹰图腾系列单位测试结果\n\n"
	result_text += "## 测试信息\n\n"
	result_text += "- 测试日期: %s\n" % test_date
	result_text += "- 测试类型: 代码结构和配置检查\n\n"
	result_text += "## 测试汇总\n\n"
	result_text += "| 项目 | 数量 |\n"
	result_text += "|------|------|\n"
	result_text += "| 通过 | %d |\n" % tests_passed
	result_text += "| 失败 | %d |\n" % tests_failed
	result_text += "| 总计 | %d |\n\n" % (tests_passed + tests_failed)

	result_text += "## 详细结果\n\n"
	for test_name in test_results:
		var result = test_results[test_name]
		var status = "✅ PASS" if result["passed"] else "❌ FAIL"
		result_text += "### %s: %s\n\n" % [test_name, status]
		if not result["errors"].is_empty():
			result_text += "**失败原因:**\n\n"
			for error in result["errors"]:
				result_text += "- %s\n" % error
			result_text += "\n"

	result_text += "## 备注\n\n"
	if tests_failed == 0:
		result_text += "所有测试通过！单位配置和代码结构正确。\n"
	else:
		result_text += "部分测试失败，请查看具体失败原因并修复。\n"

	# 确保目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("tasks/eagle_totem_units"):
		dir.make_dir_recursive("tasks/eagle_totem_units")

	var file = FileAccess.open("res://tasks/eagle_totem_units/test_result.md", FileAccess.WRITE)
	if file:
		file.store_string(result_text)
		file.close()
		print("\n测试结果已保存至: tasks/eagle_totem_units/test_result.md")
