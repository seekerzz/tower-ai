extends Node

class_name DataManager

var data: Dictionary = {}

func load_data():
	# UNIT_TYPES 和 ENEMY_VARIANTS 从 GDScript 数据文件加载（无 IO）
	_parse_unit_types(UnitDataRegistry.get_all_units())
	_parse_enemy_variants(UnitDataRegistry.get_all_enemies())

	# CORE_TYPES / BARRICADE_TYPES / TRAITS 仍从 JSON 加载（后续迁移）
	var file = FileAccess.open("res://data/game_data.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			data = json.data
			_parse_core_types(data.get("CORE_TYPES", {}))
			_parse_barricade_types(data.get("BARRICADE_TYPES", {}))
			_parse_traits(data.get("TRAITS", []))
		else:
			push_error("[DataManager] JSON Parse Error: ", json.get_error_message())
	else:
		push_warning("[DataManager] game_data.json not found, CORE/BARRICADE/TRAITS will be empty.")

	print("Game data loaded successfully.")

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
		var entry = data[key].duplicate(true)
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
		var entry = data[key].duplicate(true)
		if entry.has("color"):
			entry["color"] = Color(entry["color"])
		Constants.ENEMY_VARIANTS[key] = entry
