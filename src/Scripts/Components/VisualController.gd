extends Node2D

var wobble_scale: Vector2 = Vector2.ONE
var visual_offset: Vector2 = Vector2.ZERO
var visual_rotation: float = 0.0

var anim_config: Dictionary = {}
var base_speed: float = 40.0
var current_speed: float = 0.0
var anim_time: float = 0.0
var temp_speed_mod: float = 1.0
var is_idle_enabled: bool = true

var tween: Tween

func setup(config: Dictionary, b_speed: float, c_speed: float):
	anim_config = config
	base_speed = b_speed
	current_speed = c_speed

func update_speed(new_speed: float, mod: float):
	current_speed = new_speed
	temp_speed_mod = mod

func set_idle_enabled(enabled: bool):
	is_idle_enabled = enabled

func _process(delta):
	# If internal tween is running (e.g. elastic shoot), skip idle
	if tween and tween.is_valid():
		return

	# If external controller disabled idle (e.g. melee attack), skip idle
	if not is_idle_enabled:
		return

	if anim_config.is_empty():
		return

	var style = anim_config.get("style", "squash")
	var amp = anim_config.get("amplitude", 0.1)
	var freq = anim_config.get("base_freq", 1.0)

	# Avoid division by zero
	var effective_speed = current_speed
	if effective_speed < 1.0: effective_speed = 1.0

	# Dynamic frequency scaling: freq * (current_speed / base_speed)
	# If stationary (speed=0 in theory, but here speed is stat), use temp_speed_mod
	var speed_factor = (current_speed * temp_speed_mod) / max(1.0, base_speed)

	anim_time += delta * freq * speed_factor * 2.0

	match style:
		"squash":
			# Squash & Stretch
			var s = sin(anim_time)
			var y_scale = 1.0 + s * amp
			var x_scale = 1.0
			if y_scale > 0.01:
				x_scale = 1.0 / y_scale
			wobble_scale = Vector2(x_scale, y_scale)
			visual_offset = Vector2.ZERO
			visual_rotation = 0.0

		"bob":
			# Vertical bobbing
			var s = abs(sin(anim_time)) # Bob up and down (bounce)
			visual_offset = Vector2(0, -s * amp)
			wobble_scale = Vector2.ONE
			visual_rotation = 0.0

		"float":
			# Breathing / Floating
			var s = sin(anim_time)
			wobble_scale = Vector2.ONE * (1.0 + s * amp)
			visual_offset = Vector2.ZERO
			visual_rotation = 0.0

		"stiff":
			# Rotation wobble
			var s = sin(anim_time)
			visual_rotation = s * amp
			wobble_scale = Vector2.ONE
			visual_offset = Vector2.ZERO

		"bouncy_idle":
			# Q 弹待机
			var s = sin(anim_time)
			wobble_scale = Vector2(1.0 - s * amp * 0.5, 1.0 + s * amp * 0.5)
			visual_offset = Vector2(0, -abs(sin(anim_time)) * amp * 5.0)
			visual_rotation = 0.0

func play_elastic_shoot() -> Tween:
	kill_tween()
	tween = create_tween()

	# Prepare: Thin and lean back
	tween.set_parallel(true)
	tween.tween_property(self, "wobble_scale", Vector2(0.6, 1.4), 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "visual_rotation", deg_to_rad(-15), 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)

	# Shoot: Wide and forward
	tween.set_parallel(true)
	tween.tween_property(self, "wobble_scale", Vector2(1.4, 0.6), 0.1)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "visual_rotation", deg_to_rad(10), 0.1)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)

	# Recover
	tween.tween_property(self, "wobble_scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "visual_rotation", 0.0, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	return tween

func play_elastic_slash() -> Tween:
	kill_tween()
	tween = create_tween()

	# Windup: Rotate back
	tween.tween_property(self, "visual_rotation", deg_to_rad(-45), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Slash: Fast rotate forward
	tween.tween_property(self, "visual_rotation", deg_to_rad(90), 0.1)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Recover
	tween.tween_property(self, "visual_rotation", 0.0, 0.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	return tween

func play_death_implosion() -> Tween:
	kill_tween()
	tween = create_tween()

	# Swell
	tween.tween_property(self, "wobble_scale", Vector2(1.2, 1.2), 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Implode
	tween.set_parallel(true)
	tween.tween_property(self, "wobble_scale", Vector2.ZERO, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "visual_rotation", deg_to_rad(720), 0.5)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)

	return tween

func kill_tween():
	if tween and tween.is_valid():
		tween.kill()

func apply_to(target: Control):
	if !is_instance_valid(target): return

	target.scale = wobble_scale
	target.position = -target.size / 2 + visual_offset
	target.rotation = visual_rotation
	target.pivot_offset = target.size / 2
