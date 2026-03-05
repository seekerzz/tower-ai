extends RefCounted
class_name VisualController

var unit: Node2D

func _init():
	pass

func play_attack_anim(anim_type: String, target_pos: Vector2):
	if !is_instance_valid(unit): return
	if !("visual_holder" in unit) or !unit.visual_holder: return

	if anim_type == "melee":
		var tween = unit.create_tween()
		var start_pos = unit.visual_holder.position
		var l_dir = (target_pos - unit.global_position).normalized()
		var l_offset = l_dir * 10.0
		tween.tween_property(unit.visual_holder, "position", start_pos + l_offset, 0.1)
		tween.tween_property(unit.visual_holder, "position", start_pos, 0.15)
	else:
		var tween = unit.create_tween()
		var start_pos = unit.visual_holder.position
		tween.tween_property(unit.visual_holder, "position", start_pos + Vector2(0, -5), 0.1)
		tween.tween_property(unit.visual_holder, "position", start_pos, 0.1)
