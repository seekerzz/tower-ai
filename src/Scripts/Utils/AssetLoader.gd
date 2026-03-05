extends Node

static func get_unit_icon(unit_key: String) -> Texture2D:
	var path = "res://assets/images/units/%s.png" % unit_key
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func get_core_icon(core_key: String) -> Texture2D:
	var path = "res://assets/images/cores/%s.png" % core_key
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func get_enemy_icon(enemy_key: String) -> Texture2D:
	var path = "res://assets/images/enemies/%s.png" % enemy_key
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func get_item_icon(item_key: String) -> Texture2D:
	var path = "res://assets/images/items/%s.png" % item_key
	if ResourceLoader.exists(path):
		return load(path)
	return null
