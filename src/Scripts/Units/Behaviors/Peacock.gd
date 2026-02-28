extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var attack_counter: int = 0
var feather_refs: Array = []

func on_cleanup():
	for q in feather_refs:
		if is_instance_valid(q):
			q.queue_free()
	feather_refs.clear()

func on_combat_tick(delta: float) -> bool:
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	var target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
	if !target: return true

	# Trigger special attack every 3rd attack (counter is 0, 1, 2 for attacks 1, 2, 3)
	if attack_counter >= 2:
		unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")
		attack_counter = 0

		if unit.visual_holder:
			var tween = unit.create_tween()
			tween.tween_property(unit.visual_holder, "scale", Vector2(1.3, 1.3), 0.1)
			tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.1)

		for q in feather_refs:
			if is_instance_valid(q) and q.has_method("recall"):
				q.recall()
		feather_refs.clear()

	elif target:
		# Use unit's helper to play animation, but handle spawn logic here
		_do_bow_attack(target)

	return true

func _do_bow_attack(target):
	var target_last_pos = target.global_position
	if unit.attack_cost_mana > 0: GameManager.consume_resource("mana", unit.attack_cost_mana)

	var anim_duration = clamp(unit.atk_speed * 0.8, 0.1, 0.6)
	unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	unit.play_attack_anim("bow", target_last_pos, anim_duration)

	var pull_time = anim_duration * 0.6
	await unit.get_tree().create_timer(pull_time).timeout

	if !is_instance_valid(unit): return

	_spawn_feathers(target_last_pos, target)

func _spawn_feathers(saved_target_pos: Vector2, target):
	if !GameManager.combat_manager: return

	var extra_shots = 0
	var multi_chance = 0.0

	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		var mech = unit.unit_data["levels"][str(unit.level)].get("mechanics", {})
		multi_chance = mech.get("multi_shot_chance", 0.0)

	if multi_chance > 0.0 and randf() < multi_chance:
		extra_shots += 1

	var use_target = null
	var base_angle = 0.0

	if is_instance_valid(target):
		use_target = target
		base_angle = (target.global_position - unit.global_position).angle()
	else:
		use_target = null # Explicitly null if freed
		base_angle = (saved_target_pos - unit.global_position).angle()

	# Fire Primary Feather
	var proj_args = {}
	if !use_target:
		proj_args["angle"] = base_angle
		proj_args["target_pos"] = saved_target_pos

	var proj = GameManager.combat_manager.spawn_projectile(unit, unit.global_position, use_target, proj_args)
	if proj and is_instance_valid(proj):
		feather_refs.append(proj)

	# Fire Extra Shots
	if extra_shots > 0:
		var spread_angle = 0.2
		var angles = [base_angle - spread_angle, base_angle + spread_angle]

		for i in range(extra_shots):
			var angle_mod = angles[i % 2]
			var dist = unit.global_position.distance_to(saved_target_pos)
			var extra_target_pos = unit.global_position + Vector2.RIGHT.rotated(angle_mod) * dist

			var extra_args = {"angle": angle_mod}
			if !use_target:
				extra_args["target_pos"] = extra_target_pos

			var extra_proj = GameManager.combat_manager.spawn_projectile(unit, unit.global_position, use_target, extra_args)
			if extra_proj and is_instance_valid(extra_proj):
				feather_refs.append(extra_proj)

	attack_counter += 1
