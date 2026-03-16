extends RefCounted
class_name UnitStatsComponent

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

var dodge_chance: float = 0.0
var shield: float = 0.0
var damage_reduction: float = 0.0

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

	dodge_chance = unit.unit_data.get("dodge_chance", 0.0)
	shield = unit.unit_data.get("shield", 0.0)
	damage_reduction = unit.unit_data.get("damage_reduction", 0.0)

	attack_cost_mana = unit.unit_data.get("manaCost", 0.0)
	skill_mana_cost = unit.unit_data.get("skillCost", 30.0)

	if stats.has("mechanics"):
		var mechs = stats["mechanics"]
		if mechs.has("crit_rate_bonus"):
			crit_rate += mechs["crit_rate_bonus"]

	if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
		range_val *= 1.2

func pre_damage_hit() -> bool:
	print("[Combat] Checking Dodge... dodge_chance=", dodge_chance)
	if dodge_chance > 0.0 and randf() < dodge_chance:
		print("[Combat] Dodged!")
		GameManager.ftext_spawn_requested.emit(unit.global_position, "Dodge", Color.WHITE, Vector2.ZERO)
		return true
	return false

func calculate_mitigation(amount: float) -> float:
	var mitigated_amount = amount
	print("[Combat] Mitigation Start. amount=", amount, " dmg_reduction=", damage_reduction, " shield=", shield)

	if "guardian_shield" in unit.active_buffs:
		var source = unit.buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			mitigated_amount = mitigated_amount * (1.0 - reduction)
			print("[Combat] Guardian Shield active. amount=", mitigated_amount)

	if damage_reduction > 0.0:
		mitigated_amount = mitigated_amount * (1.0 - damage_reduction)
		print("[Combat] Damage Reduction active. amount=", mitigated_amount)

	if shield > 0.0:
		var shield_absorb = min(shield, mitigated_amount)
		shield -= shield_absorb
		mitigated_amount -= shield_absorb
		print("[Combat] Shield Absorb: ", shield_absorb, " Remaining amount=", mitigated_amount)

	return mitigated_amount

func on_damage_applied(amount: float):
	current_hp = max(0, current_hp - amount)
	GameManager.damage_core(amount)

	if unit.visual_component:
		unit.visual_component.play_damage_hit_anim()

func post_damage(final_amount: float, original_amount: float, source_enemy) -> float:
	var context = {
		"amount": final_amount,
		"original_amount": original_amount,
		"source": source_enemy
	}
	var behavior_amount = unit.behavior.on_damage_taken(context)

	var blocked_amount = original_amount - behavior_amount
	if blocked_amount > 0:
		unit.damage_blocked.emit(blocked_amount, source_enemy)

	return behavior_amount

func take_damage(amount: float, source_enemy = null) -> float:
	if pre_damage_hit():
		return 0.0

	var mitigated_amount = calculate_mitigation(amount)
	var original_amount = amount

	var final_amount = post_damage(mitigated_amount, original_amount, source_enemy)

	on_damage_applied(final_amount)

	return final_amount

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	GameManager.spawn_floating_text(unit.global_position, "+%d" % int(amount), Color.GREEN)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"crit_chance":
			crit_rate += amount
