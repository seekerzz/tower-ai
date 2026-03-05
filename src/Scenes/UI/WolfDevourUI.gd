class_name WolfDevourUI
extends Control

var wolf_unit: Unit
var selectable_units: Array[Unit] = []
var selected_unit: Unit = null

@onready var panel = $Panel
@onready var unit_list = $Panel/ScrollContainer/UnitList

func show_for_wolf(wolf: Unit):
	wolf_unit = wolf
	_populate_unit_list()
	visible = true
	# Pause the game to allow selection
	get_tree().paused = true

func _populate_unit_list():
	# Clear old items
	for child in unit_list.get_children():
		child.queue_free()

	selectable_units.clear()

	if not GameManager.grid_manager:
		_show_no_target_message()
		return

	var wolf_pos = wolf_unit.global_position
	# Find units within 120 distance
	var nearby_units = []

	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		var unit = tile.unit
		# Handle large units occupying multiple tiles (check only main tile or check against list to avoid dupes)
		if unit and unit != wolf_unit and is_instance_valid(unit) and not (unit in nearby_units):
			var dist = wolf_pos.distance_to(unit.global_position)
			if dist <= 120:
				nearby_units.append(unit)

	if nearby_units.is_empty():
		_show_no_target_message()
		return

	for unit in nearby_units:
		selectable_units.append(unit)
		_create_unit_button(unit)

func _create_unit_button(unit: Unit):
	var btn = Button.new()
	btn.text = "%s (Lv.%d)" % [unit.unit_data.get("name", unit.type_key.capitalize()), unit.level]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Show buff icons if any relevant buffs
	var buff_text = ""
	for buff in unit.active_buffs:
		var icon = unit._get_buff_icon(buff)
		if icon != "?":
			buff_text += " " + icon

	if buff_text != "":
		btn.text += buff_text

	btn.custom_minimum_size.y = 40
	btn.pressed.connect(_on_unit_selected.bind(unit))
	unit_list.add_child(btn)

func _show_no_target_message():
	var label = Label.new()
	label.text = "No prey nearby...\n(Auto-select nearest)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unit_list.add_child(label)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(_on_cancel)
	unit_list.add_child(confirm_btn)

func _on_unit_selected(unit: Unit):
	selected_unit = unit
	_close_and_devour()

func _on_cancel():
	selected_unit = null
	_close_ui()

func _close_and_devour():
	_close_ui()
	if wolf_unit and is_instance_valid(wolf_unit) and selected_unit:
		wolf_unit.devour_target(selected_unit)
	elif wolf_unit and is_instance_valid(wolf_unit):
		# Fallback if selected_unit is null (e.g. from cancel but logic might differ)
		# The prompt says: "If no target selected, auto select nearest" in UnitWolf logic usually,
		# but here if we explicitly cancel, we might want to trigger auto-devour or just close.
		# UnitWolf will handle the "no selection" case.
		pass

func _close_ui():
	visible = false
	get_tree().paused = false
	queue_free()

func _exit_tree():
	if get_tree() and get_tree().paused:
		get_tree().paused = false
