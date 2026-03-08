extends Node2D

var unit: Node2D
var visual_holder: Node2D

var breathe_tween: Tween = null
var attack_tween: Tween = null
var damage_tween: Tween = null

var tile_size: float = 60.0
var anim_windup_dist: float = 8.0
var anim_strike_dist: float = 20.0
var anim_windup_time: float = 0.15
var anim_strike_time: float = 0.05
var anim_recovery_time: float = 0.2
var anim_windup_scale: Vector2 = Vector2(1.15, 0.85)
var anim_strike_scale: Vector2 = Vector2(0.85, 1.15)

func _ready():
	unit = get_parent()
	visual_holder = unit.get_node_or_null("VisualHolder")

	if unit.has_signal("damage_taken"):
		unit.damage_taken.connect(_on_damage_taken)

	_ensure_visual_hierarchy()

func _ensure_visual_hierarchy():
	if visual_holder and is_instance_valid(visual_holder):
		return

	visual_holder = unit.get_node_or_null("VisualHolder")
	if !visual_holder:
		visual_holder = Node2D.new()
		visual_holder.name = "VisualHolder"
		unit.add_child(visual_holder)

		var visual_elements = ["Label", "StarLabel"]
		for child_name in visual_elements:
			var child = unit.get_node_or_null(child_name)
			if child:
				unit.remove_child(child)
				visual_holder.add_child(child)

	var highlight = visual_holder.get_node_or_null("HighlightBorder")
	if !highlight:
		highlight = ReferenceRect.new()
		highlight.name = "HighlightBorder"
		highlight.border_width = 4.0
		highlight.editor_only = false
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_holder.add_child(highlight)

	if unit.get("unit_data") != null and unit.unit_data.has("size"):
		var size_val = unit.unit_data["size"]
		var target_size = Vector2(size_val.x * tile_size - 4, size_val.y * tile_size - 4)
		highlight.size = target_size
		highlight.position = -(target_size / 2)

func update_visuals():
	_ensure_visual_hierarchy()
	if !visual_holder: return

	var label = visual_holder.get_node_or_null("Label")
	var star_label = visual_holder.get_node_or_null("StarLabel")

	var icon_texture = null

	var tex_rect = visual_holder.get_node_or_null("TextureRect")
	if !tex_rect:
		tex_rect = TextureRect.new()
		tex_rect.name = "TextureRect"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_holder.add_child(tex_rect)
		if label: visual_holder.move_child(tex_rect, label.get_index())

	if icon_texture:
		tex_rect.texture = icon_texture
		tex_rect.show()
		if label: label.hide()
	else:
		tex_rect.hide()
		if label and unit.get("unit_data") != null:
			label.text = unit.unit_data.get("icon", "?")
			label.show()

	var size = Vector2.ONE
	if unit.get("unit_data") != null:
		size = unit.unit_data.get("size", Vector2.ONE)

	var target_size = Vector2(size.x * tile_size - 4, size.y * tile_size - 4)
	var target_pos = -(target_size / 2)

	if tex_rect:
		tex_rect.size = target_size
		tex_rect.position = target_pos
		tex_rect.pivot_offset = tex_rect.size / 2

	if label:
		label.size = target_size
		label.position = target_pos
		label.pivot_offset = label.size / 2

	if unit.get("level") != null and unit.level > 1:
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

		var size = Vector2(tile_size, tile_size)
		if unit.get("unit_data") != null and unit.unit_data.has("size"):
			size = Vector2(unit.unit_data["size"].x * tile_size, unit.unit_data["size"].y * tile_size)

		buff_container.position = Vector2(-size.x/2, size.y/2 - 20)
		buff_container.size = Vector2(size.x, 15)

		buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.add_child(buff_container)

	for child in buff_container.get_children():
		child.queue_free()

	if unit.get("active_buffs") != null:
		for buff in unit.active_buffs:
			var lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			lbl.text = _get_buff_icon(buff)
			buff_container.add_child(lbl)

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
	if !visual_holder: return

	if breathe_tween: breathe_tween.kill()

	breathe_tween = create_tween().set_loops()
	breathe_tween.tween_property(visual_holder, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE)
	breathe_tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func play_attack_anim(attack_type: String, target_pos: Vector2, duration: float = -1.0):
	if !visual_holder: return

	if breathe_tween: breathe_tween.kill()
	if attack_tween: attack_tween.kill()

	attack_tween = create_tween()

	if attack_type == "melee":
		var dir = (target_pos - unit.global_position).normalized()
		var original_pos = Vector2.ZERO

		attack_tween.tween_property(visual_holder, "position", -dir * anim_windup_dist, anim_windup_time)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(visual_holder, "scale", anim_windup_scale, anim_windup_time)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		attack_tween.tween_property(visual_holder, "position", dir * anim_strike_dist, anim_strike_time)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		attack_tween.parallel().tween_property(visual_holder, "scale", anim_strike_scale, anim_strike_time)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		attack_tween.tween_property(visual_holder, "position", original_pos, anim_recovery_time)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(visual_holder, "scale", Vector2.ONE, anim_recovery_time)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	elif attack_type == "bow":
		var total_time = duration if duration > 0 else 0.5
		var pull_time = total_time * 0.6
		var recover_time = total_time * 0.3

		var dir = (target_pos - unit.global_position).normalized()

		attack_tween.tween_property(visual_holder, "position", -dir * 10.0, pull_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(visual_holder, "scale", Vector2(0.8, 1.2), pull_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		attack_tween.tween_callback(func():
			visual_holder.position = Vector2.ZERO
			visual_holder.scale = Vector2.ONE
		)

		attack_tween.tween_property(visual_holder, "scale", Vector2(1.1, 0.9), recover_time * 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.tween_property(visual_holder, "scale", Vector2.ONE, recover_time * 0.5)

	elif attack_type == "ranged" or attack_type == "lightning":
		attack_tween.tween_property(visual_holder, "scale", Vector2(0.8, 0.8), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)
		attack_tween.parallel().tween_property(visual_holder, "position", Vector2.ZERO, 0.3)

	attack_tween.finished.connect(func(): start_breathe_anim())

func play_damage_bounce():
	if !visual_holder: return

	if damage_tween:
		damage_tween.kill()

	damage_tween = create_tween()
	damage_tween.tween_property(visual_holder, "position", Vector2(randf_range(-2,2), randf_range(-2,2)), 0.05).set_trans(Tween.TRANS_BOUNCE)
	damage_tween.tween_property(visual_holder, "position", Vector2.ZERO, 0.05)

func _on_damage_taken():
	play_damage_bounce()

func play_buff_receive_anim():
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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

	var tween = create_tween()
	tween.tween_property(effect_node, "scale", Vector2(2.5, 2.5), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(effect_node, "modulate:a", 0.0, 0.6)

	tween.finished.connect(effect_node.queue_free)

func play_level_up_anim():
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)

func play_skill_activation_anim():
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1)
