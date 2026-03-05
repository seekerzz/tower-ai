extends RefCounted
class_name InteractController

var unit: Node2D

var interaction_target_pos = null # Vector2i or null
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var ghost_node: Node2D = null
var is_hovered: bool = false
var focus_target: Node2D = null
var focus_stacks: int = 0

func _init():
	pass

func on_drag_start(event: InputEvent):
	is_dragging = true

func on_drag_end():
	is_dragging = false

func _on_area_2d_input_event(viewport, event, shape_idx):
	var GameManager = unit.get_node_or_null("/root/GameManager")
	var is_wave_active = false
	if GameManager and GameManager.session_data:
		is_wave_active = GameManager.session_data.is_wave_active

	if !is_wave_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unit.unit_clicked.emit(unit)

func _on_area_2d_mouse_entered():
	is_hovered = true
	if unit.has_method("queue_redraw"):
		unit.queue_redraw()

	var buff_sources = unit.buff_manager.buff_sources if unit.get("buff_manager") else {}
	for buff_type in buff_sources:
		var source = buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(true)

	var GameManager = unit.get_node_or_null("/root/GameManager")
	if GameManager and GameManager.grid_manager and GameManager.grid_manager.has_method("show_provider_icons"):
		GameManager.grid_manager.show_provider_icons(unit)

	var current_stats = {
		"level": unit.level,
		"damage": unit.stats.damage,
		"range": unit.stats.range_val,
		"atk_speed": unit.stats.atk_speed,
		"crit_rate": unit.stats.crit_rate,
		"crit_dmg": unit.stats.crit_dmg
	}
	var active_buffs = unit.buff_manager.active_buffs if unit.get("buff_manager") else []
	if GameManager:
		GameManager.show_tooltip.emit(unit.unit_data, current_stats, active_buffs, unit.global_position)

func _on_area_2d_mouse_exited():
	is_hovered = false
	if unit.has_method("queue_redraw"):
		unit.queue_redraw()

	var buff_sources = unit.buff_manager.buff_sources if unit.get("buff_manager") else {}
	for buff_type in buff_sources:
		var source = buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(false)

	var GameManager = unit.get_node_or_null("/root/GameManager")
	if GameManager and GameManager.grid_manager and GameManager.grid_manager.has_method("hide_provider_icons"):
		GameManager.grid_manager.hide_provider_icons()

	if GameManager:
		GameManager.hide_tooltip.emit()
