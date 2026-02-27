extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var hp_cost_percent: float = 0.20
var buff_active: bool = false

func on_skill_activated():
	var hp_cost = GameManager.core_health * hp_cost_percent
	if GameManager.core_health - hp_cost <= 0:
		GameManager.spawn_floating_text(unit.global_position, "Too Low HP!", Color.RED)
		return

	GameManager.damage_core(hp_cost)

	var bleed_stacks = 2 if unit.level < 2 else 3
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and unit.global_position.distance_to(enemy.global_position) <= unit.range_val:
			enemy.add_bleed_stacks(bleed_stacks, unit)

	if unit.level >= 3:
		_start_ritual_buff()

func _start_ritual_buff():
	if buff_active: return

	buff_active = true
	GameManager.apply_global_buff("lifesteal_multiplier", 2.0)
	GameManager.spawn_floating_text(unit.global_position, "Ritual!", Color.RED)

	# Wait 4 seconds then remove
	await unit.get_tree().create_timer(4.0).timeout

	if buff_active:
		GameManager.remove_global_buff("lifesteal_multiplier")
		buff_active = false

func on_cleanup():
	if buff_active:
		GameManager.remove_global_buff("lifesteal_multiplier")
		buff_active = false
