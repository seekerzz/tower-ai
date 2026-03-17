extends RefCounted
class_name UnitStatsComponent

const DamageContext = preload("res://src/Scripts/CoreMechanics/DamageContext.gd")

var unit: Node2D

var damage: float
var range_val: float
var atk_speed: float
var attack_cost_mana: float = 0.0
var skill_mana_cost: float = 30.0

var max_hp: float = 0.0
var current_hp: float = 0.0

var crit_rate: float = 0.0
var crit_dmg: float = 1.5

var dodge_rate: float = 0.0
var shield: float = 0.0

func _init(target_unit: Node2D):
	unit = target_unit

func reset_stats():
	var stats = {}
	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		stats = unit.unit_data["levels"][str(unit.level)]
	else:
		stats = unit.unit_data

	damage = stats.get("damage", unit.unit_data.get("damage", 0))
	max_hp = stats.get("hp", unit.unit_data.get("hp", 0))

	if current_hp > max_hp: current_hp = max_hp

	range_val = unit.unit_data.get("range", 0)
	atk_speed = unit.unit_data.get("atkSpeed", 1.0)

	crit_rate = unit.unit_data.get("crit_rate", 0.1)
	crit_dmg = unit.unit_data.get("crit_dmg", 1.5)

	attack_cost_mana = unit.unit_data.get("manaCost", 0.0)
	skill_mana_cost = unit.unit_data.get("skillCost", 30.0)

	if stats.has("mechanics"):
		var mechs = stats["mechanics"]
		if mechs.has("crit_rate_bonus"):
			crit_rate += mechs["crit_rate_bonus"]

	if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
		range_val *= 1.2

func process_hit_detection(context: DamageContext):
	# Attacker's Blindness
	if context.source and is_instance_valid(context.source):
		if "blind_timer" in context.source and context.source.blind_timer > 0:
			if randf() < 0.5: # 50% miss when blinded
				context.is_miss = true
				return

	# Defender's Dodge
	if dodge_rate > 0 and randf() < dodge_rate:
		context.is_dodge = true

func process_mitigation(context: DamageContext):
	var amount = context.final_damage

	# Guardian Shield (Legacy logic)
	if "guardian_shield" in unit.active_buffs:
		var source = unit.buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			amount = amount * (1.0 - reduction)

	# Unit Shield Component
	if shield > 0:
		var absorbed = min(shield, amount)
		shield -= absorbed
		amount -= absorbed
		context.shield_absorbed = absorbed
		# Emit AI signal
		GameManager.shield_absorbed.emit(unit, absorbed, shield, context.source)

	context.final_damage = amount

func apply_damage(context: DamageContext):
	var amount = context.final_damage

	if amount > 0:
		current_hp = max(0, current_hp - amount)
		GameManager.damage_core(amount)

	var blocked = context.base_damage - amount - context.shield_absorbed
	if blocked > 0:
		unit.damage_blocked.emit(blocked, context.source)

# DEPRECATED
func take_damage(amount: float, source_node = null) -> float:
	# This now routes through Unit.gd which creates a context
	# We can't easily return the final damage without a major rewrite of this deprecated stub,
	# but we can try to trigger the flow.
	unit.take_damage(amount, source_node)
	return amount # Note: this may differ from old behavior which returned reduced amount

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	GameManager.spawn_floating_text(unit.global_position, "+%d" % int(amount), Color.GREEN)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"crit_chance":
			crit_rate += amount
