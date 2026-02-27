extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var chained_enemies: Array = []
var drain_interval: float = 1.0
var drain_timer: float = 0.0

func on_tick(delta: float):
	drain_timer += delta
	if drain_timer >= drain_interval:
		drain_timer = 0.0
		_drain_life()

func _update_chain_targets():
	if not GameManager.combat_manager: return
	var enemies = unit.get_tree().get_nodes_in_group("enemies")

	var valid_enemies = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.hp > 0:
			valid_enemies.append(enemy)

	valid_enemies.sort_custom(func(a, b):
		return unit.global_position.distance_to(a.global_position) > unit.global_position.distance_to(b.global_position)
	)

	var max_chains = 1 if unit.level < 2 else 2
	chained_enemies = valid_enemies.slice(0, max_chains)
	unit.queue_redraw()

func _drain_life():
	_update_chain_targets()

	var total_drained = 0.0
	for enemy in chained_enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue

		var drain_amount = 4.0
		if enemy.has_method("take_damage"):
			enemy.take_damage(drain_amount, unit, "magic")
			total_drained += drain_amount
			GameManager.spawn_floating_text(enemy.global_position, "-%.1f" % drain_amount, Color.PURPLE)

	if total_drained > 0:
		GameManager.heal_core(total_drained)
		GameManager.spawn_floating_text(unit.global_position, "+%.1f" % total_drained, Color.GREEN)

	if unit.level >= 3:
		_apply_damage_distribution()

func _apply_damage_distribution():
	for enemy in chained_enemies:
		if not is_instance_valid(enemy): continue
		var nearby = _get_enemies_in_range(enemy.global_position, 100.0)
		for n in nearby:
			if n != enemy:
				n.take_damage(2.0, unit, "magic")

func _get_enemies_in_range(pos: Vector2, r: float) -> Array:
	var list = []
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= r:
			list.append(e)
	return list
