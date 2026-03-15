class_name GridInteractionService
extends RefCounted

var grid_manager: Node2D

func _init(owner: Node2D):
	grid_manager = owner

func process(_delta: float):
	if grid_manager.interaction_state == grid_manager.STATE_SELECTING_INTERACTION_TARGET:
		grid_manager.selection_overlay.queue_redraw()

	if grid_manager.interaction_state == grid_manager.STATE_SEQUENCE_TRAP_PLACEMENT:
		process_trap_placement_preview()

	if grid_manager.interaction_state == grid_manager.STATE_SKILL_TARGETING and grid_manager.skill_preview_node and is_instance_valid(grid_manager.skill_preview_node):
		var mouse_pos = grid_manager.get_local_mouse_position()
		var gx = round(mouse_pos.x / grid_manager.TILE_SIZE)
		var gy = round(mouse_pos.y / grid_manager.TILE_SIZE)
		grid_manager.skill_preview_node.position = grid_manager.grid_to_local(Vector2i(gx, gy))

func handle_input(event):
	match grid_manager.interaction_state:
		grid_manager.STATE_SKILL_TARGETING:
			handle_input_skill_targeting(event)
		grid_manager.STATE_SELECTING_INTERACTION_TARGET:
			handle_input_interaction_selection(event)
		grid_manager.STATE_SEQUENCE_TRAP_PLACEMENT:
			handle_input_trap_placement(event)
		grid_manager.STATE_IDLE:
			handle_input_idle(event)
		_:
			handle_input_idle(event)

