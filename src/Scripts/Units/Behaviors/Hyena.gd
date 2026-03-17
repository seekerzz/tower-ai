extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var execute_threshold: float = 0.25
var extra_attacks: int = 1
var execute_damage_ratio: float = 0.2

func on_setup():
	_update_mechanics()

func on_stats_updated():
	_update_mechanics()

func _update_mechanics():
	var level_stats = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = level_stats.get("mechanics", {})

	execute_threshold = mechanics.get("execute_threshold", 0.25)
	extra_attacks = mechanics.get("extra_attacks", 1)
	execute_damage_ratio = mechanics.get("execute_damage_ratio", 0.2)

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return

	var hp = target.get("hp")
	var max_hp = target.get("max_hp")
	if max_hp == null or max_hp <= 0:
		return
	if hp == null:
		return

	if (float(hp) / float(max_hp)) > execute_threshold:
		return

	var bonus_damage = unit.damage * execute_damage_ratio
	for i in range(extra_attacks):
		target.take_damage(bonus_damage, unit, unit.unit_data.get("damageType", "physical"))

	unit.spawn_buff_effect("🩸")
