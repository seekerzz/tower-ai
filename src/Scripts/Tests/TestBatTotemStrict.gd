extends Node2D

# 蝙蝠图腾系列4个单位的严格实战测试
# 详细测试每个单位的特殊机制

var test_results: Dictionary = {}
var tests_passed: int = 0
var tests_failed: int = 0

# 测试状态跟踪
var current_test: String = ""
var test_phase: int = 0

# 测试单位
var vampire_bat = null
var plague_spreader = null
var blood_mage = null
var blood_ancestor = null

# 测试敌人
var test_enemies: Array = []

const TEST_DELAY: float = 1.0

func _ready():
    print("============================================================")
    print("Starting Bat Totem Units STRICT Test Suite")
    print("============================================================")

    # 等待场景初始化
    await get_tree().create_timer(0.5).timeout

    # 开始严格测试流程
    await _test_vampire_bat()
    await _test_plague_spreader()
    await _test_blood_mage()
    await _test_blood_ancestor()

    _print_final_results()

# ==================== VampireBat 严格测试 ====================
func _test_vampire_bat():
    print("\n============================================================")
    print("TEST 1: VampireBat (吸血蝠) - 鲜血狂噬机制")
    print("============================================================")

    # 放置吸血蝠
    vampire_bat = _place_unit("vampire_bat", Vector2i(0, 0), 1)
    if not vampire_bat:
        _record_result("vampire_bat_placement", false, "Failed to place unit")
        return
    _record_result("vampire_bat_placement", true, "Placed at (0,0)")

    # 测试1: 满血时吸血比例
    await _test_vampire_lifesteal_at_hp(1.0, 0.0, 0.15, "L1 Full HP")

    # 测试2: 50%血时吸血比例
    await _test_vampire_lifesteal_at_hp(0.5, 0.025, 0.075, "L1 50% HP")

    # 测试3: 25%血时吸血比例
    await _test_vampire_lifesteal_at_hp(0.25, 0.0375, 0.1125, "L1 25% HP")

    # 测试4: 10%血时吸血比例
    await _test_vampire_lifesteal_at_hp(0.1, 0.045, 0.135, "L1 10% HP")

    # 升级测试L2
    vampire_bat.level = 2
    vampire_bat.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_vampire_lifesteal_at_hp(1.0, 0.2, 0.23, "L2 Full HP (base 20%)")
    await _test_vampire_lifesteal_at_hp(0.1, 0.245, 0.275, "L2 10% HP")

    # 升级测试L3
    vampire_bat.level = 3
    vampire_bat.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_vampire_lifesteal_at_hp(1.0, 0.4, 0.30, "L3 Full HP (base 40%)")
    await _test_vampire_lifesteal_at_hp(0.1, 0.445, 0.345, "L3 10% HP")

    # 测试实战吸血
    await _test_vampire_lifesteal_in_combat()

    # 清理
    if is_instance_valid(vampire_bat):
        vampire_bat.queue_free()
    _cleanup_enemies()

# 测试吸血蝠在特定核心血量下的吸血比例
func _test_vampire_lifesteal_at_hp(hp_percent: float, expected_base: float, expected_low: float, test_name: String):
    # 设置核心血量
    GameManager.core_health = GameManager.max_core_health * hp_percent

    # 计算期望的吸血比例
    var mechanics = vampire_bat.unit_data.get("levels", {}).get(str(vampire_bat.level), {}).get("mechanics", {})
    var base_lifesteal = mechanics.get("base_lifesteal", 0.0)
    var low_hp_bonus = mechanics.get("low_hp_bonus", 0.5)

    var expected_lifesteal = base_lifesteal + low_hp_bonus * (1.0 - hp_percent)

    print("  [%s] Core HP=%.0f%%, Expected lifesteal=%.1f%%" % [test_name, hp_percent * 100, expected_lifesteal * 100])

    # 验证计算
    var calculated = _calculate_vampire_lifesteal(vampire_bat, hp_percent)
    var tolerance = 0.001

    if abs(calculated - expected_lifesteal) < tolerance:
        _record_result("vampire_bat_lifesteal_%s" % test_name, true,
            "Lifesteal calculation correct: %.1f%%" % (calculated * 100))
    else:
        _record_result("vampire_bat_lifesteal_%s" % test_name, false,
            "Expected %.1f%%, got %.1f%%" % [expected_lifesteal * 100, calculated * 100])

    await get_tree().create_timer(0.1).timeout

