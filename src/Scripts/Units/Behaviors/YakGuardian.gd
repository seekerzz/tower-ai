extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var taunt_behavior: RefCounted

func on_setup():
	var script = load("res://src/Scripts/Units/Behaviors/TauntBehavior.gd")
	if script:
		taunt_behavior = script.new(unit)
		taunt_behavior.taunt_interval = 6.0 if unit.level < 2 else 5.0

	if unit.level >= 3:
		if not GameManager.is_connected("totem_attacked", _on_totem_attack):
			GameManager.totem_attacked.connect(_on_totem_attack)

func on_tick(delta: float):
	if taunt_behavior and taunt_behavior.has_method("on_tick"):
		taunt_behavior.on_tick(delta)

func _on_totem_attack(totem_type: String):
	if totem_type != "cow":
		return

	var bonus_damage = unit.max_hp * 0.15
	var enemies = unit.get_enemies_in_range(unit.range_val)
	for enemy in enemies:
		enemy.take_damage(bonus_damage, unit, "physical")
		unit.spawn_buff_effect("⚔️")

func on_cleanup():
	if GameManager.has_signal("totem_attacked") and GameManager.is_connected("totem_attacked", _on_totem_attack):
		GameManager.totem_attacked.disconnect(_on_totem_attack)
