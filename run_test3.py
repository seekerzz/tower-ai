with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "r") as f:
    c = f.read()

c = c.replace("await process_frame", "pass")

with open("src/Scripts/Tests/UnitVisualsAndInteractionTest.gd", "w") as f:
    f.write(c)
