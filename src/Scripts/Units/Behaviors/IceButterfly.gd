extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name IceButterfly

var freeze_threshold: int = 2  # 从3层降低到2层触发冰冻

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	super.on_projectile_hit(target, damage, projectile)

	if not target.has_meta("ice_stacks"):
		target.set_meta("ice_stacks", 0)

	var stacks = target.get_meta("ice_stacks") + 1
	target.set_meta("ice_stacks", stacks)

	GameManager.spawn_floating_text(target.global_position, "❄", Color.CYAN)

	if stacks >= freeze_threshold:
		_freeze_enemy(target)
		target.set_meta("ice_stacks", 0)

func _freeze_enemy(enemy: Node2D):
	# 冻结时间从1.0/1.5秒提升到1.5/2.0秒
	var duration = 1.5 if unit.level < 2 else 2.0
	if enemy.has_method("apply_freeze"):
		enemy.apply_freeze(duration)
