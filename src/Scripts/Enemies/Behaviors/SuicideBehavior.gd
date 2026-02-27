extends "res://src/Scripts/Enemies/Behaviors/DefaultBehavior.gd"

func physics_process(delta: float) -> bool:
	if !GameManager.is_wave_active: return false

	check_suicide_collision()
	return super.physics_process(delta)

func check_suicide_collision():
	if GameManager.grid_manager:
		var core_dist = enemy.global_position.distance_to(GameManager.grid_manager.global_position)
		if core_dist < 40.0:
			explode_suicide()

func explode_suicide():
	GameManager.damage_core(data.dmg)
	GameManager.spawn_floating_text(enemy.global_position, "BOOM!", Color.RED)
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	enemy.get_parent().add_child(effect)
	effect.global_position = enemy.global_position
	effect.configure("cross", Color.ORANGE)
	effect.scale = Vector2(2, 2)
	effect.play()
	enemy.queue_free()
