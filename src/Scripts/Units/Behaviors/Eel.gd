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
		GameManager.combat_manager.perform_lightning_attack(unit, unit.global_position, target, unit.unit_data.get("chain", 0))
		unit.attack_performed.emit(target)

	return true
