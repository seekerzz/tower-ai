extends "res://src/Scripts/Units/UnitBehavior.gd"

enum State {
	IDLE,
	WINDUP,
	ATTACK_OUT,
	IMPACT,
	RETURN,
	LANDING
}

var state: State = State.IDLE
var current_target: Node2D = null
var _target_cache_pos: Vector2 = Vector2.ZERO
var _combat_tween: Tween = null
var sprite_faces_left: bool = true

# Scale modifier to keep "Head Up"
# 1.0 = Standard (Left Target)
# -1.0 = Flipped Vertical + Rotated (Right Target) -> Looks like Horizontal Flip
var _current_y_scale_sign: float = 1.0

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_combat_tick(delta: float) -> bool:
	# Decrement cooldown if in IDLE
	if state == State.IDLE:
		if unit.cooldown > 0:
			unit.cooldown -= delta
			return true

		# Cooldown ready, look for target
		current_target = _get_target()
		if current_target:
			start_attack_sequence()
		return true

	# Logic during states
	if state == State.WINDUP:
		if is_instance_valid(current_target):
			_target_cache_pos = current_target.global_position

		# NOTE: We do not continuously rotate here anymore to avoid conflicting
		# with the flip logic (which might require a snap if target crosses X-axis).
		# We rely on the initial aim in start_attack_sequence and re-aim in ATTACK_OUT.

	return true

# Helper to determine facing and rotation
# Returns the target rotation angle
func _update_facing(target_pos: Vector2) -> float:
	var dir = target_pos - unit.visual_holder.global_position

	# Determine Scale Sign (Horizontal Flip Logic via Vertical Flip + Rotation)
	# If Target is Right (> 0), we want to Face Right.
	# Sprite Faces Left (-X). Rotation PI -> Right. Upside Down.
	# Flip Y (-1) -> Right Upright.
	if dir.x > 0:
		_current_y_scale_sign = -1.0
	else:
		_current_y_scale_sign = 1.0

	var angle = dir.angle()
	if sprite_faces_left:
		angle -= PI

	return angle

func start_attack_sequence():
	state = State.WINDUP

	var interval_mod = 1.0
	if GameManager.has_method("get_stat_modifier"):
		interval_mod = GameManager.get_stat_modifier("attack_interval")

	var total_duration = max(0.1, unit.atk_speed * interval_mod)
	unit.cooldown = total_duration

	# Phase Durations
	var t_windup = total_duration * 0.3
	var t_attack = total_duration * 0.1
	var t_impact = total_duration * 0.05
	var t_return = total_duration * 0.35
	var t_landing = total_duration * 0.2

	if is_instance_valid(current_target):
		_target_cache_pos = current_target.global_position

	if _combat_tween: _combat_tween.kill()
	_combat_tween = unit.create_tween()

	# 1. WINDUP
	if unit.visual_holder:
		# Initial aim snap & Facing update
		var target_angle = _update_facing(_target_cache_pos)
		unit.visual_holder.rotation = target_angle

		# Anticipation
		# Scale: (0.8, 1.2). Multiply Y by sign.
		var target_scale = Vector2(0.8, 1.2 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_windup)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

		# Move back slightly (Anticipation opposite to target direction)
		# We calculate the vector in parent space (Unit space)
		var pullback_dir = (unit.global_position - _target_cache_pos).normalized()
		if pullback_dir.length_squared() < 0.01: pullback_dir = Vector2.RIGHT

		_combat_tween.parallel().tween_property(unit.visual_holder, "position", pullback_dir * 20.0, t_windup)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	else:
		_combat_tween.tween_interval(t_windup)

	_combat_tween.tween_callback(func(): _enter_attack_out(t_attack, t_impact, t_return, t_landing))

