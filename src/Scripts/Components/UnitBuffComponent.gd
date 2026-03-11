extends RefCounted
class_name UnitBuffComponent

var unit: Node2D

var active_buffs: Array = []
var buff_sources: Dictionary = {} # Key: buff_type, Value: source_unit (Node2D)
var temporary_buffs: Array = [] # Array of {stat, amount, duration, source}

var bounce_count: int = 0
var split_count: int = 0

func _init(target_unit: Node2D):
	unit = target_unit

func clear():
	active_buffs.clear()
	buff_sources.clear()
	bounce_count = 0
	split_count = 0

func apply_buff(buff_type: String, source_unit: Node2D = null):
	if buff_type in active_buffs and buff_type != "bounce": return

	if not (buff_type in active_buffs):
		active_buffs.append(buff_type)

	if source_unit:
		buff_sources[buff_type] = source_unit

	if GameManager.has_signal("buff_applied"):
		var amount = 0.0
		match buff_type:
			"range": amount = 1.25
			"speed": amount = 1.2
			"crit": amount = 0.25
			"bounce": amount = 1.0
			"split": amount = 1.0
			"forest_blessing": amount = 1.0
			"guardian_shield": amount = 1.0
		GameManager.buff_applied.emit(unit, buff_type, source_unit, amount)

	match buff_type:
		"range":
			unit.range_val *= 1.25
		"speed":
			unit.atk_speed *= 1.2
		"crit":
			unit.crit_rate += 0.25
		"bounce":
			bounce_count += 1
		"split":
			split_count += 1
		"guardian_shield":
			pass

func add_temporary_buff(stat: String, amount: float, duration: float):
	temporary_buffs.append({
		"stat": stat,
		"amount": amount,
		"duration": duration
	})
	_apply_temp_buff_effect(stat, amount)

func _update_temporary_buffs(delta: float):
	for i in range(temporary_buffs.size() - 1, -1, -1):
		var buff = temporary_buffs[i]
		buff["duration"] -= delta
		if buff["duration"] <= 0:
			_remove_temp_buff_effect(buff["stat"], buff["amount"])
			temporary_buffs.remove_at(i)

func _apply_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			unit.atk_speed *= (1.0 + amount)
		"crit_chance":
			unit.crit_rate += amount

func _remove_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			unit.atk_speed /= (1.0 + amount)
		"crit_chance":
			unit.crit_rate -= amount
