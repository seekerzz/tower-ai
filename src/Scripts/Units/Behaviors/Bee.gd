extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func on_combat_tick(delta: float) -> bool:
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	var target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
	if target:
		_do_bow_attack(target)
	return true

func _do_bow_attack(target, on_release_callback: Callable = Callable()):
	var target_last_pos = target.global_position

	if unit.attack_cost_mana > 0:
		if !GameManager.check_resource("mana", unit.attack_cost_mana):
			unit.is_no_mana = true
			return
		GameManager.consume_resource("mana", unit.attack_cost_mana)
		unit.is_no_mana = false

	var anim_duration = clamp(unit.atk_speed * 0.8, 0.1, 0.6)
	unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	unit.play_attack_anim("bow", target_last_pos, anim_duration)

	var pull_time = anim_duration * 0.6
	await unit.get_tree().create_timer(pull_time).timeout

	if !is_instance_valid(unit): return

	if on_release_callback.is_valid():
		on_release_callback.call(target_last_pos)
	else:
		if GameManager.combat_manager:
			if is_instance_valid(target):
				GameManager.combat_manager.spawn_projectile(unit, unit.global_position, target)
				unit.attack_performed.emit(target)
			else:
				var angle = (target_last_pos - unit.global_position).angle()
				GameManager.combat_manager.spawn_projectile(unit, unit.global_position, null, {"angle": angle, "target_pos": target_last_pos})
				unit.attack_performed.emit(null)
