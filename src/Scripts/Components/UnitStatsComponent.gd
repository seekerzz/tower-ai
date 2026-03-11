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

func take_damage(amount: float, source_enemy = null) -> float:
	var original_amount = amount

	if "guardian_shield" in unit.active_buffs:
		var source = unit.buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			amount = amount * (1.0 - reduction)

	amount = unit.behavior.on_damage_taken(amount, source_enemy)

	var blocked_amount = original_amount - amount
	if blocked_amount > 0:
		unit.damage_blocked.emit(blocked_amount, source_enemy)

	current_hp = max(0, current_hp - amount)
	GameManager.damage_core(amount)

	return amount

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	GameManager.spawn_floating_text(unit.global_position, "+%d" % int(amount), Color.GREEN)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"crit_chance":
			crit_rate += amount
