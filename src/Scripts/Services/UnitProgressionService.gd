extends RefCounted
class_name UnitProgressionService

var unit: Node2D

func _init(target_unit: Node2D):
	unit = target_unit

func can_merge_with(other_unit) -> bool:
	if other_unit == null: return false
	if other_unit == unit: return false
	if other_unit.type_key != unit.type_key: return false
	if other_unit.level != unit.level: return false
	if unit.level >= unit.MAX_LEVEL: return false
	return true

func merge_with(other_unit):
	var old_level = unit.level
	unit.merged.emit(other_unit)
	unit.level += 1
	unit.reset_stats()
	unit.current_hp = unit.max_hp

	GameManager.unit_upgraded.emit(unit, old_level, unit.level)
	GameManager.spawn_floating_text(unit.global_position, "Level Up!", Color.GOLD)
	if unit.visual_component and unit.visual_component.has_method("play_level_up_anim"):
		unit.visual_component.play_level_up_anim()

func devour(food_unit):
	var old_level = unit.level
	unit.level += 1
	unit.damage += 5
	unit.stats_multiplier += 0.2
	unit.update_visuals()
	GameManager.unit_upgraded.emit(unit, old_level, unit.level)
