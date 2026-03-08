with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "r") as f:
    c = f.read()

# remove unit._ready() since unit_scene.instantiate() already calls _ready
c = c.replace("unit._ready()", "pass")

with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "w") as f:
    f.write(c)
