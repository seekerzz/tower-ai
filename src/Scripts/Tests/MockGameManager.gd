extends Node

signal damage_blocked(damage: float, source: Node)
signal buff_applied(unit, buff_type, source_unit, amount)
signal show_tooltip(unit_data, current_stats, active_buffs, global_position)
signal hide_tooltip()
signal skill_activated(unit)
signal unit_upgraded(unit, old_level, level)

var is_wave_active = true
var skill_cost_reduction = 0.0
var cheat_fast_cooldown = false
var reward_manager = null
var grid_manager = null
var combat_manager = null

func get_stat_modifier(stat_name: String) -> float:
	return 1.0

func get_global_buff(buff_name: String, default: float) -> float:
	return default

func consume_resource(resource_name: String, amount: float) -> bool:
	return true

func check_resource(resource_name: String, amount: float) -> bool:
	return true

func damage_core(amount: float):
	pass

func spawn_floating_text(pos: Vector2, text: String, color: Color):
	pass
