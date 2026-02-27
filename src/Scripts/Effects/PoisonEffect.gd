extends "res://src/Scripts/Effects/StatusEffect.gd"

var base_damage: float = 0.0
var tick_timer: float = 0.0
const MAX_STACKS = 50 # Constants.POISON_MAX_STACKS was used

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)
	type_key = "poison"
	base_damage = params.get("damage", 10.0)

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
	if host.modulate.b > host.modulate.r + 0.2: # Rough check for blue tint
		pass
	else:
		host.modulate = col

func _exit_tree():
	var host = get_parent()
	if host:
		host.modulate = Color.WHITE
