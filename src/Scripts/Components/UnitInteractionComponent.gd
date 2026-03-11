extends RefCounted
class_name UnitInteractionComponent

var unit: Node2D

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var ghost_node: Node2D = null
var is_hovered: bool = false
var start_position: Vector2 = Vector2.ZERO

func _init(target_unit: Node2D):
	unit = target_unit

func handle_input(event):
	if is_dragging:
		if event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			end_drag()

func on_area_2d_input_event(viewport, event, shape_idx):
	if !GameManager.is_wave_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unit.unit_clicked.emit(unit)

func on_area_2d_mouse_entered():
	is_hovered = true
	unit.queue_redraw()

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

func on_area_2d_mouse_exited():
	is_hovered = false
	unit.queue_redraw()

	for buff_type in unit.buff_sources:
		var source = unit.buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(false)

	if GameManager.grid_manager and GameManager.grid_manager.has_method("hide_provider_icons"):
		GameManager.grid_manager.hide_provider_icons()

	GameManager.hide_tooltip.emit()

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

		var viewport_rect = unit.get_viewport_rect()
		var mouse_pos = unit.get_global_mouse_position()
		if mouse_pos.y > (viewport_rect.size.y - 200):
			var bench_index = _find_empty_bench_slot()
			if bench_index >= 0 and unit.grid_pos != null:
				var BoardController = unit.get_node_or_null("/root/BoardController")
				if BoardController:
					var result = BoardController.try_move_unit("grid", unit.grid_pos, "bench", bench_index)
					if result.success:
						return
			return_to_start()
			return

	return_to_start()

func create_ghost():
	if ghost_node: return
	ghost_node = Node2D.new()

	if unit.visual_holder:
		var dup_visual = unit.visual_holder.duplicate(7)
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
	if not GameManager.get("session_data"):
		return -1
	for i in range(Constants.BENCH_SIZE):
		if GameManager.session_data.get_bench_unit(i) == null:
			return i
	return -1
