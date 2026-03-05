extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name Firefly

func on_stats_updated():
	unit.damage = 0.0

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	super.on_projectile_hit(target, damage, projectile)

	var blind_duration = 2.5
	if unit.level >= 2:
		blind_duration += 2.0

	if target.has_method("apply_blind"):
		target.apply_blind(blind_duration)

	if unit.level >= 3:
		if target.has_signal("attack_missed"):
			if not target.is_connected("attack_missed", _on_enemy_miss):
				target.attack_missed.connect(_on_enemy_miss)

func _on_enemy_miss(enemy):
	if unit.level >= 3:
		GameManager.add_resource("mana", 8)
		GameManager.spawn_floating_text(unit.global_position, "+8 Mana", Color.BLUE)
