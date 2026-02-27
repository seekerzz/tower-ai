extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var skill_active_timer: float = 0.0
var original_atk_speed: float = 0.0

func on_skill_activated():
	skill_active_timer = 5.0
	unit.set_highlight(true, Color.RED)
	original_atk_speed = unit.atk_speed
	unit.atk_speed *= 0.3

func on_tick(delta: float):
	if skill_active_timer > 0:
		skill_active_timer -= delta
		if skill_active_timer <= 0:
			unit.set_highlight(false)
			unit.atk_speed = original_atk_speed
