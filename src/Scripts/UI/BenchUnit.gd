extends Control

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var unit_key: String
var bench_index: int

signal drag_started(index)
signal drag_ended

func setup(key: String, index: int):
	unit_key = key
	bench_index = index
	var proto = Constants.UNIT_TYPES[key]

	# Background Panel
	var panel = Panel.new()
	panel.anchors_preset = 15
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 1) # Slightly popped out color
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Visuals (Using existing children or creating new)
	var icon_texture = AssetLoader.get_unit_icon(unit_key) if AssetLoader else null

	if icon_texture:
		# Use TextureRect
		var tex_rect = get_node_or_null("IconTexture")
		if !tex_rect:
			tex_rect = TextureRect.new()
			tex_rect.name = "IconTexture"
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.layout_mode = 1
			tex_rect.anchors_preset = 15
			tex_rect.grow_horizontal = 2
			tex_rect.grow_vertical = 2
			# Add margin
			tex_rect.offset_left = 5
			tex_rect.offset_top = 5
			tex_rect.offset_right = -5
			tex_rect.offset_bottom = -5
			add_child(tex_rect)

		tex_rect.texture = icon_texture
		tex_rect.show()

		# Hide Label if exists
		if has_node("IconLabel"):
			get_node("IconLabel").hide()
	else:
		# Use Label
		var label = get_node_or_null("IconLabel")
		if !label:
			label = Label.new()
			label.name = "IconLabel"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			# Ensure proper centering
			label.layout_mode = 1 # Anchors
			label.anchors_preset = 15 # Full Rect
			label.grow_horizontal = 2
			label.grow_vertical = 2
			# Adjust font size for icon
			label.add_theme_font_size_override("font_size", 42)
			add_child(label)

		label.text = proto.icon
		label.show()

		# Hide TextureRect if exists
		if has_node("IconTexture"):
			get_node("IconTexture").hide()

	custom_minimum_size = Vector2(60, 60)
	mouse_filter = MOUSE_FILTER_PASS

func _get_drag_data(at_position):
	var preview = _create_drag_preview()
	set_drag_preview(preview)

	return {
		"source": "bench",
		"index": bench_index,
		"key": unit_key
	}

func _create_drag_preview() -> Control:
	var preview = Control.new()
	var rect = ColorRect.new()
	rect.size = Vector2(50, 50)
	rect.color = Color(1, 1, 1, 0.5)
	preview.add_child(rect)

	var tex_rect = TextureRect.new()
	var icon_texture = AssetLoader.get_unit_icon(unit_key)
	if icon_texture:
		tex_rect.texture = icon_texture

	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size = rect.size
	preview.add_child(tex_rect)

	preview.z_index = 100 # On top
	return preview
