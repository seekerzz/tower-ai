extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var shield_amount: float = 0.0
var shield_percent: float = 0.8

func on_setup():
	if not GameManager.wave_started.is_connected(_on_wave_start):
		GameManager.wave_started.connect(_on_wave_start)
	if not GameManager.core_healed.is_connected(_on_core_healed):
		GameManager.core_healed.connect(_on_core_healed)

	call_deferred("_on_wave_start")

func _on_wave_start():
	shield_percent = 0.8 if unit.level < 2 else 1.2
	shield_amount = unit.max_hp * shield_percent
	unit.spawn_buff_effect("🛡️")
	# Emit signal for test logging
	GameManager.shield_generated.emit(unit, shield_amount, unit)

func on_damage_taken(amount: float, source: Node) -> float:
	if shield_amount > 0:
		var shield_absorb = min(shield_amount, amount)
		shield_amount -= shield_absorb
		amount -= shield_absorb

		# Emit signal for test logging
		GameManager.shield_absorbed.emit(unit, shield_absorb, shield_amount, source)

		if source and is_instance_valid(source) and source.has_method("take_damage"):
			var bonus_damage = shield_absorb * 0.4
			source.take_damage(bonus_damage, unit, "physical")

		if shield_amount <= 0:
			unit.spawn_buff_effect("💔")

	return amount

func _on_core_healed(amount: float, overheal: float):
	if unit.level >= 3:
		if overheal > 0:
			shield_amount += overheal * 0.1
			unit.spawn_buff_effect("➕🛡️")

func on_cleanup():
	if GameManager.wave_started.is_connected(_on_wave_start):
		GameManager.wave_started.disconnect(_on_wave_start)
	if GameManager.core_healed.is_connected(_on_core_healed):
		GameManager.core_healed.disconnect(_on_core_healed)
