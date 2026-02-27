extends "res://src/Scripts/Enemies/Behaviors/DefaultBehavior.gd"

var stationary_timer: float = 0.0
var boss_skill: String = ""
var skill_cd_timer: float = 0.0
var is_stationary: bool = false
var is_dying_anim: bool = false

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	super.init(enemy_node, enemy_data)
	stationary_timer = data.get("stationary_time", 0.0)
	boss_skill = data.get("boss_skill", "")

	if stationary_timer > 0.0:
		is_stationary = true

	# Boss Stats overrides
	enemy.knockback_resistance = 10.0
	enemy.mass = 5.0
	# Collision shape is likely set by Enemy.gd based on data, but if we need specific boss shape:
	# Enemy.gd handles it via enemy_data.radius usually.

func physics_process(delta: float) -> bool:
	if is_dying_anim: return true

	if is_stationary:
		stationary_timer -= delta
		skill_cd_timer -= delta
		if stationary_timer <= 0:
			is_stationary = false
		else:
			if boss_skill != "" and skill_cd_timer <= 0:
				perform_boss_skill(boss_skill)
				skill_cd_timer = 2.0
			return true # Handled (don't move)

	return super.physics_process(delta)

func perform_boss_skill(skill_name: String):
	if skill_name == "summon":
		GameManager.spawn_floating_text(enemy.global_position, "Summon!", Color.PURPLE)
		for i in range(3):
			var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			if GameManager.combat_manager:
				GameManager.combat_manager._spawn_enemy_at_pos(enemy.global_position + offset, "minion")
	elif skill_name == "shoot_enemy":
		GameManager.spawn_floating_text(enemy.global_position, "Fire!", Color.ORANGE)
		if GameManager.combat_manager:
			GameManager.combat_manager._spawn_enemy_at_pos(enemy.global_position, "bullet_entity")

func on_death(killer_unit) -> bool:
	if enemy.visual_controller:
		# Disable collision
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		enemy.is_dying = true # Set flag on enemy so physics stops
		is_dying_anim = true

		var death_tween = enemy.visual_controller.play_death_implosion()

		var tween = enemy.create_tween()
		tween.tween_property(enemy, "modulate", Color.GRAY, 0.5)

		death_tween.finished.connect(func():
			enemy.queue_free()
		)
		return true # We handle the death (delayed)
	return false
