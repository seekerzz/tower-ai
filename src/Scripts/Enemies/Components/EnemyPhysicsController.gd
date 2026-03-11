extends RefCounted
class_name EnemyPhysicsController

var enemy: CharacterBody2D

func _init(target_enemy: CharacterBody2D):
	enemy = target_enemy

func process_orientation(delta: float):
	if enemy.is_dying:
		return
	if enemy.enemy_data.get("shape") == "rect":
		enemy.rotation += enemy.angular_velocity * delta * enemy.rotation_sensitivity
		enemy.angular_velocity = lerp(enemy.angular_velocity, 0.0, enemy.rotational_damping * delta)
	else:
		update_facing_logic()

func update_facing_logic():
	if !GameManager.grid_manager:
		return
	var core_pos = GameManager.grid_manager.global_position
	var diff_x = enemy.global_position.x - core_pos.x
	if diff_x > enemy.FLIP_THRESHOLD:
		enemy.is_facing_left = true
	elif diff_x < -enemy.FLIP_THRESHOLD:
		enemy.is_facing_left = false

func handle_knockback(delta: float) -> bool:
	if enemy.knockback_velocity.length() <= 10.0:
		return false
	enemy.velocity = enemy.knockback_velocity
	enemy.knockback_velocity = enemy.knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	enemy.move_and_slide()
	handle_collisions(delta)
	return true

func update_state_from_stun():
	if enemy.stun_timer > 0:
		enemy.state = enemy.State.STUNNED
	elif enemy.state == enemy.State.STUNNED:
		enemy.state = enemy.State.MOVE

func process_stunned_movement(delta: float):
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, 500 * delta)
	enemy.move_and_slide()
	handle_collisions(delta)

func handle_collisions(delta: float):
	var count = enemy.get_slide_collision_count()
	for i in range(count):
		var collision = enemy.get_slide_collision(i)
		var collider = collision.get_collider()
		var momentum = enemy.knockback_velocity.length() * enemy.mass
		if enemy.knockback_velocity.length() > 50.0:
			if collider is StaticBody2D or (collider is TileMap) or (collider.get_class() == "StaticBody2D"):
				var impact = momentum
				enemy.knockback_velocity = Vector2.ZERO
				enemy.velocity = Vector2.ZERO
				var dmg = impact * enemy.WALL_SLAM_FACTOR
				if dmg > 1:
					enemy.take_damage(dmg, null, "physical", null, 0)
					GameManager.spawn_floating_text(enemy.global_position, "Slam!", Color.GRAY)
				if impact > enemy.HEAVY_IMPACT_THRESHOLD:
					var impact_dir = -collision.get_normal()
					var norm_strength = clamp(impact / 100.0, 0.0, 3.0)
					GameManager.trigger_impact(impact_dir, norm_strength)
				apply_physics_stagger(1.5)
			elif collider is CharacterBody2D and collider.is_in_group("enemies"):
				var target = collider
				if target.has_method("apply_physics_stagger"):
					var t_mass = target.mass if "mass" in target else 1.0
					var ratio = enemy.mass / t_mass
					if "knockback_velocity" in target:
						target.knockback_velocity = enemy.knockback_velocity * ratio * enemy.TRANSFER_RATE
					if enemy.mass > t_mass * 1.5:
						target.apply_physics_stagger(1.0)
					if t_mass > enemy.mass * 2:
						apply_physics_stagger(0.5)
						enemy.knockback_velocity = -enemy.knockback_velocity * 0.5
					else:
						enemy.knockback_velocity = enemy.knockback_velocity * 0.5

func apply_physics_stagger(duration: float):
	if enemy.behavior:
		enemy.behavior.cancel_attack()
	if enemy.visual_controller:
		enemy.visual_controller.kill_tween()
		enemy.visual_controller.wobble_scale = Vector2.ONE
	enemy.apply_stun(duration)
