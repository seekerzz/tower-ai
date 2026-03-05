extends RefCounted
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
