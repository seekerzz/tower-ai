extends SceneTree

func _init():
    print("Starting tests...")
    var gm = root.get_node_or_null("GameManager")
    if gm:
        gm.set_script(load("res://src/Scripts/Tests/MockGameManager.gd"))
        gm.is_wave_active = true

    var test_node = load("res://src/Scripts/Tests/test_unit_components.gd").new()
