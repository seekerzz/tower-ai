extends MarginContainer

const UIConstants = preload("res://src/Scripts/Constants/UIConstants.gd")

var artifacts_container: GridContainer

func _ready():
	# Create internal container
	artifacts_container = GridContainer.new()
	artifacts_container.columns = 5
	add_child(artifacts_container)
	artifacts_container.add_theme_constant_override("h_separation", 5)
	artifacts_container.add_theme_constant_override("v_separation", 5)

	# Connect to RewardManager
	var rm = GameManager.get("reward_manager")
	if not rm and GameManager.has_meta("reward_manager"):
		rm = GameManager.get_meta("reward_manager")

	if rm:
		if not rm.reward_added.is_connected(_on_reward_added):
			rm.reward_added.connect(_on_reward_added)
		if rm.has_signal("sacrifice_state_changed"):
			if not rm.sacrifice_state_changed.is_connected(_on_sacrifice_state_changed):
				rm.sacrifice_state_changed.connect(_on_sacrifice_state_changed)

	update_display()

func _on_reward_added(_id):
	update_display()

func _on_sacrifice_state_changed(_is_active):
	update_display()

func update_display():
	if not artifacts_container: return

	for child in artifacts_container.get_children():
		child.queue_free()

	var rm = GameManager.get("reward_manager")
	if not rm and GameManager.has_meta("reward_manager"):
		rm = GameManager.get_meta("reward_manager")

	if not rm: return

	# 1. Process Active Buffs (Stats)
	for buff_id in rm.active_buffs:
		_create_hud_icon(buff_id, rm.active_buffs[buff_id], rm)

	# 2. Process Artifacts
	for artifact_id in rm.acquired_artifacts:
		_create_hud_icon(artifact_id, 1, rm)

func _create_hud_icon(id, count, rm):
	if not rm.REWARDS.has(id): return

	var data = rm.REWARDS[id]
	var icon_container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = UIConstants.COLORS.panel_bg
	style.set_corner_radius_all(UIConstants.CORNER_RADIUS.small)
	icon_container.add_theme_stylebox_override("panel", style)

	# Container settings
	icon_container.custom_minimum_size = UIConstants.CARD_SIZE.small
	icon_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var label = Label.new()
	label.text = data.get("icon", "?")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.tooltip_text = data.get("name", id) + "\n" + data.get("desc", "")

	# Use a MarginContainer to center the label and allow overlay
	var margin = MarginContainer.new()
	margin.add_child(label)
	icon_container.add_child(margin)

	# Stack count
	if count > 1:
		var count_label = Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 10)

		var count_container = MarginContainer.new()
		count_container.add_theme_constant_override("margin_left", 22)
		count_container.add_theme_constant_override("margin_top", 22)
		count_container.add_child(count_label)

		margin.add_child(count_container)

	# Interaction for Sacrifice Protocol
	if id == "sacrifice_protocol":
		icon_container.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_container.gui_input.connect(_on_sacrifice_icon_input)

		# Visual feedback for cooldown
		if rm.sacrifice_cooldown > 0:
			label.modulate = Color(0.5, 0.5, 0.5, 0.5) # Greyed out
		elif rm.is_sacrifice_active:
			label.modulate = Color(1, 0, 0) # Red glow/active?

	artifacts_container.add_child(icon_container)

func _on_sacrifice_icon_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rm = GameManager.get("reward_manager")
		if not rm and GameManager.has_meta("reward_manager"):
			rm = GameManager.get_meta("reward_manager")

		if rm:
			rm.activate_sacrifice()
