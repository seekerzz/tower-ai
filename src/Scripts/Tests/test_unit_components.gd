extends Node

func _ready():
    print("Running Unit Refactor Tests...")
    var tests_passed = 0
    var tests_failed = 0

    var unit_script = load("res://src/Scripts/Unit.gd")
    if not unit_script:
        print("ERROR: Failed to load Unit.gd")
        get_tree().quit(1)
        return

    # In a real scene GameManager and Constants exist as autoloads
    # We will just patch their relevant properties or use them as is for testing

    # TEST 1: Unit Setup and Stats Initialization
    var test_unit = Node2D.new()
    test_unit.set_script(unit_script)
    add_child(test_unit)

    # Set up unit data manually for test
    test_unit.unit_data = {
        "hp": 100.0,
        "damage": 10.0,
        "range": 200.0,
        "atkSpeed": 1.5,
        "size": Vector2(1, 1),
        "attackType": "ranged"
    }
    test_unit.type_key = "test_unit"
    Constants.UNIT_TYPES["test_unit"] = test_unit.unit_data.duplicate()

    test_unit._load_behavior()
    test_unit.reset_stats()
    test_unit.current_hp = test_unit.max_hp

    if test_unit.max_hp == 100.0 and test_unit.damage == 10.0 and test_unit.range_val == 200.0 and test_unit.atk_speed == 1.5:
        print("PASS: Unit Setup and Stats Initialization")
        tests_passed += 1
    else:
        print("FAIL: Unit Setup and Stats Initialization")
        print("  Expected hp=100, damage=10, range=200, atkSpeed=1.5")
        print("  Got hp=%f, damage=%f, range=%f, atkSpeed=%f" % [test_unit.max_hp, test_unit.damage, test_unit.range_val, test_unit.atk_speed])
        tests_failed += 1

    # TEST 2: Taking Damage
    # We may need to mock behavior.on_damage_taken or GameManager.damage_core temporarily
    var temp_damage_core = null
    test_unit.take_damage(20.0)
    if test_unit.current_hp == 80.0:
        print("PASS: Taking Damage")
        tests_passed += 1
    else:
        print("FAIL: Taking Damage")
        print("  Expected current_hp=80.0, Got current_hp=%f" % test_unit.current_hp)
        tests_failed += 1

    # TEST 3: Applying Buffs
    test_unit.apply_buff("range")
    test_unit.apply_buff("speed")
    test_unit.apply_buff("crit")
    test_unit.apply_buff("bounce")

    if is_equal_approx(test_unit.range_val, 250.0) and is_equal_approx(test_unit.atk_speed, 1.8) and is_equal_approx(test_unit.crit_rate, 0.35) and test_unit.bounce_count == 1:
        print("PASS: Applying Buffs")
        tests_passed += 1
    else:
        print("FAIL: Applying Buffs")
        print("  Expected range=250, atkSpeed=1.8, critRate=0.35, bounce=1")
        print("  Got range=%f, atkSpeed=%f, critRate=%f, bounce=%d" % [test_unit.range_val, test_unit.atk_speed, test_unit.crit_rate, test_unit.bounce_count])
        tests_failed += 1

    # TEST 4: Healing
    test_unit.heal(10.0)
    if test_unit.current_hp == 90.0:
        print("PASS: Healing")
        tests_passed += 1
    else:
        print("FAIL: Healing")
        print("  Expected current_hp=90.0, Got current_hp=%f" % test_unit.current_hp)
        tests_failed += 1

    # TEST 5: Temporary Buffs
    test_unit.add_temporary_buff("attack_speed", 0.5, 2.0)
    if is_equal_approx(test_unit.atk_speed, 2.7): # 1.8 * 1.5
        print("PASS: Apply Temporary Buff")
        tests_passed += 1
    else:
        print("FAIL: Apply Temporary Buff")
        print("  Expected atkSpeed=2.7, Got atkSpeed=%f" % test_unit.atk_speed)
        tests_failed += 1

    test_unit._update_temporary_buffs(2.1) # Simulate time passing
    if is_equal_approx(test_unit.atk_speed, 1.8):
        print("PASS: Remove Temporary Buff")
        tests_passed += 1
    else:
        print("FAIL: Remove Temporary Buff")
        print("  Expected atkSpeed=1.8, Got atkSpeed=%f" % test_unit.atk_speed)
        tests_failed += 1

    print("--------------------------------------------------")
    print("Total Tests Passed: ", tests_passed)
    print("Total Tests Failed: ", tests_failed)

    test_unit.queue_free()

    if tests_failed > 0:
        get_tree().quit(1)
    else:
        get_tree().quit(0)
