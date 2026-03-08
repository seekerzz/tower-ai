import re

with open("src/Scripts/Unit.gd", "r") as f:
    code = f.read()

# Add `const UnitVisuals = preload("res://src/Scripts/Units/UnitVisuals.gd")` and `const UnitInteraction = preload("res://src/Scripts/Units/UnitInteraction.gd")` at the top
code = code.replace("const UnitBehavior = preload(\"res://src/Scripts/Units/UnitBehavior.gd\")", "const UnitBehavior = preload(\"res://src/Scripts/Units/UnitBehavior.gd\")\nconst UnitVisuals = preload(\"res://src/Scripts/Units/UnitVisuals.gd\")\nconst UnitInteraction = preload(\"res://src/Scripts/Units/UnitInteraction.gd\")")

# Remove `_ensure_visual_hierarchy()` call from `setup()`
code = code.replace("\t_ensure_visual_hierarchy()\n\ttype_key = key", "\ttype_key = key")

with open("src/Scripts/Unit.gd", "w") as f:
    f.write(code)
