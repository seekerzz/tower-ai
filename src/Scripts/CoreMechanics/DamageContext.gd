class_name DamageContext
extends RefCounted

var source: Node         # The attacker (Unit or Enemy)
var target: Node         # The defender (Unit)
var base_damage: float   # Initial damage amount
var final_damage: float  # Damage after all mitigations
var damage_type: String  # physical, magic, etc.

var is_miss: bool = false
var is_dodge: bool = false
var shield_absorbed: float = 0.0

func _init(p_source: Node, p_target: Node, p_base_damage: float, p_damage_type: String = "physical"):
	source = p_source
	target = p_target
	base_damage = p_base_damage
	final_damage = p_base_damage
	damage_type = p_damage_type
