extends Node2D

var unit: Node2D

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var ghost_node: Node2D = null
var start_position: Vector2 = Vector2.ZERO

var is_hovered: bool = false
var _is_skill_highlight_active: bool = false
var _highlight_color: Color = Color.WHITE
var is_force_highlighted: bool = false

var tile_size: float = 60.0
var bench_size: int = 8

signal tooltip_requested(unit_data, current_stats, active_buffs, global_pos)
signal tooltip_hidden()
signal provider_icons_requested(unit)
signal provider_icons_hidden()
signal grid_drop_requested(unit)
signal bench_drop_requested(unit, grid_pos, bench_index)

func _ready():
	unit = get_parent()

	if unit.has_signal("mouse_entered"):
		unit.mouse_entered.connect(_on_area_2d_mouse_entered)
	if unit.has_signal("mouse_exited"):
		unit.mouse_exited.connect(_on_area_2d_mouse_exited)

func _on_area_2d_mouse_entered():
	is_hovered = true
	queue_redraw()

	if unit.get("buff_sources") != null:
		for buff_type in unit.buff_sources:
			var source = unit.buff_sources[buff_type]
			if is_instance_valid(source) and source.has_method("set_force_highlight"):
				source.set_force_highlight(true)

	provider_icons_requested.emit(unit)

	var current_stats = {
		"level": unit.level,
		"damage": unit.damage,
		"range": unit.range_val,
		"atk_speed": unit.atk_speed,
		"crit_rate": unit.crit_rate,
		"crit_dmg": unit.crit_dmg
	}
	var ud = unit.get("unit_data") if unit.get("unit_data") != null else {}
	var buffs = unit.get("active_buffs") if unit.get("active_buffs") != null else []
	tooltip_requested.emit(ud, current_stats, buffs, unit.global_position)

func _on_area_2d_mouse_exited():
	is_hovered = false
	queue_redraw()

	if unit.get("buff_sources") != null:
		for buff_type in unit.buff_sources:
			var source = unit.buff_sources[buff_type]
			if is_instance_valid(source) and source.has_method("set_force_highlight"):
				source.set_force_highlight(false)

	provider_icons_hidden.emit()
	tooltip_hidden.emit()

func set_highlight(active: bool, color: Color = Color.WHITE):
	_is_skill_highlight_active = active
	_highlight_color = color
	queue_redraw()

func set_force_highlight(active: bool):
	is_force_highlighted = active
	queue_redraw()

func _draw():
	if !unit: return

	if is_hovered:
		var draw_radius = unit.range_val
		if unit.get("unit_data") != null and unit.unit_data.get("attackType") == "melee":
			draw_radius = max(draw_radius, 100.0)

		draw_circle(Vector2.ZERO, draw_radius, Color(1, 1, 1, 0.1))
		draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)

	var u_size = Vector2(tile_size, tile_size)
	if unit.get("unit_data") != null and unit.unit_data.has("size"):
		u_size = Vector2(unit.unit_data.size.x * tile_size, unit.unit_data.size.y * tile_size)

	if _is_skill_highlight_active:
		var rect = Rect2(-u_size / 2, u_size)
		draw_rect(rect, _highlight_color, false, 4.0)

	if is_force_highlighted:
		var rect = Rect2(-u_size / 2, u_size)
		draw_rect(rect, Color.WHITE, false, 4.0)

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

	grid_drop_requested.emit(unit)

func create_ghost():
	if ghost_node: return
	ghost_node = Node2D.new()

	if unit.get("visual_holder") != null:
		var dup_visual = unit.visual_holder.duplicate(7)
		ghost_node.add_child(dup_visual)

	unit.get_parent().add_child(ghost_node)
	ghost_node.position = start_position
	ghost_node.modulate.a = 0.5
	ghost_node.z_index = -1

func remove_ghost():
	if ghost_node:
		if is_instance_valid(ghost_node):
			ghost_node.queue_free()
		ghost_node = null

func return_to_start():
	unit.position = start_position
