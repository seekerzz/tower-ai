import re

with open("src/Scripts/Unit.gd", "r") as f:
    code = f.read()

funcs_to_delete = [
    r"func play_attack_anim\(attack_type: String, target_pos: Vector2, duration: float = -1\.0\):[\s\S]*?(?=func get_interaction_info)",
]

for func in funcs_to_delete:
    code = re.sub(func, "", code)

with open("src/Scripts/Unit.gd", "w") as f:
    f.write(code)
