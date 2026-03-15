extends RefCounted
class_name UnitVisualComponent

var unit: Node2D

var breathe_tween: Tween = null
var attack_tween: Tween = null
var _is_skill_highlight_active: bool = false
var _highlight_color: Color = Color.WHITE
var is_force_highlighted: bool = false

func _init(target_unit: Node2D):
	unit = target_unit

func ensure_visual_hierarchy():
	if unit.visual_holder and is_instance_valid(unit.visual_holder):
		return

	unit.visual_holder = unit.get_node_or_null("VisualHolder")
	if !unit.visual_holder:
		unit.visual_holder = Node2D.new()
		unit.visual_holder.name = "VisualHolder"
		unit.add_child(unit.visual_holder)

		var visual_elements = ["Label", "StarLabel"]
		for child_name in visual_elements:
			var child = unit.get_node_or_null(child_name)
			if child:
				unit.remove_child(child)
				unit.visual_holder.add_child(child)

	var highlight = unit.visual_holder.get_node_or_null("HighlightBorder")
	if !highlight:
		highlight = ReferenceRect.new()
		highlight.name = "HighlightBorder"
		highlight.border_width = 4.0
		highlight.editor_only = false
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.visual_holder.add_child(highlight)

	var target_size = Vector2(Constants.TILE_SIZE - 4, Constants.TILE_SIZE - 4)
	highlight.size = target_size
	highlight.position = -(target_size / 2)

func set_skill_highlight(active: bool, color: Color = Color.WHITE):
	_is_skill_highlight_active = active
	_highlight_color = color
	unit.queue_redraw()

func set_force_highlight(active: bool):
	is_force_highlighted = active
	unit.queue_redraw()

func draw_overlays():
	if unit.is_hovered:
		var draw_radius = unit.range_val
		if unit.unit_data.get("attackType") == "melee":
			draw_radius = max(unit.range_val, 100.0)

		unit.draw_circle(Vector2.ZERO, draw_radius, Color(1, 1, 1, 0.1))
		unit.draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)

	if _is_skill_highlight_active:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		unit.draw_rect(rect, _highlight_color, false, 4.0)

	if is_force_highlighted:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		unit.draw_rect(rect, Color.WHITE, false, 4.0)

func update_visuals():
	ensure_visual_hierarchy()
	var label = unit.visual_holder.get_node_or_null("Label")
	var star_label = unit.visual_holder.get_node_or_null("StarLabel")

	var AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")
	var icon_texture = AssetLoader.get_unit_icon(unit.type_key)

	var tex_rect = unit.visual_holder.get_node_or_null("TextureRect")
	if !tex_rect:
		tex_rect = TextureRect.new()
		tex_rect.name = "TextureRect"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.visual_holder.add_child(tex_rect)
		if label: unit.visual_holder.move_child(tex_rect, label.get_index())

	if icon_texture:
		tex_rect.texture = icon_texture
		tex_rect.show()
		if label: label.hide()
	else:
		tex_rect.hide()
		if label:
			label.text = unit.unit_data.icon
			label.show()

	var target_size = Vector2(Constants.TILE_SIZE - 4, Constants.TILE_SIZE - 4)
	var target_pos = -(target_size / 2)

	if tex_rect:
		tex_rect.size = target_size
		tex_rect.position = target_pos
		tex_rect.pivot_offset = tex_rect.size / 2

	if label:
		label.size = target_size
		label.position = target_pos
		label.pivot_offset = label.size / 2

	if unit.level > 1:
		if star_label:
			star_label.text = "⭐%d" % unit.level
			star_label.show()
	else:
		if star_label:
			star_label.hide()

	_update_buff_icons()

func _update_buff_icons():
	var buff_container = unit.get_node_or_null("BuffContainer")
	if !buff_container:
		buff_container = HBoxContainer.new()
		buff_container.name = "BuffContainer"
		buff_container.alignment = BoxContainer.ALIGNMENT_CENTER

		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)

		buff_container.position = Vector2(-size.x/2, size.y/2 - 20)
		buff_container.size = Vector2(size.x, 15)

		buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.add_child(buff_container)

	for child in buff_container.get_children():
		child.queue_free()

	for buff in unit.active_buffs:
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		lbl.text = _get_buff_icon(buff)
		buff_container.add_child(lbl)

func get_buff_icon(buff_type: String) -> String:
	return _get_buff_icon(buff_type)

func _get_buff_icon(buff_type: String) -> String:
	match buff_type:
		"fire": return "🔥"
		"poison": return "🧪"
		"range": return "🔭"
		"speed": return "⚡"
		"crit": return "💥"
		"bounce": return "🪞"
		"split": return "💠"
		"multishot": return "📶"
		"wealth": return "💰"
	return "?"

func start_breathe_anim():
	if !unit.visual_holder: return

	if breathe_tween: breathe_tween.kill()

	breathe_tween = unit.create_tween().set_loops()
	breathe_tween.tween_property(unit.visual_holder, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE)
	breathe_tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func play_attack_anim(attack_type: String, target_pos: Vector2, duration: float = -1.0):
	if !unit.visual_holder: return

	if breathe_tween: breathe_tween.kill()
	if attack_tween: attack_tween.kill()

	attack_tween = unit.create_tween()

	if attack_type == "melee":
		var dir = (target_pos - unit.global_position).normalized()
		var original_pos = Vector2.ZERO

		attack_tween.tween_property(unit.visual_holder, "position", -dir * Constants.ANIM_WINDUP_DIST, Constants.ANIM_WINDUP_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(unit.visual_holder, "scale", Constants.ANIM_WINDUP_SCALE, Constants.ANIM_WINDUP_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		attack_tween.tween_property(unit.visual_holder, "position", dir * Constants.ANIM_STRIKE_DIST, Constants.ANIM_STRIKE_TIME)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		attack_tween.parallel().tween_property(unit.visual_holder, "scale", Constants.ANIM_STRIKE_SCALE, Constants.ANIM_STRIKE_TIME)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		attack_tween.tween_property(unit.visual_holder, "position", original_pos, Constants.ANIM_RECOVERY_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(unit.visual_holder, "scale", Vector2.ONE, Constants.ANIM_RECOVERY_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	elif attack_type == "bow":
		var total_time = duration if duration > 0 else 0.5
		var pull_time = total_time * 0.6
		var recover_time = total_time * 0.3

		var dir = (target_pos - unit.global_position).normalized()

		attack_tween.tween_property(unit.visual_holder, "position", -dir * 10.0, pull_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


func play_buff_receive_anim():
	ensure_visual_hierarchy()
	if unit.visual_holder:
		var tween = unit.create_tween()
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func spawn_buff_effect(icon_char: String):
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

func play_damage_hit_anim():
	if unit.visual_holder:
		var tween = unit.create_tween()
		tween.tween_property(unit.visual_holder, "position", Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.05).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(unit.visual_holder, "position", Vector2.ZERO, 0.05)

func play_skill_cast_anim():
	if unit.visual_holder:
		var tween = unit.create_tween()
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.1)

func play_level_up_anim():
	if unit.visual_holder:
		var tween = unit.create_tween()
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.2)
