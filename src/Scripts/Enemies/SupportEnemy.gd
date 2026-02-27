extends "res://src/Scripts/Enemy.gd"

# Base class for support enemies (Healers, Buffers)

var support_cooldown_timer: float = 0.0
var support_cast_timer: float = 0.0
var current_support_target: Node2D = null
var is_casting_support: bool = false

# Configuration (defaults, can be overridden by enemy_data)
var support_range: float = 200.0
var support_cooldown: float = 3.0
var support_cast_time: float = 0.5
var heal_power: float = 20.0 # Generic power value

func _ready():
	super._ready()
	if enemy_data:
		support_range = enemy_data.get("heal_range", support_range)
		support_cooldown = enemy_data.get("heal_cooldown", support_cooldown)
		heal_power = enemy_data.get("heal_power", heal_power)
		support_cast_time = enemy_data.get("cast_time", support_cast_time)

func _physics_process(delta):
	# If wave is not active, do nothing
	if !GameManager.is_wave_active:
		super._physics_process(delta)
		return

	# If stunned, frozen or dying, let super handle it entirely.
	# Enemy.gd handles stun/freeze/knockback at the beginning of _physics_process.
	if stun_timer > 0 or freeze_timer > 0 or is_dying or knockback_velocity.length() > 10.0:
		if is_casting_support:
			interrupt_support()
		super._physics_process(delta)
		return

	# Support Cooldown
	if support_cooldown_timer > 0:
		support_cooldown_timer -= delta

	# State Machine extension
	if state == State.SUPPORT:
		_process_support_state(delta)
		# Call super to handle effects, visual updates, etc.
		# super's match block will do nothing for SUPPORT state.
		# super calls handle_collisions at the end.
		super._physics_process(delta)
	else:
		# Check if we should switch to support mode
		# We prioritize support over moving or attacking base
		if (state == State.MOVE or state == State.ATTACK_BASE) and support_cooldown_timer <= 0:
			var target = find_support_target()
			if target:
				start_support_action(target)
				# Do not call super logic for move this frame if we just switched?
				# Calling super is fine, it will process the current state (which is now SUPPORT)
				# But wait, if I set state to SUPPORT here, and call super, super will see SUPPORT and do nothing in match block.
				# So that's correct.

		super._physics_process(delta)

func _process_support_state(delta):
	velocity = Vector2.ZERO

	if is_casting_support:
		support_cast_timer -= delta
		if support_cast_timer <= 0:
			if is_instance_valid(current_support_target):
				perform_support_action(current_support_target)
			finish_support_action()

func start_support_action(target):
	current_support_target = target
	state = State.SUPPORT
	is_casting_support = true
	support_cast_timer = support_cast_time
	velocity = Vector2.ZERO

	# Visual feedback for casting start
	if visual_controller:
		# Scale wobble to indicate charging
		var tween = create_tween()
		tween.tween_property(visual_controller, "wobble_scale", Vector2(1.2, 0.8), support_cast_time * 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(visual_controller, "wobble_scale", Vector2(0.8, 1.2), support_cast_time * 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(visual_controller, "wobble_scale", Vector2.ONE, 0.1)

func finish_support_action():
	is_casting_support = false
	state = State.MOVE
	support_cooldown_timer = support_cooldown
	current_support_target = null

func interrupt_support():
	is_casting_support = false
	current_support_target = null
	# We don't set state here because the interruption source (stun) sets it in super.

func find_support_target() -> Node2D:
	return null

func perform_support_action(target):
	pass
