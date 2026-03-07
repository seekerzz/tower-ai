extends SceneTree

func _initialize():
    print("Running Unit Refactor Test...")
    var UnitScript = load("res://src/Scripts/Unit.gd")
    if not UnitScript:
        print("Failed to load Unit script.")
        quit(1)
        return

    var unit = UnitScript.new()
    var passed = true

    var old_properties = [
        "damage", "range_val", "atk_speed", "attack_cost_mana", "skill_mana_cost",
        "max_hp", "current_hp", "hp", "crit_rate", "crit_dmg"
    ]

    for prop in old_properties:
        if prop in unit:
            print("FAIL: Unit still has legacy property '", prop, "'")
            passed = false
        else:
            print("PASS: Unit does not have property '", prop, "'")

    if not passed:
        print("TEST FAILED: Legacy properties still exist!")
        quit(1)
        return

    var unit_scene = Node2D.new()
    unit_scene.set_script(UnitScript)
    print("TEST PASSED: Unit refactor properties test successful.")
    quit(0)
