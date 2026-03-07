extends Node
class_name UnitStats

var unit: Node2D

var damage: float = 0.0
var range_val: float = 0.0
var atk_speed: float = 0.0
var attack_cost_mana: float = 0.0
var skill_mana_cost: float = 30.0

var max_hp: float = 0.0
var current_hp: float = 0.0

var crit_rate: float = 0.0
var crit_dmg: float = 1.5

func _init():
	pass

func take_damage(amount: float):
	current_hp -= amount
	if current_hp < 0:
		current_hp = 0

func heal(amount: float):
	current_hp += amount
	if current_hp > max_hp:
		current_hp = max_hp

func reset_stats(unit_data: Dictionary, level: int):
	var level_stats = {}
	if unit_data.has("levels") and unit_data["levels"].has(str(level)):
		level_stats = unit_data["levels"][str(level)]
	else:
		level_stats = unit_data

	damage = level_stats.get("damage", unit_data.get("damage", 0))
	max_hp = level_stats.get("hp", unit_data.get("hp", 0))

	range_val = unit_data.get("range", 0)
	atk_speed = unit_data.get("atkSpeed", 1.0)
	crit_rate = unit_data.get("crit_rate", 0.1)
	crit_dmg = unit_data.get("crit_dmg", 1.5)

	attack_cost_mana = unit_data.get("manaCost", 0.0)
	skill_mana_cost = unit_data.get("skillCost", 30.0)

	if level_stats.has("mechanics"):
		var mechs = level_stats["mechanics"]
		if mechs.has("crit_rate_bonus"):
			crit_rate += mechs["crit_rate_bonus"]

	if current_hp > max_hp: current_hp = max_hp