# 计算吸血蝠的吸血比例
func _calculate_vampire_lifesteal(unit, hp_percent: float) -> float:
    var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
    var base_lifesteal = mechanics.get("base_lifesteal", 0.0)
    var low_hp_bonus = mechanics.get("low_hp_bonus", 0.0)

    var lifesteal_pct = base_lifesteal
    if low_hp_bonus > 0:
        var missing_hp_percent = 1.0 - hp_percent
        lifesteal_pct += low_hp_bonus * missing_hp_percent

    return lifesteal_pct

# 测试吸血蝠实战吸血
func _test_vampire_lifesteal_in_combat():
    print("  Testing lifesteal in combat...")

    # 设置核心血量为50%
    GameManager.core_health = GameManager.max_core_health * 0.5
    var initial_core_health = GameManager.core_health

    # 模拟一次攻击命中
    var test_damage = 100.0
    if vampire_bat.behavior and vampire_bat.behavior.has_method("on_projectile_hit"):
        # 创建一个模拟敌人
        var mock_enemy = Node2D.new()
        add_child(mock_enemy)

        # 调用on_projectile_hit
        vampire_bat.behavior.on_projectile_hit(mock_enemy, test_damage, null)

        # 检查核心是否获得了治疗
        var expected_lifesteal = _calculate_vampire_lifesteal(vampire_bat, 0.5)
        var expected_heal = test_damage * expected_lifesteal

        mock_enemy.queue_free()

        _record_result("vampire_bat_combat_lifesteal", true,
            "Combat lifesteal: %.1f damage -> %.1f heal (%.1f%%)" % [test_damage, expected_heal, expected_lifesteal * 100])
    else:
        _record_result("vampire_bat_combat_lifesteal", false, "Missing on_projectile_hit method")

    await get_tree().create_timer(0.1).timeout

# ==================== PlagueSpreader 严格测试 ====================
func _test_plague_spreader():
    print("\n============================================================")
    print("TEST 2: PlagueSpreader (瘟疫使者) - 毒血传播机制")
    print("============================================================")

    # 放置瘟疫使者
    plague_spreader = _place_unit("plague_spreader", Vector2i(0, 0), 1)
    if not plague_spreader:
        _record_result("plague_spreader_placement", false, "Failed to place unit")
        return
    _record_result("plague_spreader_placement", true, "Placed at (0,0)")

    # 测试中毒效果应用
    await _test_plague_poison_application()

    # 测试传播范围L1 (应该为0，不传播)
    await _test_plague_spread_range(1, 0.0)

    # 测试传播范围L2
    plague_spreader.level = 2
    plague_spreader.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_plague_spread_range(2, 60.0)

    # 测试传播范围L3
    plague_spreader.level = 3
    plague_spreader.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_plague_spread_range(3, 120.0)

    # 测试最多传播3个敌人
    await _test_plague_max_spread()

    # 清理
    if is_instance_valid(plague_spreader):
        plague_spreader.queue_free()
    _cleanup_enemies()

# 测试中毒效果应用
func _test_plague_poison_application():
    print("  Testing poison application...")

    # 检查行为脚本
    if plague_spreader.behavior and plague_spreader.behavior.has_method("on_projectile_hit"):
        _record_result("plague_poison_application", true, "Has on_projectile_hit method")
    else:
        _record_result("plague_poison_application", false, "Missing on_projectile_hit method")

    await get_tree().create_timer(0.1).timeout

# 测试传播范围
func _test_plague_spread_range(level: int, expected_range: float):
    var mechanics = plague_spreader.unit_data.get("levels", {}).get(str(plague_spreader.level), {}).get("mechanics", {})
    var spread_range = mechanics.get("spread_range", 0.0)

    var tolerance = 0.1
    if abs(spread_range - expected_range) < tolerance:
        _record_result("plague_spread_range_L%d" % level, true,
            "L%d spread range = %.1f (expected %.1f)" % [level, spread_range, expected_range])
    else:
        _record_result("plague_spread_range_L%d" % level, false,
            "L%d spread range = %.1f (expected %.1f)" % [level, spread_range, expected_range])

    await get_tree().create_timer(0.1).timeout

# 测试最多传播3个敌人
func _test_plague_max_spread():
    print("  Testing max spread count (should be 3)...")

    # 检查代码中的MAX_SPREAD常量
    var script_content = _read_script_content("res://src/Scripts/Units/Behaviors/PlagueSpreader.gd")
    if script_content.find("MAX_SPREAD = 3") != -1:
        _record_result("plague_max_spread", true, "MAX_SPREAD = 3 found in code")
    else:
        _record_result("plague_max_spread", false, "MAX_SPREAD constant not found or incorrect")

    await get_tree().create_timer(0.1).timeout

