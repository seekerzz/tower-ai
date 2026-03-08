extends Node2D

class_name UnitInteraction

var unit: Node2D
var is_dragging: bool = false
var start_position: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var ghost_node: Node2D = null

var is_hovered: bool = false
var _is_skill_highlight_active: bool = false
var _highlight_color: Color = Color.WHITE
var is_force_highlighted: bool = false

func _init(u: Node2D):
	unit = u
	z_index = unit.z_index + 1

func _ready():
	_connect_signals()
	# Disable _process if not needed
	set_process(false)

func _connect_signals():
	if unit.has_signal("interaction_mouse_entered"):
		unit.interaction_mouse_entered.connect(_on_area_2d_mouse_entered)
	if unit.has_signal("interaction_mouse_exited"):
		unit.interaction_mouse_exited.connect(_on_area_2d_mouse_exited)
	if unit.has_signal("interaction_input_event"):
		unit.interaction_input_event.connect(_on_area_2d_input_event)
	if unit.has_signal("highlight_requested"):
		unit.highlight_requested.connect(set_highlight)
	if unit.has_signal("force_highlight_requested"):
		unit.force_highlight_requested.connect(set_force_highlight)
	if unit.has_signal("drag_started"):
		unit.drag_started.connect(start_drag)

func _on_area_2d_input_event(viewport, event, shape_idx):
	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	if !is_wave_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unit.unit_clicked.emit(unit)

func _on_area_2d_mouse_entered():
	is_hovered = true
	queue_redraw()

	for buff_type in unit.buff_sources:
		var source = unit.buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(true)

	if GameManager.grid_manager and GameManager.grid_manager.has_method("show_provider_icons"):
		GameManager.grid_manager.show_provider_icons(unit)

	var current_stats = {
		"level": unit.level,
		"damage": unit.damage,
		"range": unit.range_val,
		"atk_speed": unit.atk_speed,
		"crit_rate": unit.crit_rate,
		"crit_dmg": unit.crit_dmg
	}
	GameManager.show_tooltip.emit(unit.unit_data, current_stats, unit.active_buffs, unit.global_position)

func _on_area_2d_mouse_exited():
	is_hovered = false
	queue_redraw()

	for buff_type in unit.buff_sources:
		var source = unit.buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(false)

	if GameManager.grid_manager and GameManager.grid_manager.has_method("hide_provider_icons"):
		GameManager.grid_manager.hide_provider_icons()

	GameManager.hide_tooltip.emit()

func set_highlight(active: bool, color: Color = Color.WHITE):
	_is_skill_highlight_active = active
	_highlight_color = color
	queue_redraw()

func set_force_highlight(active: bool):
	is_force_highlighted = active
	queue_redraw()

func _input(event):
	if is_dragging:
		if event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			end_drag()

func start_drag(mouse_pos_global):
	is_dragging = true
	start_position = unit.position
	drag_offset = unit.global_position - mouse_pos_global
	unit.z_index = 100
	create_ghost()

func end_drag():
	is_dragging = false
	unit.z_index = 0
	remove_ghost()

	if GameManager.grid_manager:
		if GameManager.grid_manager.handle_unit_drop(unit):
			return

		var viewport_rect = get_viewport_rect()
		var mouse_pos = get_global_mouse_position()
		if mouse_pos.y > (viewport_rect.size.y - 200):
			var bench_index = _find_empty_bench_slot()
			if bench_index >= 0 and unit.grid_pos != null:
				var result = BoardController.try_move_unit("grid", unit.grid_pos, "bench", bench_index)
				if result.success:
					return
			return_to_start()
			return

	return_to_start()

func create_ghost():
	if ghost_node: return
	ghost_node = Node2D.new()

	var visual_holder = unit.get_node_or_null("VisualHolder")
	if visual_holder:
		var dup_visual = visual_holder.duplicate(7)
		ghost_node.add_child(dup_visual)

	unit.get_parent().add_child(ghost_node)
	ghost_node.position = start_position
	ghost_node.modulate.a = 0.5
	ghost_node.z_index = -1

func remove_ghost():
	if ghost_node:
		ghost_node.queue_free()
		ghost_node = null

func return_to_start():
	unit.position = start_position

func _find_empty_bench_slot() -> int:
	if not GameManager.session_data:
		return -1
	for i in range(Constants.BENCH_SIZE):
		if GameManager.session_data.get_bench_unit(i) == null:
			return i
	return -1

func _draw():
	# Drawing on self, need position relative to parent (unit) to be 0,0
	position = Vector2.ZERO
	if is_hovered:
		var draw_radius = unit.range_val
		if unit.unit_data.get("attackType") == "melee":
			draw_radius = max(unit.range_val, 100.0)

		draw_circle(Vector2.ZERO, draw_radius, Color(1, 1, 1, 0.1))
		draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)

	if _is_skill_highlight_active:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit.unit_data and unit.unit_data.has("size"):
			size = Vector2(unit.unit_data.size.x * Constants.TILE_SIZE, unit.unit_data.size.y * Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		draw_rect(rect, _highlight_color, false, 4.0)

	if is_force_highlighted:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit.unit_data and unit.unit_data.has("size"):
			size = Vector2(unit.unit_data.size.x * Constants.TILE_SIZE, unit.unit_data.size.y * Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		draw_rect(rect, Color.WHITE, false, 4.0)
