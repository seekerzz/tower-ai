extends Node

class_name DataManager

var data: Dictionary = {}

func load_data():
	var file = FileAccess.open("res://data/game_data.json", FileAccess.READ)
	if not file:
		push_error("Failed to load game data file.")
		return

	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		data = json.data
		_parse_core_types(data.get("CORE_TYPES", {}))
		_parse_barricade_types(data.get("BARRICADE_TYPES", {}))
		_parse_unit_types(data.get("UNIT_TYPES", {}))
		_parse_traits(data.get("TRAITS", []))
		_parse_enemy_variants(data.get("ENEMY_VARIANTS", {}))
		print("Game data loaded successfully.")
	else:
		push_error("JSON Parse Error: ", json.get_error_message(), " in ", content, " at line ", json.get_error_line())

func _parse_core_types(data: Dictionary):
	Constants.CORE_TYPES = data

func _parse_barricade_types(data: Dictionary):
	for key in data:
		var entry = data[key]
		if entry.has("color"):
			entry["color"] = Color(entry["color"])
		Constants.BARRICADE_TYPES[key] = entry

func _parse_unit_types(data: Dictionary):
	for key in data:
		var entry = data[key]
		if entry.has("size"):
			var s = entry["size"]
			entry["size"] = Vector2i(s[0], s[1])

		# Compatibility: Copy Level 1 stats to root
		if entry.has("levels") and entry["levels"].has("1"):
			var lv1 = entry["levels"]["1"]
			for k in lv1:
				if k != "mechanics":
					entry[k] = lv1[k]

		Constants.UNIT_TYPES[key] = entry

func _parse_traits(data: Array):
	Constants.TRAITS = data

func _parse_enemy_variants(data: Dictionary):
	for key in data:
		var entry = data[key]
		if entry.has("color"):
			entry["color"] = Color(entry["color"])
		Constants.ENEMY_VARIANTS[key] = entry