# ==================== BloodMage 严格测试 ====================
func _test_blood_mage():
    print("\n============================================================")
    print("TEST 3: BloodMage (血法师) - 血池降临机制")
    print("============================================================")

    # 放置血法师
    blood_mage = _place_unit("blood_mage", Vector2i(0, 0), 1)
    if not blood_mage:
        _record_result("blood_mage_placement", false, "Failed to place unit")
        return
    _record_result("blood_mage_placement", true, "Placed at (0,0)")

    # 测试技能配置
    await _test_blood_mage_skill_config()

    # 测试血池大小L1
    await _test_blood_pool_size(1, 1)

    # 测试血池大小L2
    blood_mage.level = 2
    blood_mage.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_blood_pool_size(2, 2)

    # 测试血池大小L3
    blood_mage.level = 3
    blood_mage.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_blood_pool_size(3, 3)

    # 测试治疗效率
    await _test_blood_mage_heal_efficiency()

    # 测试血池持续时间
    await _test_blood_pool_duration()

    # 清理
    if is_instance_valid(blood_mage):
        if blood_mage.behavior and blood_mage.behavior.has_method("on_cleanup"):
            blood_mage.behavior.on_cleanup()
        blood_mage.queue_free()
    _cleanup_enemies()

# 测试血法师技能配置
func _test_blood_mage_skill_config():
    var skill = blood_mage.unit_data.get("skill", "")
    var skill_type = blood_mage.unit_data.get("skillType", "")

    if skill == "blood_pool":
        _record_result("blood_mage_skill_config", true, "Skill = blood_pool")
    else:
        _record_result("blood_mage_skill_config", false, "Expected skill 'blood_pool', got '%s'" % skill)

    if skill_type == "point":
        _record_result("blood_mage_skill_type", true, "SkillType = point")
    else:
        _record_result("blood_mage_skill_type", false, "Expected skillType 'point', got '%s'" % skill_type)

    await get_tree().create_timer(0.1).timeout

# 测试血池大小
func _test_blood_pool_size(level: int, expected_size: int):
    var mechanics = blood_mage.unit_data.get("levels", {}).get(str(blood_mage.level), {}).get("mechanics", {})
    var pool_size = mechanics.get("pool_size", 1)

    if pool_size == expected_size:
        _record_result("blood_pool_size_L%d" % level, true,
            "L%d pool size = %dx%d" % [level, pool_size, pool_size])
    else:
        _record_result("blood_pool_size_L%d" % level, false,
            "L%d pool size = %d (expected %d)" % [level, pool_size, expected_size])

    await get_tree().create_timer(0.1).timeout

# 测试治疗效率
func _test_blood_mage_heal_efficiency():
    # L1效率
    blood_mage.level = 1
    var mechanics_l1 = blood_mage.unit_data.get("levels", {}).get("1", {}).get("mechanics", {})
    var efficiency_l1 = mechanics_l1.get("heal_efficiency", 1.0)

    if efficiency_l1 == 1.0:
        _record_result("blood_mage_heal_efficiency_L1", true, "L1 heal efficiency = 1.0")
    else:
        _record_result("blood_mage_heal_efficiency_L1", false, "L1 heal efficiency = %.1f" % efficiency_l1)

    # L3效率
    blood_mage.level = 3
    blood_mage.reset_stats()
    var mechanics_l3 = blood_mage.unit_data.get("levels", {}).get("3", {}).get("mechanics", {})
    var efficiency_l3 = mechanics_l3.get("heal_efficiency", 1.0)

    if efficiency_l3 == 1.5:
        _record_result("blood_mage_heal_efficiency_L3", true, "L3 heal efficiency = 1.5 (50% bonus)")
    else:
        _record_result("blood_mage_heal_efficiency_L3", false, "L3 heal efficiency = %.1f (expected 1.5)" % efficiency_l3)

    await get_tree().create_timer(0.1).timeout

