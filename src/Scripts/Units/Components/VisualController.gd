extends Node
class_name VisualController

var unit: Node2D

func _init():
	pass

var breathe_tween: Tween = null
var attack_tween: Tween = null

func play_damage_anim():
	if !is_instance_valid(unit) or !unit.get("visual_holder") or !unit.visual_holder: return
	var tween = unit.create_tween()
	tween.tween_property(unit.visual_holder, "position", Vector2(randf_range(-2,2), randf_range(-2,2)), 0.05).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(unit.visual_holder, "position", Vector2.ZERO, 0.05)

func play_buff_receive_anim():
	if !is_instance_valid(unit) or !unit.get("visual_holder") or !unit.visual_holder: return
	var tween = unit.create_tween()
	tween.tween_property(unit.visual_holder, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func play_attack_anim(attack_type: String, target_pos: Vector2, duration: float = -1.0):
	if !is_instance_valid(unit) or !unit.get("visual_holder") or !unit.visual_holder: return

	if breathe_tween: breathe_tween.kill()
	if attack_tween: attack_tween.kill()

	attack_tween = unit.create_tween()

	if attack_type == "melee":
		var pull_time = 0.15
		var hit_time = 0.05
		var recover_time = 0.2
		var total_anim_time = pull_time + hit_time + recover_time

		var dist = unit.global_position.distance_to(target_pos)
		var attack_dir = (target_pos - unit.global_position).normalized()

		var reach = min(dist, unit.stats.range_val * 0.8)
		if reach < 20: reach = 20

		var pull_back_pos = -attack_dir * 10.0
		var strike_pos = attack_dir * reach

		attack_tween.tween_property(unit.visual_holder, "position", pull_back_pos, pull_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(unit.visual_holder, "scale", Vector2(0.8, 1.2), pull_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		attack_tween.tween_callback(func():
			unit.visual_holder.position = Vector2.ZERO
			unit.visual_holder.scale = Vector2.ONE
		)

		attack_tween.tween_property(unit.visual_holder, "scale", Vector2(1.1, 0.9), recover_time * 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.tween_property(unit.visual_holder, "scale", Vector2.ONE, recover_time * 0.5)

	elif attack_type == "ranged" or attack_type == "lightning":
		attack_tween.tween_property(unit.visual_holder, "scale", Vector2(0.8, 0.8), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.2)
		attack_tween.parallel().tween_property(unit.visual_holder, "position", Vector2.ZERO, 0.3)

	attack_tween.finished.connect(func(): start_breathe_anim())

func start_breathe_anim():
	if !is_instance_valid(unit) or !unit.get("visual_holder") or !unit.visual_holder: return

	if breathe_tween: breathe_tween.kill()

	breathe_tween = unit.create_tween().set_loops()
	breathe_tween.tween_property(unit.visual_holder, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE)
	breathe_tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func spawn_buff_effect(icon_char: String):
	if !is_instance_valid(unit): return
	var effect_node = Node2D.new()
	effect_node.name = "BuffEffect"
	effect_node.z_index = 101

	var lbl = Label.new()
	lbl.text = icon_char
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.position = Vector2(-20, -20)
	lbl.size = Vector2(40, 40)

	effect_node.add_child(lbl)
	unit.add_child(effect_node)

	effect_node.position = Vector2.ZERO

	var tween = unit.create_tween()
	tween.tween_property(effect_node, "scale", Vector2(2.5, 2.5), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(effect_node, "modulate:a", 0.0, 0.6)

	tween.finished.connect(effect_node.queue_free)

func draw_highlight(is_hovered: bool, is_force_highlighted: bool, is_skill_highlight_active: bool, highlight_color: Color):
	if !is_instance_valid(unit): return

	if is_hovered:
		var draw_radius = unit.stats.range_val
		if unit.unit_data.get("attackType") == "melee":
			draw_radius = max(unit.stats.range_val, 100.0)

		unit.draw_circle(Vector2.ZERO, draw_radius, Color(1, 1, 1, 0.1))
		unit.draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)

	if is_skill_highlight_active:
		var size = Vector2(64, 64) # Default Constants.TILE_SIZE
		if unit.unit_data and unit.unit_data.has("size"):
			size = Vector2(unit.unit_data.size.x * 64, unit.unit_data.size.y * 64)

		var rect = Rect2(-size / 2, size)
		unit.draw_rect(rect, highlight_color, false, 4.0)

	if is_force_highlighted:
		var size = Vector2(64, 64)
		if unit.unit_data and unit.unit_data.has("size"):
			size = Vector2(unit.unit_data.size.x * 64, unit.unit_data.size.y * 64)

		var rect = Rect2(-size / 2, size)
		unit.draw_rect(rect, Color.WHITE, false, 4.0)
