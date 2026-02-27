extends PanelContainer

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var icon_rect
var title_label
var stats_label
var buff_label

func _ready():
	icon_rect = get_node("VBoxContainer/HeaderContainer/IconRect")
	title_label = get_node("VBoxContainer/HeaderContainer/TitleLabel")
	stats_label = get_node("VBoxContainer/StatsLabel")
	buff_label = get_node("VBoxContainer/BuffLabel")
	hide()

func show_tooltip(unit_data: Dictionary, current_stats: Dictionary, active_buffs: Array, global_pos: Vector2):
	if !icon_rect:
		icon_rect = get_node("VBoxContainer/HeaderContainer/IconRect")
	if !title_label:
		title_label = get_node("VBoxContainer/HeaderContainer/TitleLabel")
	if !stats_label:
		stats_label = get_node("VBoxContainer/StatsLabel")
	if !buff_label:
		buff_label = get_node("VBoxContainer/BuffLabel")

	# Set Icon
	var unit_key = unit_data.get("key", "")
	if unit_key == "":
		# Try to fallback or find key elsewhere if not in data directly
		# For now assuming key is passed or available in data
		unit_key = unit_data.get("id", "") # Sometimes id is used as key

	if unit_key != "":
		var icon = AssetLoader.get_unit_icon(unit_key) if AssetLoader else null
		if icon:
			icon_rect.texture = icon
			icon_rect.show()
		else:
			icon_rect.hide() # Or show placeholder?
	else:
		icon_rect.hide()

	title_label.text = "[b]" + unit_data.get("name", "Unknown") + "[/b]"

	var desc = unit_data.get("desc", "")
	var stats_text = ""

	# Emoji Style
	var max_hp = unit_data.get("hp", 0)
	stats_text += "❤️ %d\n" % floor(max_hp)

	var damage = current_stats.get("damage", 0)
	if damage > 0:
		stats_text += "⚔️ %d\n" % floor(damage)
		stats_text += "⚡ %.1f/s\n" % (1.0 / max(0.01, current_stats.get("atk_speed", 1.0)))
		stats_text += "🏹 %d\n" % floor(current_stats.get("range", 0))

		var crit_rate = current_stats.get("crit_rate", 0.1)
		var crit_dmg = current_stats.get("crit_dmg", 1.5)
		stats_text += "💥 %d%% (x%.1f)\n" % [floor(crit_rate * 100), crit_dmg]

	if desc != "":
		stats_text += "\n[color=#aaaaaa]" + desc + "[/color]"

	stats_label.text = stats_text

	var buff_text = ""
	if active_buffs.size() > 0:
		buff_text = "[color=yellow]Buffs:[/color]\n"
		for b in active_buffs:
			buff_text += "- " + b.capitalize() + "\n"

	buff_label.text = buff_text
	buff_label.visible = active_buffs.size() > 0

	# Ensure minimum width to prevent text wrapping issues
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 0)

	self.size.x = custom_minimum_size.x

	var width = custom_minimum_size.x

	# Explicitly set width constraints on children to fix huge height bug.
	# Sometimes RichTextLabel with fit_content calculates height based on 0/tiny width if not forced.
	$VBoxContainer.custom_minimum_size.x = width
	$VBoxContainer.size.x = width

	# title_label is now inside HeaderContainer, so we constrain HeaderContainer or the label inside?
	# We should constrain the header container width mainly.
	$VBoxContainer/HeaderContainer.custom_minimum_size.x = width

	# For TitleLabel inside HBox, we probably don't need to force width if we use size flags,
	# but keeping consistency with old logic:
	title_label.custom_minimum_size.x = width - 40 # Subtract icon width + spacing estimate
	stats_label.custom_minimum_size.x = width
	buff_label.custom_minimum_size.x = width

	# Toggling fit_content forces recalculation of height based on the new width
	title_label.fit_content = false
	stats_label.fit_content = false
	buff_label.fit_content = false

	title_label.size = Vector2(width - 40, 0)
	stats_label.size = Vector2(width, 0)
	buff_label.size = Vector2(width, 0)

	title_label.fit_content = true
	stats_label.fit_content = true
	buff_label.fit_content = true

	reset_size()

	var vp_size = get_viewport_rect().size
	var size = get_size()
	var target_pos = global_pos + Vector2(20, 20)

	# Boundary checks
	if target_pos.x + size.x > vp_size.x:
		target_pos.x = global_pos.x - size.x - 20

	if target_pos.y + size.y > vp_size.y:
		target_pos.y = global_pos.y - size.y - 20

	# Clamp to ensure it doesn't go off-screen top/left
	target_pos.x = max(0, target_pos.x)
	target_pos.y = max(0, target_pos.y)

	position = target_pos

	show()
	z_index = 4096 # On top

func hide_tooltip():
	hide()
