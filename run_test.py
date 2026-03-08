with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "r") as f:
    c = f.read()

c = c.replace("extends Node", "extends SceneTree")
with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "w") as f:
    f.write(c)
