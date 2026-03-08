extends SceneTree

func _init():
    var script = preload("res://src/Scripts/Tests/UnitStatsTest.gd")
    var node = Node.new()
    node.set_script(script)
    root.add_child(node)