func _enter_attack_out(t_attack, t_impact, t_return, t_landing):
	state = State.ATTACK_OUT

	var target_pos = _target_cache_pos

	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()

		# Re-Aim (Target might have moved)
		var target_angle = _update_facing(target_pos)
		unit.visual_holder.rotation = target_angle

		# Stretch (1.6, 0.6)
		var target_scale = Vector2(1.6, 0.6 * _current_y_scale_sign)

		# Ensure we start from current scale logic (optional, but tween handles it)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_attack)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		# Move to Global Target
		_combat_tween.parallel().tween_property(unit.visual_holder, "global_position", target_pos, t_attack)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		_combat_tween.tween_callback(func(): _enter_impact(t_impact, t_return, t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_attack)
		_combat_tween.tween_callback(func(): _enter_impact(t_impact, t_return, t_landing))

func _enter_impact(t_impact, t_return, t_landing):
	state = State.IMPACT

	if is_instance_valid(current_target):
		var dmg = _calculate_damage(current_target)
		current_target.take_damage(dmg, unit, "physical")

		if GameManager.has_method("trigger_impact"):
			var dir = (current_target.global_position - unit.global_position).normalized()
			GameManager.trigger_impact(dir, 0.5)

		GameManager.spawn_floating_text(_target_cache_pos, "HIT!", Color.WHITE)

	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()

		# Impact Squash (0.5, 1.5)
		var target_scale = Vector2(0.5, 1.5 * _current_y_scale_sign)
		var recovery_scale = Vector2(1.0, 1.0 * _current_y_scale_sign)

		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_impact * 0.5)\
			.set_trans(Tween.TRANS_BOUNCE)
		_combat_tween.tween_property(unit.visual_holder, "scale", recovery_scale, t_impact * 0.5)

		_combat_tween.tween_callback(func(): _enter_return(t_return, t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_impact)
		_combat_tween.tween_callback(func(): _enter_return(t_return, t_landing))

func _enter_return(t_return, t_landing):
	state = State.RETURN

	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()

		# Face Home
		var home_pos = unit.global_position
		# Use update_facing to set correct sign for return trip
		var return_angle = _update_facing(home_pos)
		unit.visual_holder.rotation = return_angle

		# Return Stretch (1.2, 0.9)
		# Note: We set scale immediately or tween? Tween is better.
		# But since we might have flipped sign in _update_facing just now,
		# the current scale.y might be wrong sign.
		# We should probably force set the current scale to match new sign before tweening?
		# Or rely on Tween to flip it (might look like it turns inside out).
		# Since return is a "turn around", an instant flip is acceptable or even desirable.
		unit.visual_holder.scale.y = abs(unit.visual_holder.scale.y) * _current_y_scale_sign

		var target_scale = Vector2(1.2, 0.9 * _current_y_scale_sign)
		var final_scale = Vector2(1.0, 1.0 * _current_y_scale_sign)

		# Move back to local zero
		_combat_tween.tween_property(unit.visual_holder, "position", Vector2.ZERO, t_return)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		_combat_tween.parallel().tween_property(unit.visual_holder, "scale", final_scale, t_return)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		_combat_tween.tween_callback(func(): _enter_landing(t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_return)
		_combat_tween.tween_callback(func(): _enter_landing(t_landing))

func _enter_landing(t_landing):
	state = State.LANDING

	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()

		# Reset rotation
		_combat_tween.tween_property(unit.visual_holder, "rotation", 0.0, t_landing * 0.3)

		# Landing Wobble with reset sign (1.0)
		# We should transition _current_y_scale_sign back to 1.0?
		# If we flip back to 1.0 instantly, it might pop.
		# Let's keep the sign for the wobble, then reset at end.

		var s1 = Vector2(1.1, 0.9 * _current_y_scale_sign)
		var s2 = Vector2(0.95, 1.05 * _current_y_scale_sign)
		var s_end = Vector2(1.0, 1.0 * _current_y_scale_sign) # End with current sign

		_combat_tween.parallel().tween_property(unit.visual_holder, "scale", s1, t_landing * 0.3)
		_combat_tween.tween_property(unit.visual_holder, "scale", s2, t_landing * 0.3)
		_combat_tween.tween_property(unit.visual_holder, "scale", s_end, t_landing * 0.4)

		_combat_tween.tween_callback(func():
			state = State.IDLE
			current_target = null
			unit.visual_holder.rotation = 0
			# Reset scale to pure 1.0
			unit.visual_holder.scale = Vector2.ONE
			_current_y_scale_sign = 1.0
		)
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_landing)
		_combat_tween.tween_callback(func():
			state = State.IDLE
			current_target = null
		)

func on_cleanup():
	if _combat_tween:
		_combat_tween.kill()

# Virtual Methods to be overridden by subclasses
func _get_target() -> Node2D:
	return null

func _calculate_damage(target: Node2D) -> float:
	return unit.damage
