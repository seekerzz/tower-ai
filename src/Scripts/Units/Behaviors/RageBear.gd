extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# RageBear - 暴怒熊
# Stun-based melee unit with bonus damage to stunned enemies
# Active skill: ground slam AoE stun
# Lv3: Killing stunned enemies resets skill cooldown (10s internal CD)

var stun_chance: float = 0.15
var stun_duration: float = 1.0
var bonus_vs_stunned: float = 0.5
var skill_stun_duration: float = 1.5
var skill_radius: float = 150.0
var skill_mana_cost: int = 300

# Lv3 cooldown reset tracking
var kill_reset_internal_cd: float = 0.0
var kill_reset_internal_cd_max: float = 10.0

func on_setup():
	# Set level-based stats
	match unit.level:
		1:
			stun_chance = 0.15
			stun_duration = 1.0
			bonus_vs_stunned = 0.5
			skill_stun_duration = 1.5
		2:
			stun_chance = 0.22
			stun_duration = 1.2
			bonus_vs_stunned = 0.75
			skill_stun_duration = 2.0
		3:
			stun_chance = 0.30
			stun_duration = 1.5
			bonus_vs_stunned = 1.0
			skill_stun_duration = 2.5

func on_tick(delta: float):
	# Lv3: Manage internal cooldown for kill reset
	if unit.level >= 3 and kill_reset_internal_cd > 0:
		kill_reset_internal_cd -= delta

func on_attack(target: Node2D) -> float:
	if not is_instance_valid(target):
		return 0.0

	var total_damage = unit.damage

	# Check if target is stunned and apply bonus damage
	if target.is_in_group("enemies") and target.get("stun_timer") and target.stun_timer > 0:
		total_damage *= (1.0 + bonus_vs_stunned)
		unit.spawn_buff_effect("💢")

	# Chance to stun on attack
	if target.is_in_group("enemies") and randf() < stun_chance:
		if target.has_method("apply_stun"):
			target.apply_stun(stun_duration)
			GameManager.spawn_floating_text(target.global_position, "STUN!", Color.YELLOW)

	return total_damage

func on_skill_activated():
	# Ground slam - stun all enemies in range
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var stunned_count = 0

	for enemy in enemies:
		if is_instance_valid(enemy) and unit.global_position.distance_to(enemy.global_position) <= skill_radius:
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(skill_stun_duration)
				stunned_count += 1

	# Visual feedback
	if stunned_count > 0:
		GameManager.spawn_floating_text(unit.global_position, "SLAM! (%d)" % stunned_count, Color.ORANGE)
		unit.spawn_buff_effect("💥")

	# Create shockwave visual effect
	_create_shockwave_effect()

func _create_shockwave_effect():
	# Spawn expanding circle effect
	var shockwave = ColorRect.new()
	shockwave.color = Color(0.8, 0.4, 0.0, 0.5)
	shockwave.size = Vector2(20, 20)
	shockwave.position = unit.global_position - Vector2(10, 10)
	unit.get_tree().root.add_child(shockwave)

	# Animate expansion
	var tween = unit.create_tween()
	tween.tween_property(shockwave, "size", Vector2(skill_radius * 2, skill_radius * 2), 0.3)
	tween.parallel().tween_property(shockwave, "position", unit.global_position - Vector2(skill_radius, skill_radius), 0.3)
	tween.parallel().tween_property(shockwave, "color:a", 0.0, 0.3)
	tween.tween_callback(shockwave.queue_free)

func on_kill(victim: Node2D):
	# Lv3: Killing a stunned enemy resets skill cooldown
	if unit.level >= 3 and kill_reset_internal_cd <= 0:
		if victim.is_in_group("enemies") and victim.get("stun_timer") and victim.stun_timer > 0:
			# Reset skill cooldown
			if unit.has_method("reset_skill_cooldown"):
				unit.reset_skill_cooldown()
				kill_reset_internal_cd = kill_reset_internal_cd_max
				GameManager.spawn_floating_text(unit.global_position, "CD RESET!", Color.CYAN)