func handle_input_skill_targeting(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = grid_manager.get_local_mouse_position()
			var gx = int(round(mouse_pos.x / grid_manager.TILE_SIZE))
			var gy = int(round(mouse_pos.y / grid_manager.TILE_SIZE))

			if grid_manager.skill_source_unit and is_instance_valid(grid_manager.skill_source_unit):
				grid_manager.skill_source_unit.execute_skill_at(Vector2i(gx, gy))

			exit_skill_targeting()
			grid_manager.get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			exit_skill_targeting()
			grid_manager.get_viewport().set_input_as_handled()

func handle_input_interaction_selection(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = grid_manager.get_local_mouse_position()
			var gx = int(round(mouse_pos.x / grid_manager.TILE_SIZE))
			var gy = int(round(mouse_pos.y / grid_manager.TILE_SIZE))
			var grid_pos = Vector2i(gx, gy)

			if grid_pos in grid_manager.valid_interaction_targets:
				if grid_manager.interaction_source_unit and is_instance_valid(grid_manager.interaction_source_unit):
					grid_manager.interaction_source_unit.interaction_target_pos = grid_pos
					grid_manager.recalculate_buffs()

					var targets = [grid_pos]
					if grid_manager.interaction_source_unit.unit_data.get("interaction_pattern") == "neighbor_pair":
						var neighbors = grid_manager._get_clockwise_neighbors(grid_manager.interaction_source_unit.grid_pos)
						var idx = neighbors.find(grid_pos)
						if idx != -1:
							var next_idx = (idx + 1) % neighbors.size()
							targets.append(neighbors[next_idx])

					for target_pos in targets:
						var key = grid_manager.get_tile_key(target_pos.x, target_pos.y)
						if grid_manager.tiles.has(key):
							var tile = grid_manager.tiles[key]
							var u = tile.unit
							if u == null and tile.occupied_by != Vector2i.ZERO:
								var origin_key = grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
								if grid_manager.tiles.has(origin_key):
									u = grid_manager.tiles[origin_key].unit

							if u and is_instance_valid(u):
								u.play_buff_receive_anim()
								var buff_icon = grid_manager.grid_buff_service.resolve_buff_icon(grid_manager.interaction_source_unit, grid_manager.interaction_source_unit.get_interaction_info().buff_id)
								u.spawn_buff_effect(buff_icon)

				end_interaction_selection()
				grid_manager.get_viewport().set_input_as_handled()
			else:
				end_interaction_selection()
				grid_manager.get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_deployment_sequence()
			grid_manager.get_viewport().set_input_as_handled()

func handle_input_idle(_event):
	pass

func enter_skill_targeting(unit: Node2D):
	exit_skill_targeting()
	grid_manager.interaction_state = grid_manager.STATE_SKILL_TARGETING
	grid_manager.skill_source_unit = unit

	grid_manager.skill_preview_node = Node2D.new()
	grid_manager.skill_preview_node.name = "SkillPreview"
	grid_manager.skill_preview_node.z_index = 100

	for x in range(-1, 2):
		for y in range(-1, 2):
			var rect = ColorRect.new()
			rect.size = Vector2(grid_manager.TILE_SIZE, grid_manager.TILE_SIZE)
			rect.position = Vector2(x * grid_manager.TILE_SIZE, y * grid_manager.TILE_SIZE) - Vector2(grid_manager.TILE_SIZE/2.0, grid_manager.TILE_SIZE/2.0)
			rect.color = Color(0, 1, 0, 0.4)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_manager.skill_preview_node.add_child(rect)

	grid_manager.add_child(grid_manager.skill_preview_node)

func exit_skill_targeting():
	if grid_manager.skill_preview_node:
		grid_manager.skill_preview_node.queue_free()
		grid_manager.skill_preview_node = null

	grid_manager.interaction_state = grid_manager.STATE_IDLE
	grid_manager.skill_source_unit = null

func start_interaction_selection(unit):
	grid_manager.interaction_state = grid_manager.STATE_SELECTING_INTERACTION_TARGET
	grid_manager.interaction_source_unit = unit
	grid_manager.valid_interaction_targets.clear()

	var cx = unit.grid_pos.x
	var cy = unit.grid_pos.y
	var neighbors = [
		Vector2i(cx - 1, cy - 1),
		Vector2i(cx, cy - 1),
		Vector2i(cx + 1, cy - 1),
		Vector2i(cx - 1, cy),
		Vector2i(cx + 1, cy),
		Vector2i(cx - 1, cy + 1),
		Vector2i(cx, cy + 1),
		Vector2i(cx + 1, cy + 1)
	]

	for pos in neighbors:
		if is_valid_interaction_target(unit, pos):
			grid_manager.valid_interaction_targets.append(pos)
			var color = Color.GREEN
			if unit.unit_data.get("buff_id") == "multishot":
				color = Color(0, 1, 1, 0.4)
			spawn_interaction_highlight(pos, color)
		else:
			spawn_interaction_highlight(pos, Color.RED)

func is_valid_interaction_target(_origin_unit, target_pos: Vector2i) -> bool:
	var key = grid_manager.get_tile_key(target_pos.x, target_pos.y)
	if !grid_manager.tiles.has(key):
		return false
	var tile = grid_manager.tiles[key]
	if !grid_manager.is_in_core_zone(target_pos):
		return false
	if tile.state != "unlocked" and tile.type != "core":
		return false
	return true

func end_interaction_selection():
	grid_manager.interaction_state = grid_manager.STATE_IDLE
	grid_manager.interaction_source_unit = null
	grid_manager.valid_interaction_targets.clear()
	for node in grid_manager.interaction_highlights:
		node.queue_free()
	grid_manager.interaction_highlights.clear()
	grid_manager.selection_overlay.queue_redraw()

func spawn_interaction_highlight(grid_pos: Vector2i, color: Color = Color(1, 0.84, 0, 0.4)):
	var highlight = ColorRect.new()
	highlight.size = Vector2(grid_manager.TILE_SIZE, grid_manager.TILE_SIZE)
	highlight.color = color
	highlight.color.a = 0.4
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_manager.add_child(highlight)

	var local_pos = grid_manager.grid_to_local(grid_pos)
	highlight.position = local_pos - Vector2(grid_manager.TILE_SIZE, grid_manager.TILE_SIZE) / 2
	grid_manager.interaction_highlights.append(highlight)

func on_selection_overlay_draw():
	if grid_manager.interaction_state == grid_manager.STATE_SELECTING_INTERACTION_TARGET and grid_manager.interaction_source_unit and is_instance_valid(grid_manager.interaction_source_unit):
		var mouse_pos = grid_manager.get_local_mouse_position()
		var gx = int(round(mouse_pos.x / grid_manager.TILE_SIZE))
		var gy = int(round(mouse_pos.y / grid_manager.TILE_SIZE))
		var grid_pos = Vector2i(gx, gy)

		var buff_id = grid_manager.interaction_source_unit.get_interaction_info().buff_id
		var icon_char = grid_manager.grid_buff_service.resolve_buff_icon(grid_manager.interaction_source_unit, buff_id)
		var font = ThemeDB.fallback_font
		var font_size = 24

		var draw_positions = []
		var is_valid = grid_pos in grid_manager.valid_interaction_targets
		var color = Color.WHITE

		if is_valid:
			draw_positions.append(grid_pos)
			if grid_manager.interaction_source_unit.unit_data.get("interaction_pattern") == "neighbor_pair":
				var neighbors = grid_manager._get_clockwise_neighbors(grid_manager.interaction_source_unit.grid_pos)
				var idx = neighbors.find(grid_pos)
				if idx != -1:
					var next_idx = (idx + 1) % neighbors.size()
					draw_positions.append(neighbors[next_idx])
		else:
			draw_positions.append(grid_pos)
			color = Color(0.5, 0.5, 0.5, 0.5)

		for pos in draw_positions:
			var snap_pos = grid_manager.grid_to_local(pos)
			grid_manager.selection_overlay.draw_string(font, snap_pos + Vector2(-10, 10), icon_char, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func start_trap_placement_sequence(unit):
	grid_manager.interaction_state = grid_manager.STATE_SEQUENCE_TRAP_PLACEMENT
	grid_manager.interaction_source_unit = unit
	grid_manager.valid_interaction_targets.clear()

func handle_input_trap_placement(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = grid_manager.get_local_mouse_position()
			var gx = int(round(mouse_pos.x / grid_manager.TILE_SIZE))
			var gy = int(round(mouse_pos.y / grid_manager.TILE_SIZE))
			var grid_pos = Vector2i(gx, gy)

			if can_place_trap_at(grid_pos):
				var trap_type = "poison"
				if grid_manager.interaction_source_unit and grid_manager.interaction_source_unit.behavior.has_method("get_trap_type"):
					var t = grid_manager.interaction_source_unit.behavior.get_trap_type()
					if t != "":
						trap_type = t

				grid_manager.spawn_trap_custom(grid_pos, trap_type)
				var trap_node = grid_manager.obstacles.get(grid_pos)
				if trap_node and grid_manager.interaction_source_unit:
					if "associated_traps" in grid_manager.interaction_source_unit:
						grid_manager.interaction_source_unit.associated_traps.append(trap_node)

				end_trap_placement_sequence()

				var next_step_started = false
				if grid_manager.interaction_source_unit and is_instance_valid(grid_manager.interaction_source_unit):
					var info = grid_manager.interaction_source_unit.get_interaction_info()
					if info.has_interaction:
						start_interaction_selection(grid_manager.interaction_source_unit)
						next_step_started = true

				if not next_step_started:
					grid_manager.interaction_state = grid_manager.STATE_IDLE
					grid_manager.interaction_source_unit = null

				grid_manager.get_viewport().set_input_as_handled()
			else:
				grid_manager.get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_deployment_sequence()
			grid_manager.get_viewport().set_input_as_handled()

func process_trap_placement_preview():
	var trap_type = "poison_trap"
	if grid_manager.interaction_source_unit and grid_manager.interaction_source_unit.behavior.has_method("get_trap_type"):
		var t = grid_manager.interaction_source_unit.behavior.get_trap_type()
		if t != "":
			trap_type = t

	var local_mouse = grid_manager.get_local_mouse_position()
	var gx = int(round(local_mouse.x / grid_manager.TILE_SIZE))
	var gy = int(round(local_mouse.y / grid_manager.TILE_SIZE))
	var grid_pos = Vector2i(gx, gy)
	var snapped_local_pos = grid_manager.grid_to_local(grid_pos)
	var snapped_world_pos = grid_manager.to_global(snapped_local_pos)
	grid_manager.update_placement_preview(grid_pos, snapped_world_pos, trap_type)

func can_place_trap_at(grid_pos: Vector2i) -> bool:
	var key = grid_manager.get_tile_key(grid_pos.x, grid_pos.y)
	if !grid_manager.tiles.has(key):
		return false
	var tile = grid_manager.tiles[key]
	if grid_manager.obstacles.has(grid_pos):
		return false
	if tile.unit != null:
		return false
	if tile.occupied_by != Vector2i.ZERO:
		return false
	if tile.type == "core":
		return false
	return true

func end_trap_placement_sequence():
	for node in grid_manager.interaction_highlights:
		node.queue_free()
	grid_manager.interaction_highlights.clear()
	if grid_manager.placement_preview_cursor:
		grid_manager.placement_preview_cursor.visible = false

func cancel_deployment_sequence():
	end_trap_placement_sequence()
	end_interaction_selection()

	if grid_manager.interaction_source_unit and is_instance_valid(grid_manager.interaction_source_unit):
		var u_key = grid_manager.interaction_source_unit.type_key
		var u_cost = grid_manager.interaction_source_unit.unit_data.get("cost", 0)
		grid_manager.remove_unit_from_grid(grid_manager.interaction_source_unit)

		if GameManager.main_game:
			if !GameManager.main_game.add_unit_to_bench(u_key):
				GameManager.add_gold(u_cost)
		else:
			print("MainGame not found, cannot return to bench.")

	grid_manager.interaction_state = grid_manager.STATE_IDLE
	grid_manager.interaction_source_unit = null
