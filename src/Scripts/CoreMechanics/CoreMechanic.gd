extends Node
class_name CoreMechanic

func on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	pass

func on_core_damaged(amount: float):
	pass

func on_damage_dealt_by_unit(unit, amount: float):
	pass

func on_projectile_crit(projectile, target):
	pass

func get_stat_modifier(stat_type: String, context: Dictionary) -> float:
	return 1.0
