extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if randf() < 0.25:
		if GameManager.grid_manager:
			GameManager.grid_manager.try_spawn_trap(target.global_position, "mucus")
