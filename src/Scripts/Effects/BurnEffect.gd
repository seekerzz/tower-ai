extends "res://src/Scripts/Effects/StatusEffect.gd"

var base_damage: float = 0.0
var explosion_damage: float = 0.0
var tick_timer: float = 0.0
const TICK_INTERVAL = 0.5

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)
	type_key = "burn"
	base_damage = params.get("damage", 10.0)
	explosion_damage = params.get("explosion_damage", base_damage * 3.0)

func apply(delta: float):
	super.apply(delta)

	tick_timer += delta
	if tick_timer >= 1.0:
		tick_timer -= 1.0
		_deal_damage()

func stack(params: Dictionary):
	super.stack(params)
	pass

func _deal_damage():
	var host = get_parent()
	if host and host.has_method("take_damage"):
		var dmg = base_damage * stacks
		host.take_damage(dmg, source_unit, "fire")

func _on_host_died():
	# Explosion logic
	var host = get_parent()
	if not host: return

	var center = host.global_position
	var final_explosion_damage = explosion_damage * stacks

	# Visual
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	# Add visual to map/parent of host to persist
	host.get_parent().call_deferred("add_child", effect)
	effect.global_position = center
	effect.configure("cross", Color.ORANGE)
	effect.scale = Vector2(3, 3)
	effect.play()

	# Damage Area (Delegate to CombatManager to avoid race condition on death)
	if GameManager.combat_manager:
		GameManager.combat_manager.trigger_burn_explosion(center, final_explosion_damage, source_unit)
