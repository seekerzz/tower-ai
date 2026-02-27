extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var heal_interval: float = 6.0
var heal_timer: float = 0.0

func on_setup():
	heal_interval = 6.0
	if unit.level >= 2:
		heal_interval = 5.0
	heal_timer = heal_interval

func on_tick(delta: float):
	heal_timer -= delta
	if heal_timer <= 0:
		heal_timer = heal_interval
		_heal_core()

func _heal_core():
	var base_heal = GameManager.max_core_health * 0.015

	if unit.level >= 3:
		var health_lost_percent = 1.0 - (GameManager.core_health / GameManager.max_core_health)
		var bonus_multiplier = 1.0 + health_lost_percent
		base_heal *= bonus_multiplier

	GameManager.heal_core(base_heal)
	unit.spawn_buff_effect("🥛")
