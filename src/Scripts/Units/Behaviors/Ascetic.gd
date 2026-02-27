extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name AsceticBehavior

var damage_to_mana_ratio: float = 0.12
var buffed_units: Array = []
var max_buffed_count: int = 1

func on_setup():
	max_buffed_count = 1 if unit.level < 3 else 2
	call_deferred("_auto_select_targets")

func _auto_select_targets():
	if not is_instance_valid(unit): return

	var all_units = unit.get_all_player_units()
	# Filter self out
	var valid_units = []
	for u in all_units:
		if u != unit:
			valid_units.append(u)

	valid_units.sort_custom(func(a, b):
		return unit.global_position.distance_to(a.global_position) < \
			   unit.global_position.distance_to(b.global_position)
	)

	# Clear old connections if any (though on_setup runs on fresh unit/reset)
	_clear_buffs()

	for i in range(min(max_buffed_count, valid_units.size())):
		buffed_units.append(valid_units[i])

	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit):
			buffed_unit.set_meta("ascetic_buffed", true)
			buffed_unit.set_meta("ascetic_source", unit)
			if not buffed_unit.is_connected("damage_taken", _on_buffed_unit_damaged):
				buffed_unit.damage_taken.connect(_on_buffed_unit_damaged)

			unit.spawn_buff_effect("🙏")

func _on_buffed_unit_damaged(amount: float, source: Node):
	if !is_instance_valid(unit): return

	var ratio = 0.12 if unit.level < 2 else 0.18
	var mana_gain = amount * ratio
	GameManager.add_resource("mana", mana_gain)

	# Visual Effect
	GameManager.spawn_floating_text(unit.global_position, "+%d MP" % int(mana_gain), Color.CYAN)

func _clear_buffs():
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit):
			if buffed_unit.is_connected("damage_taken", _on_buffed_unit_damaged):
				buffed_unit.damage_taken.disconnect(_on_buffed_unit_damaged)
			buffed_unit.remove_meta("ascetic_buffed")
			buffed_unit.remove_meta("ascetic_source")
	buffed_units.clear()

func on_cleanup():
	_clear_buffs()
