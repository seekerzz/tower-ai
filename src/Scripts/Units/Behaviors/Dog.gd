extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var skill_active_timer: float = 0.0
var original_atk_speed: float = 0.0
var _is_skill_active: bool = false

func on_skill_activated():
	# Prevent multiple activations stacking incorrectly
	if _is_skill_active:
		# Just reset the timer if already active
		skill_active_timer = 5.0
		return

	skill_active_timer = 5.0
	_is_skill_active = true
	unit.set_highlight(true, Color.RED)
	original_atk_speed = unit.atk_speed
	# Rage increases attack speed (lower atk_speed value = faster attacks)
	unit.atk_speed *= 0.3

func on_tick(delta: float):
	if skill_active_timer > 0:
		skill_active_timer -= delta
		if skill_active_timer <= 0:
			_is_skill_active = false
			unit.set_highlight(false)
			# Only restore if original_atk_speed was properly set
			if original_atk_speed > 0:
				unit.atk_speed = original_atk_speed
			else:
				# Fallback: restore to base value from unit_data if available
				if unit and unit.unit_data:
					unit.atk_speed = unit.unit_data.get("atkSpeed", 0.8)
