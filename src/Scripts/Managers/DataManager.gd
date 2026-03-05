extends Node

class_name DataManager

# 数据文件列表
const DATA_FILES = {
	"core_types": "res://data/core_types.json",
	"barricade_types": "res://data/barricade_types.json",
	"enemy_variants": "res://data/enemy_variants.json",
	"traits": "res://data/traits.json",
}

# 单位阵营文件目录
const UNITS_DIR = "res://data/units/"

func load_data():
	print("[DataManager] Starting to load game data...")

	# 加载主要数据文件
	_load_core_types()
	_load_barricade_types()
	_load_enemy_variants()
	_load_traits()

	# 加载所有单位数据（从拆分后的阵营文件）
	_load_all_unit_types()

	print("[DataManager] Game data loaded successfully.")

func _load_json_file(path: String) -> Dictionary:
	"""加载单个 JSON 文件并返回解析后的数据"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[DataManager] Failed to load file: " + path)
		return {}

	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		return json.data
	else:
		push_error("[DataManager] JSON Parse Error in ", path, ": ", json.get_error_message(), " at line ", json.get_error_line())
		return {}

func _load_core_types():
	var data = _load_json_file(DATA_FILES["core_types"])
	if data.has("CORE_TYPES"):
		Constants.CORE_TYPES = data["CORE_TYPES"]
		print("[DataManager] Loaded ", Constants.CORE_TYPES.size(), " core types")

func _load_barricade_types():
	var data = _load_json_file(DATA_FILES["barricade_types"])
	if data.has("BARRICADE_TYPES"):
		_parse_barricade_types(data["BARRICADE_TYPES"])
		print("[DataManager] Loaded ", Constants.BARRICADE_TYPES.size(), " barricade types")

func _load_enemy_variants():
	var data = _load_json_file(DATA_FILES["enemy_variants"])
	if data.has("ENEMY_VARIANTS"):
		_parse_enemy_variants(data["ENEMY_VARIANTS"])
		print("[DataManager] Loaded ", Constants.ENEMY_VARIANTS.size(), " enemy variants")

func _load_traits():
	var data = _load_json_file(DATA_FILES["traits"])
	if data.has("TRAITS"):
		Constants.TRAITS = data["TRAITS"]
		print("[DataManager] Loaded ", Constants.TRAITS.size(), " traits")

func _load_all_unit_types():
	"""加载所有阵营的单位数据文件"""
	var dir = DirAccess.open(UNITS_DIR)
	if not dir:
		push_error("[DataManager] Failed to open units directory: " + UNITS_DIR)
		return

	var total_units = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var faction_name = file_name.get_basename()
			var file_path = UNITS_DIR + file_name
			var units_data = _load_json_file(file_path)

			if units_data.size() > 0:
				var count = _parse_unit_types(units_data, faction_name)
				total_units += count
				print("[DataManager] Loaded faction '", faction_name, "' with ", count, " units")

		file_name = dir.get_next()

	dir.list_dir_end()
	print("[DataManager] Total units loaded: ", total_units)

func _parse_barricade_types(data: Dictionary):
	for key in data:
		var entry = data[key]
		if entry.has("color"):
			entry["color"] = Color(entry["color"])
		Constants.BARRICADE_TYPES[key] = entry

func _parse_unit_types(data: Dictionary, faction_name: String = "") -> int:
	"""解析单位数据，返回加载的单位数量"""
	var count = 0
	for key in data:
		var entry = data[key]

		# 转换 size 数组为 Vector2i
		if entry.has("size"):
			var s = entry["size"]
			entry["size"] = Vector2i(s[0], s[1])

		# 兼容性处理：将等级1的属性复制到根级别
		if entry.has("levels") and entry["levels"].has("1"):
			var lv1 = entry["levels"]["1"]
			for k in lv1:
				if k != "mechanics":
					entry[k] = lv1[k]

		Constants.UNIT_TYPES[key] = entry
		count += 1
	return count

func _parse_enemy_variants(data: Dictionary):
	for key in data:
		var entry = data[key]
		if entry.has("color"):
			entry["color"] = Color(entry["color"])
		Constants.ENEMY_VARIANTS[key] = entry