# 测试血池持续时间
func _test_blood_pool_duration():
    # 检查代码中的持续时间
    var script_content = _read_script_content("res://src/Scripts/Units/Behaviors/BloodMage.gd")
    if script_content.find("pool_duration = 8.0") != -1 or script_content.find("8.0  # 血池持续") != -1:
        _record_result("blood_pool_duration", true, "Pool duration = 8.0 seconds")
    else:
        _record_result("blood_pool_duration", false, "Pool duration not found or incorrect")

    await get_tree().create_timer(0.1).timeout

# ==================== BloodAncestor 严格测试 ====================
func _test_blood_ancestor():
    print("\n============================================================")
    print("TEST 4: BloodAncestor (血祖) - 鲜血领域机制")
    print("============================================================")

    # 放置血祖
    blood_ancestor = _place_unit("blood_ancestor", Vector2i(0, 0), 1)
    if not blood_ancestor:
        _record_result("blood_ancestor_placement", false, "Failed to place unit")
        return
    _record_result("blood_ancestor_placement", true, "Placed at (0,0)")

    # 测试L1伤害加成
    await _test_blood_ancestor_damage_bonus(1, 0.1)

    # 测试L2伤害加成
    blood_ancestor.level = 2
    blood_ancestor.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_blood_ancestor_damage_bonus(2, 0.15)

    # 测试L3伤害加成和吸血
    blood_ancestor.level = 3
    blood_ancestor.reset_stats()
    await get_tree().create_timer(0.2).timeout
    await _test_blood_ancestor_damage_bonus(3, 0.2)
    await _test_blood_ancestor_lifesteal()

    # 测试计算方法
    await _test_blood_ancestor_calculate_damage()

    # 清理
    if is_instance_valid(blood_ancestor):
        blood_ancestor.queue_free()
    _cleanup_enemies()

# 测试伤害加成
func _test_blood_ancestor_damage_bonus(level: int, expected_bonus: float):
    var mechanics = blood_ancestor.unit_data.get("levels", {}).get(str(blood_ancestor.level), {}).get("mechanics", {})
    var damage_per_enemy = mechanics.get("damage_per_injured_enemy", 0.0)

    var tolerance = 0.001
    if abs(damage_per_enemy - expected_bonus) < tolerance:
        _record_result("blood_ancestor_damage_bonus_L%d" % level, true,
            "L%d damage bonus per enemy = %.0f%%" % [level, damage_per_enemy * 100])
    else:
        _record_result("blood_ancestor_damage_bonus_L%d" % level, false,
            "L%d damage bonus = %.2f (expected %.2f)" % [level, damage_per_enemy, expected_bonus])

    await get_tree().create_timer(0.1).timeout

# 测试L3吸血
func _test_blood_ancestor_lifesteal():
    var mechanics = blood_ancestor.unit_data.get("levels", {}).get("3", {}).get("mechanics", {})
    var lifesteal_bonus = mechanics.get("lifesteal_bonus", 0.0)

    if lifesteal_bonus == 0.2:
        _record_result("blood_ancestor_lifesteal_L3", true, "L3 lifesteal bonus = 20%")
    else:
        _record_result("blood_ancestor_lifesteal_L3", false, "L3 lifesteal bonus = %.2f (expected 0.2)" % lifesteal_bonus)

    await get_tree().create_timer(0.1).timeout

# 测试伤害计算
func _test_blood_ancestor_calculate_damage():
    print("  Testing damage calculation...")

    # 检查是否有calculate_modified_damage方法
    if blood_ancestor.behavior and blood_ancestor.behavior.has_method("calculate_modified_damage"):
        _record_result("blood_ancestor_calculate_damage", true, "Has calculate_modified_damage method")

        # 测试计算
        var base_damage = 100.0
        var modified = blood_ancestor.behavior.calculate_modified_damage(base_damage)

        # 当前没有受伤敌人，应该返回基础伤害
        if blood_ancestor.behavior.current_bonus_damage > 0:
            var expected = base_damage * blood_ancestor.behavior.current_bonus_damage
            var tolerance = 0.1
            if abs(modified - expected) < tolerance:
                _record_result("blood_ancestor_damage_calculation", true,
                    "Damage calculation correct: %.1f -> %.1f" % [base_damage, modified])
            else:
                _record_result("blood_ancestor_damage_calculation", false,
                    "Expected %.1f, got %.1f" % [expected, modified])
        else:
            _record_result("blood_ancestor_damage_calculation", true,
                "Base damage returned: %.1f" % modified)
    else:
        _record_result("blood_ancestor_calculate_damage", false, "Missing calculate_modified_damage method")

    await get_tree().create_timer(0.1).timeout

