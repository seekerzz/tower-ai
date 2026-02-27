extends Control

var unit_ref # Reference to the Unit (Node2D)

func setup(unit):
	unit_ref = unit
	if unit_ref.has_signal("merged"):
		unit_ref.merged.connect(_on_units_merged)

	# Match unit size using visual_holder if available
	var color_rect = null
	if unit.has_node("VisualHolder"):
		var vh = unit.get_node("VisualHolder")
		color_rect = vh.get_node_or_null("ColorRect")

	# Fallback if VisualHolder doesn't exist yet or not found (compatibility)
	if !color_rect:
		color_rect = unit.get_node_or_null("ColorRect")

	if color_rect:
		size = color_rect.size
		# position for a Control is relative to parent (Unit).
		# visual_holder is at (0,0). ColorRect is at (-size/2).
		# If we want this DragHandler to cover the unit, it should be at ColorRect's position.
		# Note: unit.get_node("VisualHolder").position is 0,0 usually.
		# unit.get_node("VisualHolder/ColorRect").position is local to holder.

		# If hierarchy is Unit -> VisualHolder -> ColorRect
		# ColorRect global position = Unit.global_position + VisualHolder.position + ColorRect.position
		# DragHandler (child of Unit) position should be VisualHolder.position + ColorRect.position

		var vh_pos = Vector2.ZERO
		if unit.has_node("VisualHolder"):
			vh_pos = unit.get_node("VisualHolder").position

		position = vh_pos + color_rect.position
	else:
		# Fallback size
		size = Vector2(56, 56)
		position = -size / 2

	mouse_filter = MOUSE_FILTER_PASS

func _get_drag_data(at_position):
	if !unit_ref: return null
	if !GameManager.is_wave_active and unit_ref.grid_pos != null:
		var preview = Control.new()
		var rect = ColorRect.new()
		rect.size = size
		rect.color = Color(1, 1, 1, 0.5)
		preview.add_child(rect)

		# Add label?
		var lbl = Label.new()
		if unit_ref.unit_data:
			lbl.text = unit_ref.unit_data.get("icon", "?")
		lbl.size = size
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.add_child(lbl)

		set_drag_preview(preview)

		return {
			"source": "grid",
			"unit": unit_ref,
			"grid_pos": unit_ref.grid_pos
		}
	return null

func _can_drop_data(_at_position, data):
	if !data or !data.has("source"): return false

	if data.source == "inventory" and data.has("item"):
		var id = data.item.get("item_id")
		if id == "meat":
			return true

	if data.source == "bench" or data.source == "grid":
		return true
	return false

func _drop_data(_at_position, data):
	if !unit_ref: return

	if data.source == "inventory" and data.has("item"):
		var id = data.item.get("item_id")
		if id == "meat":
			unit_ref.devour(null)
			if GameManager.inventory_manager:
				GameManager.inventory_manager.remove_item(data.slot_index)
			return

	if !GameManager.grid_manager: return

	var grid_pos = unit_ref.grid_pos
	var target_tile_key = GameManager.grid_manager.get_tile_key(grid_pos.x, grid_pos.y)

	if GameManager.grid_manager.tiles.has(target_tile_key):
		var target_tile = GameManager.grid_manager.tiles[target_tile_key]

		if data.source == "bench":
			GameManager.grid_manager.handle_bench_drop_at(target_tile, data)
		elif data.source == "grid":
			GameManager.grid_manager.handle_grid_move_at(target_tile, data)

func _on_units_merged(consumed_unit):
	if SoulManager:
		SoulManager.add_souls_from_unit_merge({
			"level": consumed_unit.level,
			"type": consumed_unit.type_key
		})

	if unit_ref is UnitWolf and consumed_unit is UnitWolf:
		unit_ref.on_merged_with(consumed_unit)
