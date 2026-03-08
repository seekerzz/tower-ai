import re

with open("src/Scripts/Unit.gd", "r") as f:
    code = f.read()

# Remove specific visual variables
vars_to_remove = [
    r"var visual_holder: Node2D = null\n",
    r"var is_dragging: bool = false\n",
    r"var drag_offset: Vector2 = Vector2\.ZERO\n",
    r"var ghost_node: Node2D = null\n",
    r"var is_hovered: bool = false\n",
    r"var _is_skill_highlight_active: bool = false\n",
    r"var _highlight_color: Color = Color\.WHITE\n",
    r"var is_force_highlighted: bool = false\n",
    r"var breathe_tween: Tween = null\n",
    r"var attack_tween: Tween = null\n",
]

for v in vars_to_remove:
    code = re.sub(v, "", code)

# We need to expose signals instead
signals = """
signal on_damage_taken_visual()
signal attack_started_visual(attack_type: String, target_pos: Vector2, duration: float)
signal buff_received_visual()
signal level_up_visual()
signal skill_cast_visual()
signal visual_update_requested()
signal spawn_buff_effect_visual(icon_char: String)

signal interaction_mouse_entered()
signal interaction_mouse_exited()
signal interaction_input_event(viewport, event, shape_idx)
signal highlight_requested(active: bool, color: Color)
signal force_highlight_requested(active: bool)
signal drag_started(mouse_pos_global: Vector2)

var _unit_visuals = null
var _unit_interaction = null

"""

code = code.replace("signal damage_blocked(damage: float, source: Node)", "signal damage_blocked(damage: float, source: Node)\n" + signals)

# Find and replace function calls in `_ready`
ready_replacement = """func _ready():
	_unit_visuals = UnitVisuals.new(self)
	add_child(_unit_visuals)

	_unit_interaction = UnitInteraction.new(self)
	add_child(_unit_interaction)

	tree_exiting.connect(_on_cleanup)

	if !unit_data.is_empty():
		visual_update_requested.emit()"""

code = re.sub(r"func _ready\(\):[\s\S]*?(?=func _on_cleanup)", ready_replacement + "\n\n", code)


# Delete visual functions
funcs_to_delete = [
    r"func _ensure_visual_hierarchy\(\):[\s\S]*?(?=func take_damage)",
    r"func update_visuals\(\):[\s\S]*?(?=func _update_buff_icons)",
    r"func _update_buff_icons\(\):[\s\S]*?(?=func _get_buff_icon)",
    r"func _get_buff_icon\(buff_type: String\) -> String:[\s\S]*?(?=func _process)",
    r"func play_attack_anim\(attack_type: String, target_pos: Vector2, duration: float = -1\.0\):[\s\S]*?(?=var breathe_tween: Tween = null)",
    r"func start_breathe_anim\(\):[\s\S]*?(?=func can_merge_with)",
    r"func play_buff_receive_anim\(\):[\s\S]*?(?=func spawn_buff_effect)",
    r"func spawn_buff_effect\(icon_char: String\):[\s\S]*?(?=func add_stat_bonus)",
]

for func in funcs_to_delete:
    code = re.sub(func, "", code)


# Replace interaction functions with signal emissions
interaction_funcs_replace = {
    r"func _on_area_2d_input_event\(viewport, event, shape_idx\):[\s\S]*?(?=func _on_area_2d_mouse_entered)": "func _on_area_2d_input_event(viewport, event, shape_idx):\n\tinteraction_input_event.emit(viewport, event, shape_idx)\n\n",
    r"func _on_area_2d_mouse_entered\(\):[\s\S]*?(?=func _on_area_2d_mouse_exited)": "func _on_area_2d_mouse_entered():\n\tinteraction_mouse_entered.emit()\n\n",
    r"func _on_area_2d_mouse_exited\(\):[\s\S]*?(?=func _draw)": "func _on_area_2d_mouse_exited():\n\tinteraction_mouse_exited.emit()\n\n",
}

for regex, replacement in interaction_funcs_replace.items():
    code = re.sub(regex, replacement, code)


# Remove interaction logic (draw, input, drag) entirely
interaction_logic_delete = [
    r"func set_highlight\(active: bool, color: Color = Color\.WHITE\):[\s\S]*?(?=func set_force_highlight)",
    r"func set_force_highlight\(active: bool\):[\s\S]*?(?=func execute_skill_at)",
    r"func _draw\(\):[\s\S]*?(?=func _get_neighbor_units)",
    r"func _input\(event\):[\s\S]*?(?=func start_drag)",
    r"func start_drag\(mouse_pos_global\):[\s\S]*?(?=func end_drag)",
    r"func end_drag\(\):[\s\S]*?(?=func create_ghost)",
    r"func create_ghost\(\):[\s\S]*?(?=func remove_ghost)",
    r"func remove_ghost\(\):[\s\S]*?(?=func return_to_start)",
    r"func return_to_start\(\):[\s\S]*?(?=func _find_empty_bench_slot)",
]

for logic in interaction_logic_delete:
    code = re.sub(logic, "", code)

# Replace the drag interface to emit signal
#Wait, some components call set_force_highlight or set_highlight directly on unit.
#So we should keep wrappers that emit the signals.
wrappers = """
func set_highlight(active: bool, color: Color = Color.WHITE):
	highlight_requested.emit(active, color)

func set_force_highlight(active: bool):
	force_highlight_requested.emit(active)

func start_drag(mouse_pos_global):
	drag_started.emit(mouse_pos_global)

func update_visuals():
	visual_update_requested.emit()
"""

# Let's insert wrappers at the end.
code += "\n" + wrappers

# Now replace hardcoded tweening in take_damage, activate_skill, merge_with
code = re.sub(r"if visual_holder:\n\t\tvar tween = create_tween\(\)[\s\S]*?position\", Vector2\.ZERO, 0\.05\)", "on_damage_taken_visual.emit()", code)
code = re.sub(r"if visual_holder:\n\t\t\tvar tween = create_tween\(\)[\s\S]*?scale\", Vector2\(1\.0, 1\.0\), 0\.1\)", "skill_cast_visual.emit()", code)
code = re.sub(r"if visual_holder:\n\t\tvar tween = create_tween\(\)[\s\S]*?scale\", Vector2\(1\.0, 1\.0\), 0\.2\)", "level_up_visual.emit()", code)

# Replace update_visuals() calls -> they are now wrappers

# In `setup`, replace update_visuals() and start_breathe_anim() with signal
code = re.sub(r"update_visuals\(\)\n\tstart_breathe_anim\(\)", "visual_update_requested.emit()\n\tattack_started_visual.emit('breathe', Vector2.ZERO, 0.0)", code)

# In `_do_melee_attack`, `play_attack_anim` -> emit
code = code.replace('play_attack_anim("melee", target_last_pos)', 'attack_started_visual.emit("melee", target_last_pos, -1.0)')

# In `_do_standard_ranged_attack`, `play_attack_anim` -> emit
code = code.replace('play_attack_anim("lightning", target.global_position)', 'attack_started_visual.emit("lightning", target.global_position, -1.0)')
code = code.replace('play_attack_anim("ranged", target.global_position)', 'attack_started_visual.emit("ranged", target.global_position, -1.0)')


with open("src/Scripts/Unit.gd", "w") as f:
    f.write(code)
