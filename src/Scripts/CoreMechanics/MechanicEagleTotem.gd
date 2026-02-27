extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var echo_chance: float = 0.3
var echo_mult: float = 1.0

func _ready():
	if Constants.CORE_TYPES.has("eagle_totem"):
		var config = Constants.CORE_TYPES["eagle_totem"]
		echo_chance = config.get("crit_echo_chance", 0.3)
		echo_mult = config.get("crit_echo_mult", 1.0)

func on_projectile_crit(projectile, target):
	if randf() < echo_chance:
		if projectile.has_method("trigger_eagle_echo"):
			var echo_damage = projectile.damage * echo_mult
			projectile.trigger_eagle_echo(target, echo_mult)
			if projectile.source_unit:
				GameManager.totem_echo_triggered.emit(projectile.source_unit, echo_damage)
				# Emit echo_triggered signal for test logging
				if GameManager.has_signal("echo_triggered"):
					GameManager.echo_triggered.emit(projectile.source_unit, target, projectile.damage, echo_damage)
