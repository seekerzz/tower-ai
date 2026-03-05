extends Control

@onready var container = $PanelContainer/VBoxContainer

var cheat_items = [
	{ "label": "Add Gold (+1000)", "type": "button", "shortcut": KEY_1, "method": "_on_add_gold_pressed" },
	{ "label": "Skip Wave", "type": "button", "shortcut": KEY_2, "method": "_on_skip_wave_pressed" },
	{ "label": "God Mode", "type": "checkbox", "shortcut": KEY_3, "property": "cheat_god_mode" },
	{ "label": "Infinite Resources", "type": "checkbox", "shortcut": KEY_4, "property": "cheat_infinite_resources" },
	{ "label": "Fast Skills (1s)", "type": "checkbox", "shortcut": KEY_5, "property": "cheat_fast_cooldown" }
]

var ui_elements = {} # Map shortcut key or ID to UI element to update state

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Optimize input processing
	set_process_unhandled_input(visible)

	_rebuild_ui()

func _rebuild_ui():
	# Clear existing children of the container
	# Note: Based on previous file, the structure was PanelContainer/VBoxContainer/HBoxContainer/OptionButton...
	# We want to replace the vertical list inside the VBoxContainer with a GridContainer, or replace VBoxContainer itself.
	# The requirements say "Layout: Deprecate original vertical list, create a GridContainer (columns = 2)".
	# To stay safe with scene tree, we will clear VBoxContainer and add a GridContainer inside it,
	# or assuming VBoxContainer is the main holder, we can just replace its children if we want,
	# but GridContainer inside VBoxContainer is safer if there are other things (like Title).
	# However, the previous code had `unit_option` deep inside.
	# Let's clean up `container` (VBoxContainer) and add a GridContainer.

	if !container:
		return

	for child in container.get_children():
		child.queue_free()

	var grid = GridContainer.new()
	grid.columns = 2
	grid.name = "CheatGrid"
	# Make it expand
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(grid)

	for item in cheat_items:
		if item.type == "button":
			var btn = Button.new()
			btn.text = "%s (%s)" % [item.label, OS.get_keycode_string(item.shortcut)]
			btn.pressed.connect(Callable(self, item.method))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(btn)

		elif item.type == "checkbox":
			var chk = CheckBox.new()
			chk.text = "%s (%s)" % [item.label, OS.get_keycode_string(item.shortcut)]
			chk.toggled.connect(func(val): _on_checkbox_toggled(item.property, val))
			# Initialize state
			chk.button_pressed = GameManager.get(item.property)
			chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(chk)

			# Store reference for shortcut updates
			ui_elements[item.shortcut] = chk

func _input(event):
	# Global input for toggle, not affected by set_process_unhandled_input(false)
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		_toggle_visibility()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if visible:
			# Check shortcuts
			for item in cheat_items:
				if event.keycode == item.shortcut:
					if item.type == "button":
						call(item.method)
						# Visual feedback for button
						# (Optional since buttons usually show pressed state only on click)
					elif item.type == "checkbox":
						var current = GameManager.get(item.property)
						var new_val = !current
						_on_checkbox_toggled(item.property, new_val)
						# Update UI
						if ui_elements.has(item.shortcut):
							ui_elements[item.shortcut].button_pressed = new_val

func _toggle_visibility():
	visible = !visible
	get_tree().paused = visible
	set_process_unhandled_input(visible) # Optimization: stop processing input when hidden

	if visible:
		# Refresh UI states in case variables changed externally (unlikely but safe)
		for item in cheat_items:
			if item.type == "checkbox" and ui_elements.has(item.shortcut):
				ui_elements[item.shortcut].button_pressed = GameManager.get(item.property)

func _on_checkbox_toggled(property: String, value: bool):
	GameManager.set(property, value)
	var state = "ON" if value else "OFF"
	print("[Cheat] Set %s to %s" % [property, state])

	# Feedback (using spawn_floating_text if possible, or just print)
	# Since this is a menu, floating text might be behind it or weird, but let's try or just rely on the CheckBox check.
	# CheckBox check is sufficient visual feedback for toggle.

func _on_add_gold_pressed():
	GameManager.add_gold(1000)
	print("[Cheat] Added 1000 Gold")
	_show_feedback("Added Gold!")

func _on_skip_wave_pressed():
	if GameManager.main_game and GameManager.main_game.has_method("skip_wave"):
		GameManager.main_game.skip_wave()
		print("[Cheat] Skipped Wave")
		_show_feedback("Wave Skipped!")
	else:
		print("[Cheat] skip_wave not found on GameManager.main_game")

func _show_feedback(text: String):
	# Simple feedback: Print is done.
	# Maybe spawn text at mouse position or center?
	# Since the menu handles input, we can assume mouse is over the menu or somewhere.
	# But creating a Label on the fly inside the menu is also fine.
	pass
