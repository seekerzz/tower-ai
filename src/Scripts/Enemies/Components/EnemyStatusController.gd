extends RefCounted
class_name EnemyStatusController

const StatusEffect = preload("res://src/Scripts/Effects/StatusEffect.gd")

var enemy: CharacterBody2D

func _init(target_enemy: CharacterBody2D):
	enemy = target_enemy

func process_environmental_cooldowns(delta: float):
	var finished = []
	for trap_id in enemy._env_cooldowns:
		enemy._env_cooldowns[trap_id] -= delta
		if enemy._env_cooldowns[trap_id] <= 0:
			finished.append(trap_id)
	for id in finished:
		enemy._env_cooldowns.erase(id)

func process_blind_timer(delta: float):
	if enemy.blind_timer > 0:
		enemy.blind_timer -= delta

func process_stun_timer(delta: float):
	if enemy.stun_timer > 0:
		enemy.stun_timer -= delta

func handle_environmental_impact(trap_node):
	var trap_id = trap_node.get_instance_id()
	if enemy._env_cooldowns.has(trap_id) and enemy._env_cooldowns[trap_id] > 0:
		return
	if not trap_node.props:
		return
	var type = trap_node.props.get("type")
	if type == "reflect":
		enemy.take_damage(trap_node.props.get("strength", 10.0), trap_node, "physical")
		enemy._env_cooldowns[trap_id] = 0.5
	elif type == "poison":
		enemy.apply_status(load("res://src/Scripts/Effects/PoisonEffect.gd"), {"duration": 3.0, "damage": 10.0, "stacks": 1})
		enemy._env_cooldowns[trap_id] = 0.5
	elif type == "slow":
		enemy.apply_status(load("res://src/Scripts/Effects/SlowEffect.gd"), {"duration": 0.1, "slow_factor": 0.5})
	if trap_node.has_method("spawn_splash_effect"):
		trap_node.spawn_splash_effect(enemy.global_position)

func apply_status(effect_script: Script, params: Dictionary):
	if not effect_script:
		return
	var effect_ref = null
	for c in enemy.get_children():
		if c.get_script() == effect_script:
			effect_ref = c
			break
	if effect_ref:
		effect_ref.stack(params)
	else:
		effect_ref = effect_script.new()
		enemy.add_child(effect_ref)
		effect_ref.setup(enemy, params.get("source", null), params)

	if effect_ref and "type_key" in effect_ref:
		var stacks = effect_ref.stacks if "stacks" in effect_ref else params.get("stacks", 1)
		GameManager.debuff_applied.emit(enemy, effect_ref.type_key, stacks)

func add_poison_stacks(amount: int):
	apply_status(load("res://src/Scripts/Effects/PoisonEffect.gd"), {
		"duration": 5.0,
		"damage": 10.0,
		"stacks": amount,
		"source": null
	})

func apply_stun(duration: float):
	enemy.stun_timer = duration
	GameManager.spawn_floating_text(enemy.global_position, "Stunned!", Color.GRAY)

func apply_freeze(duration: float):
	enemy.freeze_timer = duration
	GameManager.spawn_floating_text(enemy.global_position, "Frozen!", Color.CYAN)
	if GameManager.has_signal("freeze_applied"):
		GameManager.freeze_applied.emit(enemy, duration, null)

func apply_blind(duration: float):
	enemy.blind_timer = duration
	GameManager.spawn_floating_text(enemy.global_position, "Blind!", Color.GRAY)

func apply_debuff(type: String, stacks: int = 1):
	match type:
		"poison":
			apply_status(load("res://src/Scripts/Effects/PoisonEffect.gd"), {"duration": 5.0, "damage": 20.0, "stacks": stacks})
		"burn":
			apply_status(load("res://src/Scripts/Effects/BurnEffect.gd"), {"duration": 5.0, "damage": 20.0, "stacks": stacks})
		"bleed":
			enemy.add_bleed_stacks(stacks)
		"slow":
			apply_status(load("res://src/Scripts/Effects/SlowEffect.gd"), {"duration": 3.0, "slow_factor": 0.5})

func add_debuff(type: String, stacks: int, duration: float):
	if type == "vulnerable":
		apply_status(load("res://src/Scripts/Effects/VulnerableEffect.gd"), {"duration": duration, "stacks": stacks})

func has_status(type_key: String) -> bool:
	for c in enemy.get_children():
		if c is StatusEffect and c.type_key == type_key:
			return true
	return false

func is_trap(node) -> bool:
	if node.get("type") and Constants.BARRICADE_TYPES.has(node.type):
		var b_type = Constants.BARRICADE_TYPES[node.type].type
		return b_type == "slow" or b_type == "poison" or b_type == "reflect"
	return false
