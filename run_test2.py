with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "r") as f:
    c = f.read()

c = c.replace("extends SceneTree", "extends SceneTree\n\nfunc _initialize():\n\t_run()\n\nfunc _run():")
c = c.replace("func _ready():", "")
c = c.replace("get_tree().process_frame", "process_frame")
c = c.replace("get_tree().root", "root")
c = c.replace("get_tree().quit", "quit")

with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "w") as f:
    f.write(c)
