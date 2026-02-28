extends "res://src/Scripts/Effects/StatusEffect.gd"

var base_damage: float = 0.0
var tick_timer: float = 0.0
const MAX_STACKS = 25 # 从50层降低到25层，提升堆叠效率

# Visual feedback properties
var _stack_indicator: Label = null
var _max_stack_glow: ColorRect = null

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)
	type_key = "poison"
	base_damage = params.get("damage", 15.0)  # 基础伤害从10提升到15
	_call_deferred_setup_visuals()

func _call_deferred_setup_visuals():
	# Defer visual setup to ensure host is ready
	if get_parent():
		_setup_stack_indicator()

func _setup_stack_indicator():
	var host = get_parent()
	if not host: return

	# Create or get stack indicator
	_stack_indicator = host.get_node_or_null("PoisonStackIndicator")
	if not _stack_indicator:
		_stack_indicator = Label.new()
		_stack_indicator.name = "PoisonStackIndicator"
		_stack_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stack_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stack_indicator.add_theme_font_size_override("font_size", 16)
		_stack_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
		_stack_indicator.add_theme_constant_override("outline_size", 3)
		_stack_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(_stack_indicator)

	_update_stack_visuals()

func _get_stack_color() -> Color:
	# Color gradient based on stack count
	if stacks <= 10:
		return Color(0.18, 0.8, 0.44)  # #2ecc71 - Green
	elif stacks <= 20:
		return Color(0.94, 0.77, 0.06)  # #f1c40f - Yellow-Green
	elif stacks <= 30:
		return Color(0.9, 0.49, 0.13)   # #e67e22 - Orange
	else:
		return Color(0.91, 0.3, 0.24)   # #e74c3c - Red

func _update_stack_visuals():
	if not _stack_indicator: return

	var host = get_parent()
	if not host: return

	# Update text
	_stack_indicator.text = str(min(stacks, MAX_STACKS))
	_stack_indicator.add_theme_color_override("font_color", _get_stack_color())

	# Position above enemy
	var radius = 20.0
	if host.get("enemy_data") and host.enemy_data is Dictionary and host.enemy_data.has("radius"):
		radius = host.enemy_data.radius
	_stack_indicator.position = Vector2(-15, -radius - 35)
	_stack_indicator.size = Vector2(30, 20)

	# Show/hide based on stacks
	_stack_indicator.visible = stacks > 0

	# Max stack glow effect
	if stacks >= MAX_STACKS:
		_show_max_stack_glow()
	else:
		_hide_max_stack_glow()

func _show_max_stack_glow():
	var host = get_parent()
	if not host: return

	_max_stack_glow = host.get_node_or_null("MaxStackGlow")
	if not _max_stack_glow:
		_max_stack_glow = ColorRect.new()
		_max_stack_glow.name = "MaxStackGlow"
		_max_stack_glow.color = Color(0.2, 1.0, 0.2, 0.3)
		_max_stack_glow.size = Vector2(60, 60)
		_max_stack_glow.position = Vector2(-30, -30)
		_max_stack_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Add a circular mask or shader effect would be ideal, using simple rect for now
		host.add_child(_max_stack_glow)
		_max_stack_glow.z_index = -1

	# Pulse animation
	if not _max_stack_glow.has_meta("pulsing"):
		_max_stack_glow.set_meta("pulsing", true)
		var tween = create_tween().set_loops()
		tween.tween_property(_max_stack_glow, "color:a", 0.6, 0.5)
		tween.tween_property(_max_stack_glow, "color:a", 0.2, 0.5)

func _hide_max_stack_glow():
	if _max_stack_glow and is_instance_valid(_max_stack_glow):
		_max_stack_glow.queue_free()
		_max_stack_glow = null

func apply(delta: float):
	super.apply(delta)

	tick_timer += delta
	if tick_timer >= 1.0: # Tick interval
		tick_timer -= 1.0
		_deal_damage()

	_update_visuals()

func stack(params: Dictionary):
	super.stack(params)
	if stacks > MAX_STACKS:
		stacks = MAX_STACKS
	# Update visual indicator when stacks change
	_update_stack_visuals()

func _deal_damage():
	var host = get_parent()
	if host and host.has_method("take_damage"):
		var dmg = base_damage * stacks
		host.take_damage(dmg, source_unit, "poison")
		# Emit signal for test logging
		if GameManager.has_signal("poison_damage"):
			GameManager.poison_damage.emit(host, dmg, stacks, source_unit)

func _update_visuals():
	var host = get_parent()
	if not host: return

	# Update stack indicator
	_update_stack_visuals()

	# Basic visual feedback (green tint)
	# This might conflict with Freeze, but following the "Component" pattern,
	# the component should try to do its job.
	# To avoid conflict with Freeze, we could check if host is frozen.
	# But host.frozen might not be a property yet.
	# For now, let's just apply tint if not heavily tinted?

	# Replicating original logic:
	# t = stacks / 10.0
	# modulate = lerp(white, green, t)

	var t = clamp(float(stacks) / 10.0, 0.0, 1.0)
	var col = Color.WHITE.lerp(Color(0.2, 1.0, 0.2), t)

	# We only apply if we are the dominant effect or just apply it.
	# If we want to be safe, we can skip if host.modulate is blue (Frozen).
	if "modulate" in host and host.modulate is Color:
		if host.modulate.b > host.modulate.r + 0.2: # Rough check for blue tint
			pass
		else:
			host.modulate = col

func _on_host_died():
	# Poison explosion logic - similar to burn explosion but spreads poison
	var host = get_parent()
	if not host: return

	var center = host.global_position
	var explosion_damage = base_damage * stacks * 0.5  # 50% of normal poison damage

	# Visual effect - green cross explosion
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	host.get_parent().call_deferred("add_child", effect)
	effect.global_position = center
	effect.configure("cross", Color.GREEN)
	effect.scale = Vector2(2, 2)
	effect.play()

	# Damage area and spread poison (delegate to CombatManager)
	if GameManager.combat_manager:
		GameManager.combat_manager.trigger_poison_explosion(center, explosion_damage, stacks, source_unit)

	# Emit signal for test logging
	if GameManager.has_signal("poison_explosion"):
		GameManager.poison_explosion.emit(center, explosion_damage, stacks, source_unit)

func _exit_tree():
	var host = get_parent()
	if host and "modulate" in host:
		host.modulate = Color.WHITE
	# Clean up visual indicators
	if _stack_indicator and is_instance_valid(_stack_indicator):
		_stack_indicator.queue_free()
		_stack_indicator = null
	_hide_max_stack_glow()
