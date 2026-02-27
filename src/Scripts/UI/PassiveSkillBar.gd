extends Control

const StyleMaker = preload("res://src/Scripts/Utils/StyleMaker.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var container: VBoxContainer
@onready var panel_container = $PanelContainer

var monitored_units = []

func _ready():
	# Dynamically replace GridContainer with VBoxContainer for Row-based layout
	var old_grid = panel_container.get_node_or_null("GridContainer")
	if old_grid:
		old_grid.queue_free()

	container = VBoxContainer.new()
	container.name = "RowsContainer"
	# Compact spacing between rows
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_END # Pack at bottom

	panel_container.add_child(container)

	if panel_container:
		var style = StyleBoxEmpty.new()
		panel_container.add_theme_stylebox_override("panel", style)

	refresh_units()

	# Connect to grid updates
	if GameManager.grid_manager and GameManager.grid_manager.has_signal("grid_updated"):
		if !GameManager.grid_manager.is_connected("grid_updated", refresh_units):
			GameManager.grid_manager.grid_updated.connect(refresh_units)

func refresh_units():
	# Scan for viper and scorpion units on the grid
	monitored_units.clear()

	# Clear UI
	for child in container.get_children():
		child.queue_free()

	if !GameManager.grid_manager: return

	# Assuming GridManager has tiles dict
	var tiles = GameManager.grid_manager.tiles
	# Collect all valid passive units first
	for key in tiles:
		var tile = tiles[key]
		if tile.unit:
			var u = tile.unit
			# Generic check for production units
			if u.unit_data.has("production_type") and u.unit_data["production_type"] == "item":
				monitored_units.append(u)
			# Fallback for hardcoded types if JSON isn't fully migrated (legacy safety)
			elif u.type_key == "parrot":
				monitored_units.append(u)

	# Create Rows (Chunks of 3)
	# Requirement: "Add a new row above the existing row".
	# Logic: Chunk 0 (Oldest) -> Bottom. Chunk N (Newest) -> Top.

	var chunk_size = 3
	var current_row: HBoxContainer = null

	# To properly handle "Leftmost" for new units (which come last in the array iteration),
	# we need to consider how units fill the row.
	# If we just add to HBox, they go Right.
	# The user wants "New passive skills ... appear in the leftmost slot".
	# This implies that within a row, the sort order should be Newest -> Oldest (Left -> Right).
	# OR if we view the grid as filling up, usually it fills Top Left -> Bottom Right.
	# But here we are stacking Upwards. So Bottom Left -> Top Right?
	# "New passive skills appear in the leftmost slot".
	# If I have Row 0 (Oldest). I add a new Unit. It starts Row 1 (Newest). It should be at the Left.
	# That is default behavior of HBox.
	# But if I have Row 1 with 1 unit (Left), and I add another unit (Newer), where does it go?
	# "Leftmost". So it should push the previous one to the right?
	# If so, the row order is Newest -> Oldest.
	# YES.

	# So for the current chunk (which contains N units), we want to add them such that the last unit added is at index 0.
	# Wait, `monitored_units` usually appends new units at the end.
	# So unit at index `i` is older than `i+1`.
	# If we iterate `i` from 0 to N.
	# Chunk 0 has units 0, 1, 2.
	# If we want 2 to be Leftmost, and 0 to be Rightmost?
	# No, usually "Leftmost" means the slot position.
	# If I have [Empty, Empty, Empty].
	# Add Unit 1 -> [Unit 1, Empty, Empty].
	# Add Unit 2 -> [Unit 2, Unit 1, Empty] ?? Or [Unit 1, Unit 2, Empty]?
	# "Appear in the leftmost slot".
	# If I have [U1, U2] and I add U3. If it appears in Leftmost, it becomes [U3, U1, U2].
	# This implies a LIFO stack behavior for the visual row.

	# Let's assume standard "Latest on Left" behavior.
	# So when filling `current_row` with `unit`, we use `move_child(card, 0)`.

	for i in range(monitored_units.size()):
		if i % chunk_size == 0:
			# Start new row
			current_row = HBoxContainer.new()
			current_row.name = "Row_%d" % (i / chunk_size)
			current_row.add_theme_constant_override("separation", 10)
			# Center alignment looks best if row is not full, or Begin?
			# User said "Leftmost". So probably alignment = Begin (Left).
			# If centered, "Leftmost" is relative to the group.
			current_row.alignment = BoxContainer.ALIGNMENT_BEGIN
			# Actually, if we use move_child(0), we are prepending.
			# So visual order: [Newest ... Oldest]
			# If Alignment is Center, they cluster in center.
			# If Alignment is Begin (Left), they cluster on left.
			# Let's use Center as it usually looks better for UI bars, unless specifically asked to be left-aligned.
			# "Appear in the leftmost slot".
			# This usually implies position.
			# If I have 1 item, it should be on the Left? Or Center?
			# "Leftmost one".
			# Let's assume Left Alignment for the row content.
			current_row.alignment = BoxContainer.ALIGNMENT_BEGIN

			container.add_child(current_row)
			# Move row to top (Newest Row on Top)
			container.move_child(current_row, 0)

		var unit = monitored_units[i]
		_create_card(unit, current_row)

		# Enforce Newest on Left within the row
		# Since we iterate Old -> New, we prepend each new unit to the row.
		# [U0] -> [U1, U0] -> [U2, U1, U0]
		# This satisfies "New ... in leftmost".
		var card = current_row.get_child(current_row.get_child_count() - 1)
		current_row.move_child(card, 0)

func _create_card(unit, parent_row):
	var card = PanelContainer.new()
	# Fixed size for 1:1 look
	card.custom_minimum_size = Vector2(60, 60)
	card.name = "PassiveCard_%s" % unit.name
	card.set_meta("unit", unit)

	# Style matching SkillBar
	var bg_color = Color("#2c3e50")
	var style = StyleMaker.get_flat_style(bg_color, 8, 2, Color("#3498db"))
	card.add_theme_stylebox_override("panel", style)

	# Layout
	var layout = Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(layout)

	# Icon
	var icon_tex = AssetLoader.get_unit_icon(unit.type_key) if AssetLoader else null
	var icon_rect = TextureRect.new()
	if icon_tex:
		icon_rect.texture = icon_tex
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Smaller Square 45x45
	var size = 45
	icon_rect.custom_minimum_size = Vector2(size, size)
	icon_rect.size = Vector2(size, size)
	var offset = size / 2.0
	icon_rect.offset_left = -offset
	icon_rect.offset_top = -offset
	icon_rect.offset_right = offset
	icon_rect.offset_bottom = offset

	# Setup for Scale Pulse
	icon_rect.pivot_offset = Vector2(offset, offset)
	icon_rect.name = "Icon"

	layout.add_child(icon_rect)

	# CD Overlay
	var cd_bar = TextureProgressBar.new()
	cd_bar.name = "CD_Overlay"
	cd_bar.nine_patch_stretch = true
	cd_bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	cd_bar.value = 0
	cd_bar.max_value = 1.0
	cd_bar.step = 0.01
	cd_bar.tint_progress = Color(0, 0, 0, 0.7)
	cd_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var placeholder = ImageTexture.create_from_image(img)
	cd_bar.texture_progress = placeholder

	layout.add_child(cd_bar)

	# Ammo Label (Parrot)
	if unit.type_key == "parrot":
		cd_bar.visible = false # Hide CD for parrot

		var ammo_lbl = Label.new()
		ammo_lbl.name = "AmmoLabel"
		ammo_lbl.add_theme_font_size_override("font_size", 12)
		ammo_lbl.text = "0/5"
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		ammo_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		# Add outline for readability
		ammo_lbl.add_theme_constant_override("outline_size", 4)
		ammo_lbl.add_theme_color_override("font_outline_color", Color.BLACK)

		layout.add_child(ammo_lbl)

	parent_row.add_child(card)

func _process(_delta):
	# Resize Logic
	if panel_container and container:
		var target_height = 0.0
		for child in container.get_children():
			if child is Container:
				target_height += child.get_combined_minimum_size().y

		var sep = container.get_theme_constant("separation")
		var visible_children = 0
		for c in container.get_children(): if c.visible: visible_children += 1
		if visible_children > 1:
			target_height += (visible_children - 1) * sep

		if custom_minimum_size.y != target_height:
			custom_minimum_size.y = target_height

	# Update CD overlays and handle flashing
	if !container: return

	# Reverse Iteration logic for matching units (if needed)
	# Actually, since we clear and rebuild on refresh, we can just iterate cards.
	# But we need to link them to units.
	# Since we sorted visual order, matching by index is tricky.
	# We should probably store the unit in the card metadata to be safe.
	# Wait, `_create_card` doesn't store unit reference.
	# Let's rely on the fact that `monitored_units` is stable during `_process`.
	# BUT `refresh_units` reorders them visually.
	# [U0, U1, U2] -> Row 0: [U2, U1, U0].
	# If we iterate monitored_units i=0..N.
	# Unit 0 is at Row 0, Child 2.
	# Unit 2 is at Row 0, Child 0.
	# This is getting complex.
	# Better to traverse the Visual Tree and use stored Unit reference.
	# I will add `card.set_meta("unit", unit)` in `_create_card`.

	for row in container.get_children():
		for card in row.get_children():
			if !card.has_meta("unit"): continue
			var unit = card.get_meta("unit")

			if !is_instance_valid(unit):
				continue

			var layout = card.get_child(0)
			var cd_bar = layout.get_node("CD_Overlay")

			if unit.type_key == "parrot":
				var ammo_lbl = layout.get_node_or_null("AmmoLabel")
				if ammo_lbl and unit.behavior:
					var size = 0
					var max_a = 0
					if "ammo_queue" in unit.behavior: size = unit.behavior.ammo_queue.size()
					if "max_ammo" in unit.behavior: max_a = unit.behavior.max_ammo
					ammo_lbl.text = "%d/%d" % [size, max_a]
			else:
				var prev_timer = card.get_meta("prev_timer", 0.0)
				var current_timer = 0.0
				var max_timer = 1.0

				if unit.behavior and "production_timer" in unit.behavior:
					current_timer = unit.behavior.production_timer
				if unit.behavior and "max_production_timer" in unit.behavior:
					max_timer = unit.behavior.max_production_timer

				if prev_timer > 0 and current_timer <= 0:
					_trigger_flash(card)
				elif prev_timer > 0 and current_timer > prev_timer:
					_trigger_flash(card)

				card.set_meta("prev_timer", current_timer)

				cd_bar.max_value = max_timer
				cd_bar.value = current_timer

func _trigger_flash(card):
	if !card.has_meta("flashing") or !card.get_meta("flashing"):
		card.set_meta("flashing", true)

		var tween = create_tween()
		tween.tween_property(card, "modulate", Color(2.0, 2.0, 2.0), 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(card, "modulate", Color.WHITE, 0.1).set_trans(Tween.TRANS_SINE)

		tween.finished.connect(func(): card.set_meta("flashing", false))
