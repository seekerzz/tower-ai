extends "res://src/Scripts/Units/Behaviors/FlyingMeleeBehavior.gd"

# Harpy Eagle - 角雕
# 三连爪击，第三次爪击暴击（Lv3）并施加流血

var claw_count: int = 3
var damage_per_claw: float = 0.6
var third_claw_bleed: bool = false
var _current_claw: int = 0
var _combo_target: Node2D = null

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_setup():
	_update_mechanics()

func _update_mechanics():
	var lvl_stats = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = lvl_stats.get("mechanics", {})
	damage_per_claw = mechanics.get("damage_per_claw", 0.6)
	third_claw_bleed = mechanics.get("third_claw_bleed", false)

func on_stats_updated():
	_update_mechanics()

func _get_target() -> Node2D:
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = unit.range_val

	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var dist = unit.global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _calculate_damage(target: Node2D) -> float:
	var dmg = unit.damage * damage_per_claw

	# Check crit logic for 3rd strike
	var effective_crit_rate = unit.crit_rate

	if _current_claw == 2:
		if unit.level == 1: effective_crit_rate *= 2
		elif unit.level == 2: effective_crit_rate *= 3
		elif unit.level >= 3: effective_crit_rate = 1.0

	if randf() < effective_crit_rate:
		dmg *= unit.crit_dmg
		GameManager.spawn_floating_text(target.global_position, "CRIT!", Color.RED)
		GameManager.projectile_crit.emit(unit, target, dmg)

	if _current_claw == 2 and third_claw_bleed and is_instance_valid(target):
		_apply_bleed(target)
		if unit.level >= 3:
			if target.has_method("add_bleed_stacks"):
				target.add_bleed_stacks(2, unit)
			GameManager.spawn_floating_text(target.global_position, "BLEED!", Color.RED)

	return dmg

func _apply_bleed(target: Node2D):
	if not target.has_method("apply_status"): return
	var bleed_script = load("res://src/Scripts/Effects/BleedEffect.gd")
	if bleed_script:
		target.apply_status(bleed_script, {
			"duration": 5.0,
			"source": unit
		})

func start_attack_sequence():
	_combo_target = current_target
	_current_claw = 0
	_start_claw_attack()

func _start_claw_attack():
	if not is_instance_valid(_combo_target):
		state = State.IDLE
		return

	state = State.WINDUP

	var interval_mod = 1.0
	if GameManager.has_method("get_stat_modifier"):
		interval_mod = GameManager.get_stat_modifier("attack_interval")

	var claw_interval = max(0.1, unit.atk_speed * interval_mod / claw_count)
	unit.cooldown = unit.atk_speed * interval_mod

	var t_windup = claw_interval * 0.3
	var t_attack = claw_interval * 0.2
	var t_impact = claw_interval * 0.1
	var t_return = claw_interval * 0.3
	var t_landing = claw_interval * 0.1

	if is_instance_valid(_combo_target):
		_target_cache_pos = _combo_target.global_position

	if _combat_tween: _combat_tween.kill()
	_combat_tween = unit.create_tween()

	if unit.visual_holder:
		var target_angle = _update_facing(_target_cache_pos)
		unit.visual_holder.rotation = target_angle
		var target_scale = Vector2(0.8, 1.2 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_windup)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		var pullback_dir = (unit.global_position - _target_cache_pos).normalized()
		if pullback_dir.length_squared() < 0.01: pullback_dir = Vector2.RIGHT
		_combat_tween.parallel().tween_property(unit.visual_holder, "position", pullback_dir * 10.0, t_windup)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_combat_tween.tween_interval(t_windup)

	_combat_tween.tween_callback(func(): _enter_claw_attack_out(t_attack, t_impact, t_return, t_landing))

func _enter_claw_attack_out(t_attack, t_impact, t_return, t_landing):
	state = State.ATTACK_OUT
	var target_pos = _target_cache_pos
	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		var target_angle = _update_facing(target_pos)
		unit.visual_holder.rotation = target_angle
		var target_scale = Vector2(1.6, 0.6 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_attack)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_combat_tween.parallel().tween_property(unit.visual_holder, "global_position", target_pos, t_attack)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		_combat_tween.tween_callback(func(): _enter_claw_impact(t_impact, t_return, t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_attack)
		_combat_tween.tween_callback(func(): _enter_claw_impact(t_impact, t_return, t_landing))

func _enter_claw_impact(t_impact, t_return, t_landing):
	state = State.IMPACT
	if is_instance_valid(_combo_target):
		var dmg = _calculate_damage(_combo_target)
		_combo_target.take_damage(dmg, unit, "physical")
		if GameManager.has_method("trigger_impact"):
			var dir = (_target_cache_pos - unit.global_position).normalized()
			GameManager.trigger_impact(dir, 0.3)
		var claw_text = ["CLAW 1", "CLAW 2", "CLAW 3"][_current_claw]
		GameManager.spawn_floating_text(_target_cache_pos, claw_text, Color.WHITE)

	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		var target_scale = Vector2(0.5, 1.5 * _current_y_scale_sign)
		var recovery_scale = Vector2(1.0, 1.0 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_impact * 0.5)\
			.set_trans(Tween.TRANS_BOUNCE)
		_combat_tween.tween_property(unit.visual_holder, "scale", recovery_scale, t_impact * 0.5)
		_combat_tween.tween_callback(func(): _enter_claw_return(t_return, t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_impact)
		_combat_tween.tween_callback(func(): _enter_claw_return(t_return, t_landing))

func _enter_claw_return(t_return, t_landing):
	state = State.RETURN
	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		var home_pos = unit.global_position
		var return_angle = _update_facing(home_pos)
		unit.visual_holder.rotation = return_angle
		unit.visual_holder.scale.y = abs(unit.visual_holder.scale.y) * _current_y_scale_sign
		var final_scale = Vector2(1.0, 1.0 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "position", Vector2.ZERO, t_return)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_combat_tween.parallel().tween_property(unit.visual_holder, "scale", final_scale, t_return)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_combat_tween.tween_callback(func(): _enter_claw_landing(t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_return)
		_combat_tween.tween_callback(func(): _enter_claw_landing(t_landing))

func _enter_claw_landing(t_landing):
	state = State.LANDING
	_current_claw += 1
	if _current_claw < claw_count and is_instance_valid(_combo_target):
		if is_instance_valid(_combo_target):
			_target_cache_pos = _combo_target.global_position
		_start_claw_attack()
	else:
		_finish_combo()

func _finish_combo():
	state = State.IDLE
	_combo_target = null
	_current_claw = 0
	if unit.visual_holder:
		unit.visual_holder.rotation = 0
		unit.visual_holder.scale = Vector2.ONE
		_current_y_scale_sign = 1.0
