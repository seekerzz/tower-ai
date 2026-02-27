extends Control

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")
const UIConstants = preload("res://src/Scripts/Constants/UIConstants.gd")
const StyleMaker = preload("res://src/Scripts/Utils/StyleMaker.gd")

@onready var container = $PanelContainer/GridContainer

var skill_units = []

func _ready():
	# Ensure the container is set up correctly
	if container:
		container.add_theme_constant_override("h_separation", 10)
		container.add_theme_constant_override("v_separation", 10)
		var parent = container.get_parent()
		if parent is PanelContainer:
			var style = StyleBoxEmpty.new()
			parent.add_theme_stylebox_override("panel", style)

	# Wait for grid to be ready
	await get_tree().create_timer(0.1).timeout

	if GameManager.grid_manager:
		if !GameManager.grid_manager.grid_updated.is_connected(refresh_skills):
			GameManager.grid_manager.grid_updated.connect(refresh_skills)

	refresh_skills()
	GameManager.unit_purchased.connect(func(_u): refresh_skills())
	GameManager.unit_sold.connect(func(_u): refresh_skills())

func refresh_skills():
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	skill_units.clear()

	if !GameManager.grid_manager: return

	# Scan grid for units with skills
	var units_with_skills = []
	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		if tile.unit and tile.unit.unit_data.has("skill"):
			if tile.unit.type_key == "viper" or tile.unit.type_key == "scorpion":
				continue
			units_with_skills.append(tile.unit)

	# Create Cards
	var hotkeys = ["Q", "W", "E", "R", "D", "F"]

	for i in range(units_with_skills.size()):
		var unit = units_with_skills[i]
		skill_units.append(unit)

		# Base Card (PanelContainer)
		var card = PanelContainer.new()
		# Use correct size flag for Godot 4
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 80 # Height fixed, width expands
		card.name = "SkillCard_%d" % i

		# Style
		var bg_color = UIConstants.COLORS.dark_bg # Dark background
		var style = StyleMaker.get_flat_style(bg_color, UIConstants.CORNER_RADIUS.large, 2, UIConstants.COLORS.primary) # Blue border default
		card.add_theme_stylebox_override("panel", style)

		# Layout Container
		var layout = Control.new()
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(layout)

		# Icon (Center)
		var icon_tex = AssetLoader.get_unit_icon(unit.type_key) if AssetLoader else null
		# Always create TextureRect, even if texture is null (as per requirements)
		var icon_rect = TextureRect.new()
		if icon_tex:
			icon_rect.texture = icon_tex

		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Make it fill a good portion of the card height
		icon_rect.custom_minimum_size = Vector2(50, 50)
		icon_rect.size = Vector2(50, 50)
		# Re-center with offsets
		icon_rect.offset_left = -25
		icon_rect.offset_top = -25
		icon_rect.offset_right = 25
		icon_rect.offset_bottom = 25

		# Set pivot for animation
		icon_rect.pivot_offset = Vector2(25, 25)

		# Set Name for retrieval
		icon_rect.name = "Icon"

		layout.add_child(icon_rect)

		# Hotkey (Top Right)
		var hotkey_lbl = Label.new()
		var key_text = ""
		if i < hotkeys.size():
			key_text = hotkeys[i]

		hotkey_lbl.text = key_text
		hotkey_lbl.add_theme_font_size_override("font_size", 14)
		hotkey_lbl.add_theme_color_override("font_color", Color.WHITE)
		hotkey_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		# Add margins manually via offsets since it's a Control child
		hotkey_lbl.offset_left = -25
		hotkey_lbl.offset_top = 5
		hotkey_lbl.offset_right = -5
		hotkey_lbl.offset_bottom = 25
		hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hotkey_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(hotkey_lbl)

		# Cost (Bottom Right - inside cell)
		var cost_lbl = Label.new()
		cost_lbl.name = "CostLabel"
		cost_lbl.text = "💧%d" % unit.skill_mana_cost
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

		cost_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cost_lbl.offset_left = -60
		cost_lbl.offset_top = -25
		cost_lbl.offset_right = -5
		cost_lbl.offset_bottom = -2

		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(cost_lbl)

		# Cooldown Overlay
		var cd_bar = TextureProgressBar.new()
		cd_bar.name = "CD_Overlay"
		cd_bar.nine_patch_stretch = true
		cd_bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		cd_bar.value = 0
		cd_bar.max_value = 100
		cd_bar.step = 0.01 # Smooth progress
		cd_bar.tint_progress = Color(0, 0, 0, 0.7) # Semi-transparent black
		cd_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Create a white 1x1 texture for the progress
		var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var placeholder = ImageTexture.create_from_image(img)
		cd_bar.texture_progress = placeholder

		layout.add_child(cd_bar)

		# Interaction
		card.gui_input.connect(func(ev): _on_card_gui_input(ev, unit))

		container.add_child(card)