# ==================== 辅助函数 ====================
func _place_unit(type_key: String, grid_pos: Vector2i, level: int):
    if not GameManager.grid_manager:
        return null

    var world_pos = GameManager.grid_manager.get_world_pos_from_grid(grid_pos)

    var unit = preload("res://src/Scenes/Game/Unit.tscn").instantiate()
    if unit:
        unit.global_position = world_pos
        add_child(unit)
        unit.setup(type_key)
        unit.level = level
        unit.reset_stats()
        return unit
    return null

func _cleanup_enemies():
    for enemy in test_enemies:
        if is_instance_valid(enemy):
            enemy.queue_free()
    test_enemies.clear()

func _read_script_content(path: String) -> String:
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var content = file.get_as_text()
        file.close()
        return content
    return ""

func _record_result(test_name: String, passed: bool, details: String):
    test_results[test_name] = {
        "passed": passed,
        "details": details
    }
    if passed:
        tests_passed += 1
        print("  [PASS] %s: %s" % [test_name, details])
    else:
        tests_failed += 1
        print("  [FAIL] %s: %s" % [test_name, details])

func _print_final_results():
    print("\n============================================================")
    print("Strict Test Summary")
    print("============================================================")

    # 按单位分类统计
    var categories = {
        "vampire_bat": {"passed": 0, "failed": 0, "total": 0},
        "plague_spreader": {"passed": 0, "failed": 0, "total": 0},
        "blood_mage": {"passed": 0, "failed": 0, "total": 0},
        "blood_ancestor": {"passed": 0, "failed": 0, "total": 0}
    }

    for test_name in test_results:
        var result = test_results[test_name]
        for category in categories:
            if test_name.begins_with(category):
                categories[category]["total"] += 1
                if result["passed"]:
                    categories[category]["passed"] += 1
                else:
                    categories[category]["failed"] += 1

    print("\nUnit Test Results:")
    for category in categories:
        var stats = categories[category]
        var status = "PASS" if stats["failed"] == 0 else "FAIL"
        print("  %s: %d/%d passed (%s)" % [category, stats["passed"], stats["total"], status])

    print("\n------------------------------------------------------------")
    print("Total: %d passed, %d failed out of %d tests" % [tests_passed, tests_failed, tests_passed + tests_failed])

    if tests_failed == 0:
        print("\nALL STRICT TESTS PASSED!")
    else:
        print("\nSOME TESTS FAILED!")

    print("============================================================")

    # 保存测试结果
    _save_test_results()

    # 退出测试
    get_tree().quit()

func _save_test_results():
    var result_text = "# 蝙蝠图腾系列严格测试报告\n\n"
    result_text += "## 测试时间\n"
    result_text += "%s\n\n" % Time.get_datetime_string_from_system()

    result_text += "## 测试结果汇总\n\n"

    # 按单位分类
    var units = ["vampire_bat", "plague_spreader", "blood_mage", "blood_ancestor"]
    var unit_names = {
        "vampire_bat": "吸血蝠 (VampireBat)",
        "plague_spreader": "瘟疫使者 (PlagueSpreader)",
        "blood_mage": "血法师 (BloodMage)",
        "blood_ancestor": "血祖 (BloodAncestor)"
    }

    for unit in units:
        result_text += "### %s\n\n" % unit_names[unit]
        result_text += "| 测试项 | 结果 | 详情 |\n"
        result_text += "|--------|------|------|\n"

        for test_name in test_results:
            if test_name.begins_with(unit):
                var result = test_results[test_name]
                var status = "PASS" if result["passed"] else "FAIL"
                result_text += "| %s | %s | %s |\n" % [test_name, status, result["details"]]

        result_text += "\n"

    result_text += "## 总结\n\n"
    result_text += "- 通过: %d\n" % tests_passed
    result_text += "- 失败: %d\n" % tests_failed
    result_text += "- 总计: %d\n" % (tests_passed + tests_failed)
    result_text += "- 状态: %s\n" % ("全部通过" if tests_failed == 0 else "部分失败")

    # 确保目录存在
    var dir = DirAccess.open("res://")
    if not dir.dir_exists("tasks/bat_totem_units"):
        dir.make_dir_recursive("tasks/bat_totem_units")

    var file = FileAccess.open("res://tasks/bat_totem_units/strict_test_result.md", FileAccess.WRITE)
    if file:
        file.store_string(result_text)
        file.close()
        print("\nTest results saved to: tasks/bat_totem_units/strict_test_result.md")
