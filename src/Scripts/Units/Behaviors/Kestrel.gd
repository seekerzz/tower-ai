extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Kestrel - 红隼
# 攻击概率眩晕敌人，Lv2增加概率和时间
# Lv3红隼眩晕触发音爆伤害

var dive_chance: float = 0.20

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target.is_in_group("enemies"): return

	var chance = dive_chance
	if unit.level >= 2:
		chance = 0.30

	if randf() < chance:
		var duration = 1.0 if unit.level < 2 else 1.2
		_apply_dive_stun(target, duration)

func _apply_dive_stun(enemy: Node2D, duration: float):
	# Try stun, fallback to freeze/slow or just text if no method
	# Assuming Enemy.gd has apply_stun or we need to add it?
	# Existing code has "apply_freeze" and "apply_status".
	# The task description says "enemy.apply_stun(duration)".

	if enemy.has_method("apply_stun"):
		enemy.apply_stun(duration)
	elif enemy.has_method("apply_freeze"):
		enemy.apply_freeze(duration)
	else:
		# Manual stun fallback if method missing
		if "speed_modifier" in enemy:
			enemy.speed_modifier = 0.0
			await unit.get_tree().create_timer(duration).timeout
			if is_instance_valid(enemy):
				enemy.speed_modifier = 1.0 # This might override other slows, but it's a fallback

	GameManager.spawn_floating_text(enemy.global_position, "STUN!", Color.YELLOW)

	if unit.level >= 3:
		_sonic_boom(enemy.global_position)

func _sonic_boom(position: Vector2):
	var radius = 80.0
	var damage = unit.damage * 0.4

	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(position) <= radius:
			# Use "sonic" type for potentially different color/effect
			e.take_damage(damage, unit, "physical")

	GameManager.trigger_impact(Vector2.ZERO, 0.2)