func _on_card_gui_input(event, unit):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_skill_btn_pressed(unit)

func _process(_delta):
	for i in range(skill_units.size()):
		var unit = skill_units[i]
		# Ensure we have the child
		if i >= container.get_child_count(): break

		var card = container.get_child(i)
		# layout is the first child
		if card.get_child_count() == 0: continue
		var layout = card.get_child(0)
		var cd_bar = layout.get_node("CD_Overlay")
		var cost_lbl = layout.get_node("CostLabel")

		var prev_cd = card.get_meta("prev_cd", 0.0)
		var current_cd = unit.skill_cooldown

		# Trigger flash if CD just finished (went from >0 to 0)
		if prev_cd > 0 and current_cd <= 0:
			_trigger_flash(card)

		card.set_meta("prev_cd", current_cd)

		# Cooldown Logic
		if unit.skill_cooldown > 0:
			var max_cd = unit.unit_data.get("skillCd", 10.0)
			cd_bar.visible = true
			cd_bar.max_value = max_cd
			cd_bar.value = unit.skill_cooldown # Remaining time
		else:
			cd_bar.visible = false

		# Mana Logic & Styling
		var style = card.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			# Check Mana
			if GameManager.mana < unit.skill_mana_cost:
				if unit.skill_cooldown <= 0:
					# No mana but ready -> Grey out / Red Border
					card.modulate = Color(0.6, 0.6, 0.6)
					style.border_color = UIConstants.COLORS.danger # Red
					cost_lbl.add_theme_color_override("font_color", UIConstants.COLORS.danger)
				else:
					# Cooldown and no mana -> Just keep normal grey (handled by overlay mostly, but set border to grey)
					card.modulate = Color.WHITE
					style.border_color = Color("#95a5a6") # Grey border
					cost_lbl.add_theme_color_override("font_color", UIConstants.COLORS.danger)
			else:
				# Enough mana
				card.modulate = Color.WHITE
				style.border_color = UIConstants.COLORS.primary # Blue
				cost_lbl.remove_theme_color_override("font_color") # Default

func _trigger_flash(card):
	if !card.has_meta("flashing") or !card.get_meta("flashing"):
		card.set_meta("flashing", true)

		var tween = create_tween()
		tween.tween_property(card, "modulate", Color(2.0, 2.0, 2.0), 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(card, "modulate", Color.WHITE, 0.1).set_trans(Tween.TRANS_SINE)

		tween.finished.connect(func(): card.set_meta("flashing", false))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and !event.echo:
		var index = -1
		match event.keycode:
			KEY_Q: index = 0
			KEY_W: index = 1
			KEY_E: index = 2
			KEY_R: index = 3
			KEY_D: index = 4
			KEY_F: index = 5

		if index != -1 and index < skill_units.size():
			_on_skill_btn_pressed(skill_units[index])

func _on_skill_btn_pressed(unit):
	unit.activate_skill()
