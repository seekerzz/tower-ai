class_name GridBuffService
extends RefCounted

var grid_manager: Node2D

func _init(owner: Node2D):
	grid_manager = owner

func recalculate_buffs():
	var processed_units = []
	for key in grid_manager.tiles:
		var tile = grid_manager.tiles[key]
		if tile.unit and not (tile.unit in processed_units):
			tile.unit.reset_stats()
			processed_units.append(tile.unit)

	for unit in processed_units:
		if unit.behavior:
			unit.behavior.broadcast_buffs()

		# Interaction Buffs
		var info = unit.get_interaction_info()
		if info.has_interaction and unit.interaction_target_pos != null:
			if grid_manager.is_neighbor(unit, unit.interaction_target_pos):
				apply_buff_to_specific_pos(unit.interaction_target_pos, info.buff_id, unit)

				if unit.unit_data.get("interaction_pattern") == "neighbor_pair":
					var neighbors = grid_manager._get_clockwise_neighbors(unit.grid_pos)
					var idx = neighbors.find(unit.interaction_target_pos)
					if idx != -1:
						var next_idx = (idx + 1) % neighbors.size()
						apply_buff_to_specific_pos(neighbors[next_idx], info.buff_id, unit)

	for unit in processed_units:
		unit.update_visuals()

	grid_manager.grid_updated.emit()

func apply_buff_to_specific_pos(target_pos: Vector2i, buff_id: String, provider_unit: Node2D = null):
	var key = grid_manager.get_tile_key(target_pos.x, target_pos.y)
	if grid_manager.tiles.has(key):
		var tile = grid_manager.tiles[key]
		var target_unit = tile.unit
		if target_unit == null and tile.occupied_by != Vector2i.ZERO:
			var origin_key = grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
			if grid_manager.tiles.has(origin_key):
				target_unit = grid_manager.tiles[origin_key].unit

		if target_unit:
			target_unit.apply_buff(buff_id, provider_unit)


func apply_buff_to_neighbors(provider_unit, buff_type):
	var cx = provider_unit.grid_pos.x
	var cy = provider_unit.grid_pos.y
	var w = provider_unit.unit_data.size.x
	var h = provider_unit.unit_data.size.y
	var neighbors = []

	for dx in range(w):
		neighbors.append(Vector2i(cx + dx, cy - 1))
		neighbors.append(Vector2i(cx + dx, cy + h))

	for dy in range(h):
		neighbors.append(Vector2i(cx - 1, cy + dy))
		neighbors.append(Vector2i(cx + w, cy + dy))

	for n_pos in neighbors:
		var n_key = grid_manager.get_tile_key(n_pos.x, n_pos.y)
		if grid_manager.tiles.has(n_key):
			var tile = grid_manager.tiles[n_key]
			var target_unit = tile.unit
			if target_unit == null and tile.occupied_by != Vector2i.ZERO:
				var origin_key = grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if grid_manager.tiles.has(origin_key):
					target_unit = grid_manager.tiles[origin_key].unit
			if target_unit and target_unit != provider_unit:
				target_unit.apply_buff(buff_type, provider_unit)

func resolve_buff_icon(source_unit: Node2D, buff_id: String) -> String:
	if source_unit and source_unit.has_method("get_buff_icon"):
		return source_unit.get_buff_icon(buff_id)
	return "?"

func show_provider_icons(provider_unit: Node2D):
	hide_provider_icons()
	if !provider_unit:
		return

	var buff_type = ""
	if "buffProvider" in provider_unit.unit_data:
		buff_type = provider_unit.unit_data["buffProvider"]

	var info = provider_unit.get_interaction_info()
	if info.has_interaction:
		if provider_unit.interaction_target_pos != null:
			spawn_provider_icon_at(provider_unit.interaction_target_pos, info.buff_id, provider_unit)
			return

	if buff_type == "":
		return

	var cx = provider_unit.grid_pos.x
	var cy = provider_unit.grid_pos.y
	var w = provider_unit.unit_data.size.x
	var h = provider_unit.unit_data.size.y

	var neighbors = []
	for dx in range(w):
		neighbors.append(Vector2i(cx + dx, cy - 1))
		neighbors.append(Vector2i(cx + dx, cy + h))
	for dy in range(h):
		neighbors.append(Vector2i(cx - 1, cy + dy))
		neighbors.append(Vector2i(cx + w, cy + dy))

	for n_pos in neighbors:
		spawn_provider_icon_at(n_pos, buff_type, provider_unit)

func spawn_provider_icon_at(grid_pos: Vector2i, buff_type: String, provider_unit: Node2D):
	var key = grid_manager.get_tile_key(grid_pos.x, grid_pos.y)
	if grid_manager.tiles.has(key):
		var tile = grid_manager.tiles[key]
		var target_unit = tile.unit
		if target_unit == null and tile.occupied_by != Vector2i.ZERO:
			var origin_key = grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
			if grid_manager.tiles.has(origin_key):
				target_unit = grid_manager.tiles[origin_key].unit

		if target_unit and target_unit != provider_unit:
			var received = false
			if target_unit.buff_sources.has(buff_type):
				if target_unit.buff_sources[buff_type] == provider_unit:
					received = true

			if not received:
				return

			var lbl = Label.new()
			lbl.text = resolve_buff_icon(provider_unit, buff_type)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			lbl.position = grid_manager.grid_to_local(grid_pos) - Vector2(20, 20)
			lbl.size = Vector2(40, 40)

			grid_manager.provider_icon_overlay.add_child(lbl)

func hide_provider_icons():
	for child in grid_manager.provider_icon_overlay.get_children():
		child.queue_free()
