extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var damage_reduction: int = 15

func on_setup():
	damage_reduction = 15
	if unit.level >= 2:
		damage_reduction = 25
	if unit.level >= 3:
		damage_reduction = 35

func on_calculate_mitigation(context: DamageContext):
	var amount = context.final_damage
	var reduced = max(0, amount - damage_reduction)

	AILogger.action("[战斗][调试] 铁甲龟 减伤生效: %.1f -> %.1f (基础减伤: %d)" % [amount, reduced, damage_reduction])

	if unit.level >= 3 and reduced <= 0 and amount > 0:
		var heal_amount = GameManager.max_core_health * 0.005
		GameManager.heal_core(heal_amount)
		unit.spawn_buff_effect("💖")

	context.final_damage = reduced

# DEPRECATED
func on_damage_taken(amount: float, _source: Node) -> float:
	return max(0, amount - damage_reduction)
