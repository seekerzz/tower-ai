extends Node
class_name UnitStats

signal on_death

var base_stats: Dictionary = {}
var modifiers: Dictionary = {}

func _ready() -> void:
	pass

func set_base_stat(stat_name: String, value: float) -> void:
	base_stats[stat_name] = value

func get_base_stat(stat_name: String) -> float:
	return base_stats.get(stat_name, 0.0)

func add_modifier(stat_name: String, modifier) -> void:
	if not modifiers.has(stat_name):
		modifiers[stat_name] = []

	var stat_modifiers: Array = modifiers[stat_name]

	if not modifier.source_id.is_empty():
		for i in range(stat_modifiers.size()):
			var existing_mod = stat_modifiers[i]
			if existing_mod.source_id == modifier.source_id and existing_mod.type == modifier.type:
				stat_modifiers[i] = modifier
				return

	stat_modifiers.append(modifier)

func remove_modifier(stat_name: String, source_id: String) -> void:
	if not modifiers.has(stat_name):
		return

	var stat_modifiers: Array = modifiers[stat_name]
	for i in range(stat_modifiers.size() - 1, -1, -1):
		if stat_modifiers[i].source_id == source_id:
			stat_modifiers.remove_at(i)

func get_stat(stat_name: String) -> float:
	var value: float = get_base_stat(stat_name)

	if not modifiers.has(stat_name):
		return value

	var stat_modifiers: Array = modifiers[stat_name]

	var flat_sum: float = 0.0
	var percent_sum: float = 0.0

	for mod in stat_modifiers:
		if mod.type == 0: # FLAT
			flat_sum += mod.value
		elif mod.type == 1: # PERCENT
			percent_sum += mod.value

	var final_value: float = value + flat_sum
	var multiplier: float = 1.0 + percent_sum

	return final_value * multiplier

func _process(delta: float) -> void:
	for stat_name in modifiers.keys():
		var stat_modifiers: Array = modifiers[stat_name]
		var i: int = stat_modifiers.size() - 1
		while i >= 0:
			var mod = stat_modifiers[i]
			mod.tick(delta)
			if mod.is_expired():
				stat_modifiers.remove_at(i)
			i -= 1

func take_damage(amount: float) -> void:
	var hp: float = get_stat("hp")
	var new_hp: float = hp - amount

	if new_hp <= 0.0:
		new_hp = 0.0
		base_stats["hp"] = 0.0
		modifiers["hp"] = []
		on_death.emit()
	else:
		base_stats["hp"] -= amount

func heal(amount: float) -> void:
	if base_stats.has("hp"):
		base_stats["hp"] += amount
	else:
		base_stats["hp"] = amount
