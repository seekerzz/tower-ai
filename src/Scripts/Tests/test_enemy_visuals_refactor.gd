extends Node

var hp_changed_emitted = false
var status_applied_emitted = false

func _ready():
    call_deferred("_run_test")

func _run_test():
    var enemy_script = load("res://src/Scripts/Enemy.gd")
    var enemy = enemy_script.new()

    add_child(enemy)

    var failed = false
    print("--- Test Started ---")

    # Needs valid type to load stats correctly and attach Visuals
    var valid_enemy = "crab"
    enemy.setup(valid_enemy, 1)

    # Connect to signals to verify emissions explicitly
    enemy.hp_changed.connect(_on_hp_changed)
    enemy.status_applied.connect(_on_status_applied)

    # 1. Simulate adding 30 layers of bleed
    print("Testing 30 bleed layers...")
    if enemy.has_method("add_bleed_stacks"):
        enemy.add_bleed_stacks(30, null)

    if enemy.has_node("TextureRect") or enemy.has_node("ExecuteIndicator") or enemy.has_node("ExecuteBorder") or enemy.has_node("MaxBleedGlow"):
        print("FAIL: Visual nodes were generated inside Enemy!")
        failed = true

    var has_visuals = false
    var visuals_node = null
    for child in enemy.get_children():
        if child.name == "EnemyVisuals":
            has_visuals = true
            visuals_node = child
            break

    if not has_visuals:
        print("FAIL: EnemyVisuals not attached to Enemy!")
        failed = true

    # 2. Simulate lethal damage and verify signals
    print("Testing lethal damage...")
    var lethal_damage = enemy.hp + 100
    enemy.take_damage(lethal_damage)

    if not hp_changed_emitted:
        print("FAIL: hp_changed signal was never emitted on damage taken!")
        failed = true

    enemy.apply_stun(2.0)
    if not status_applied_emitted:
        print("FAIL: status_applied signal was never emitted on status application!")
        failed = true

    if failed:
        print("Some tests failed.")
    else:
        print("Tests passed!")

    print("--- Test Completed ---")
    get_tree().quit()

func _on_hp_changed(old, new):
    hp_changed_emitted = true
    print("Signal emitted: hp_changed (", old, " -> ", new, ")")

func _on_status_applied(key, duration, source):
    status_applied_emitted = true
    print("Signal emitted: status_applied (", key, " for ", duration, "s)")
