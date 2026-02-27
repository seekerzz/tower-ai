extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

@export var overflow_decay: float = 0.15

var overflowed_units: Dictionary = {}
var decay_timer: float = 0.0

func on_setup():
	if GameManager.get("lifesteal_manager") and GameManager.lifesteal_manager:
		if not GameManager.lifesteal_manager.lifesteal_occurred.is_connected(_on_lifesteal):
			GameManager.lifesteal_manager.lifesteal_occurred.connect(_on_lifesteal)

func on_tick(delta: float):
	decay_timer += delta
	if decay_timer >= 0.5:
		decay_timer = 0.0
		_apply_effects()

func _on_lifesteal(source: Node, amount: float):
	# source is the Unit that caused lifesteal
	if not (source is Unit): return

	var potential_hp = source.current_hp + amount
	if potential_hp > source.max_hp:
		var overflow = potential_hp - source.max_hp
		var current_overflow = overflowed_units.get(source.get_instance_id(), 0.0)
		overflowed_units[source.get_instance_id()] = current_overflow + overflow

		# Visual effect
		GameManager.spawn_floating_text(source.global_position, "Overflow!", Color.RED)

func _apply_effects():
	var decay = 0.10 if unit.level >= 2 else 0.15

	var ids_to_remove = []
	for unit_id in overflowed_units.keys():
		var amount = overflowed_units[unit_id]
		amount *= (1.0 - decay)

		if amount < 1.0:
			ids_to_remove.append(unit_id)
		else:
			overflowed_units[unit_id] = amount

	for id in ids_to_remove:
		overflowed_units.erase(id)

	if unit.level >= 3:
		_apply_core_loss_damage()

func _apply_core_loss_damage():
	var core_lost = GameManager.max_core_health - GameManager.core_health
	if core_lost <= 0: return

	var damage = core_lost * 0.5
	# Apply to enemies in range
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and unit.global_position.distance_to(enemy.global_position) <= unit.range_val:
			enemy.take_damage(damage * 0.5, unit)

func on_cleanup():
	if GameManager.lifesteal_manager and GameManager.lifesteal_manager.lifesteal_occurred.is_connected(_on_lifesteal):
		GameManager.lifesteal_manager.lifesteal_occurred.disconnect(_on_lifesteal)
