extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func on_combat_tick(delta: float) -> bool:
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	var target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
	if target:
		if unit.attack_cost_mana > 0:
			if !GameManager.check_resource("mana", unit.attack_cost_mana):
				unit.is_no_mana = true
				return true
			GameManager.consume_resource("mana", unit.attack_cost_mana)
			unit.is_no_mana = false

		unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

		unit.play_attack_anim("lightning", target.global_position)
		var hit_list = []
		var chain_count = unit.unit_data.get("chain", 0)
		GameManager.combat_manager.perform_lightning_attack(unit, unit.global_position, target, chain_count, hit_list)
		unit.attack_performed.emit(target)

		if AILogger:
			_log_lightning_chain(chain_count, hit_list, target)

	return true

func _log_lightning_chain(chain_count: int, hit_list: Array, first_target: Node2D):
	# Wait enough time for the recursive chain to finish
	await unit.get_tree().create_timer(0.15 * (chain_count + 1)).timeout

	if AILogger:
		var unit_id = unit.name if unit and "name" in unit else "未知单位"
		if unit and "type_key" in unit:
			unit_id = unit.type_key

		var jumps = hit_list.size()
		var single_dmg = 0
		if is_instance_valid(unit) and is_instance_valid(first_target):
			single_dmg = unit.calculate_damage_against(first_target)
		var total_dmg = jumps * single_dmg

		AILogger.eel_lightning_chain(unit_id, jumps, total_dmg)
