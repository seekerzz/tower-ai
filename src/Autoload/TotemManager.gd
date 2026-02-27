extends Node

signal totem_resource_changed(totem_id: String, current: int, max_value: int)

# 资源存储结构: resources[totem_id] = {"current": int, "max": int, "default_max": int}
var resources: Dictionary = {}

const DEFAULT_MAX_VALUES: Dictionary = {
	"wolf": 500,
	"cow": 999999,
}

func _get_or_create_resource(totem_id: String) -> Dictionary:
	"""获取或创建图腾资源条目，确保绝不返回 null"""
	if not resources.has(totem_id):
		var default_max = DEFAULT_MAX_VALUES.get(totem_id, 999999)
		resources[totem_id] = {
			"current": 0,
			"max": default_max,
			"default_max": default_max
		}
	return resources[totem_id]

func add_resource(totem_id: String, amount: int) -> void:
	"""增加图腾资源当前值（不超过上限）"""
	var res = _get_or_create_resource(totem_id)
	res.current = min(res.current + amount, res.max)
	totem_resource_changed.emit(totem_id, res.current, res.max)

func get_resource(totem_id: String) -> int:
	"""获取图腾资源当前值"""
	var res = _get_or_create_resource(totem_id)
	return res.current

func get_max_resource(totem_id: String) -> int:
	"""获取图腾资源上限"""
	var res = _get_or_create_resource(totem_id)
	return res.max

func modify_max_resource(totem_id: String, amount: int) -> void:
	"""修改图腾资源上限"""
	var res = _get_or_create_resource(totem_id)
	res.max += amount
	totem_resource_changed.emit(totem_id, res.current, res.max)

func clear_resource(totem_id: String) -> void:
	"""清零图腾资源当前值"""
	var res = _get_or_create_resource(totem_id)
	res.current = 0
	totem_resource_changed.emit(totem_id, 0, res.max)

func set_resource(totem_id: String, amount: int) -> void:
	"""直接设置图腾资源当前值（不超过上限）"""
	var res = _get_or_create_resource(totem_id)
	res.current = min(amount, res.max)
	totem_resource_changed.emit(totem_id, res.current, res.max)
