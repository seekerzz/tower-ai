extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name MushroomHealerBehavior

var spore_stacks: int = 1
var unit_spores: Dictionary = {}
var timer: float = 6.0

func on_setup():
	spore_stacks = 1
	if unit.level >= 2:
		spore_stacks = 2
	timer = 6.0

func on_tick(delta: float):
	timer -= delta
	if timer <= 0:
		timer = 6.0
		_apply_spore_shields()

func _apply_spore_shields():
	# Range 3 (approx 150px)
	var allies = unit.get_units_in_cell_range(unit, 3)

	for ally in allies:
		if ally == unit: continue

		var id = ally.get_instance_id()
		var current = unit_spores.get(id, 0)
		var new_stacks = min(current + spore_stacks, 3)
		unit_spores[id] = new_stacks
		ally.set_meta("spore_shield", new_stacks)

		if not ally.is_connected("damage_blocked", _on_spore_blocked):
			ally.damage_blocked.connect(_on_spore_blocked)

		unit.spawn_buff_effect("🍄")

		# Emit signal for test logging
		GameManager.heal_stored.emit(unit, spore_stacks, new_stacks)

func _on_spore_blocked(ally: Node, damage: float, source: Node):
	var id = ally.get_instance_id()
	var spores = unit_spores.get(id, 0)

	if spores <= 0: return

	unit_spores[id] = spores - 1
	ally.set_meta("spore_shield", spores - 1)

	# Poison attacker
	if source and is_instance_valid(source) and source.is_in_group("enemies"):
		if source.has_method("apply_status"):
			var poison_script = load("res://src/Scripts/Effects/PoisonEffect.gd")
			source.apply_status(poison_script, {"duration": 5.0, "stacks": 2, "damage": 5.0})

	if unit.level >= 3 and (spores - 1) <= 0:
		_apply_bonus_poison_damage(ally)

func _apply_bonus_poison_damage(ally: Node):
	if !GameManager.combat_manager: return

	# Find target near ally
	var range_val = 200.0
	if "range_val" in ally: range_val = ally.range_val

	var target = GameManager.combat_manager.find_nearest_enemy(ally.global_position, range_val)
	if target:
		var poison_script = load("res://src/Scripts/Effects/PoisonEffect.gd")
		target.apply_status(poison_script, {"duration": 5.0, "stacks": 2, "damage": 5.0})

func on_cleanup():
	for id in unit_spores:
		var ally = instance_from_id(id)
		if ally and is_instance_valid(ally):
			if ally.is_connected("damage_blocked", _on_spore_blocked):
				ally.damage_blocked.disconnect(_on_spore_blocked)
			ally.remove_meta("spore_shield")
