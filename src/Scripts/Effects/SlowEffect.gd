extends "res://src/Scripts/Effects/StatusEffect.gd"

var slow_factor: float = 0.5
var original_val_cache: float = 0.0
var applied: bool = false

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)
	type_key = "slow"
	slow_factor = params.get("slow_factor", 0.5)

	_apply_slow()

func stack(params: Dictionary):
	super.stack(params)
	# Refreshing duration is handled in base.
	# Should we update slow_factor if the new one is stronger?
	var new_factor = params.get("slow_factor", 0.5)
	if new_factor < slow_factor: # Lower factor = stronger slow
		_remove_slow()
		slow_factor = new_factor
		_apply_slow()

func _apply_slow():
	var host = get_parent()
	if host and "speed" in host:
		# We assume speed is a simple float variable
		# Issue: if we just multiply, we need to know what to divide by later,
		# OR we need a modifier system.
		# Simple approach: multiply and remember we did it.

		# To be safer against floating point drift or multiple modifications:
		# It's better if Enemy has a method.
		# For now, we modify directly but maybe we should store the amount we removed?

		var lost = host.speed * (1.0 - slow_factor)
		host.speed -= lost
		original_val_cache = lost
		applied = true

		# Visual
		host.modulate = Color(0.5, 0.5, 1.0)

func _remove_slow():
	if not applied: return
	var host = get_parent()
	if host and is_instance_valid(host) and "speed" in host:
		host.speed += original_val_cache
		host.modulate = Color.WHITE # Restore color (might conflict with Poison, but ok for now)
	applied = false

func _exit_tree():
	_remove_slow()
