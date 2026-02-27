extends "res://src/Scripts/Units/Behaviors/FlyingMeleeBehavior.gd"

var first_strike_bonus: bool = true
var _last_target: WeakRef = null

func _get_target() -> Node2D:
	# Prioritize Highest HP
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var max_hp = -1.0

	for enemy in enemies:
		if !is_instance_valid(enemy): continue
		var dist = unit.global_position.distance_to(enemy.global_position)
		if dist <= unit.range_val:
			if enemy.hp > max_hp:
				max_hp = enemy.hp
				best_target = enemy

	if best_target:
		# Reset first strike if target changed
		var prev = _last_target.get_ref() if _last_target else null
		if prev != best_target:
			first_strike_bonus = true
			_last_target = weakref(best_target)
	else:
		_last_target = null

	return best_target

func _calculate_damage(target: Node2D) -> float:
	var dmg = unit.calculate_damage_against(target)

	var hp_percent = 1.0
	if target.max_hp > 0:
		hp_percent = target.hp / target.max_hp

	# Lv2: +30% vs >50% HP
	if unit.level >= 2 and hp_percent > 0.5:
		dmg *= 1.3

	# Lv3: 200% on First Strike vs >80% HP
	if unit.level >= 3 and first_strike_bonus and hp_percent > 0.8:
		dmg *= 2.0
		first_strike_bonus = false
		GameManager.spawn_floating_text(target.global_position, "FIRST STRIKE!", Color.RED)

	# Lv1 Original Trait (preserved): 200% to Full HP (approx >99%)
	if unit.level == 1 and hp_percent >= 0.99:
		dmg *= 2.0
		GameManager.spawn_floating_text(target.global_position, "CRUSH!", Color.RED)

	return dmg
