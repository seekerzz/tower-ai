extends "res://src/Scripts/Enemies/Behaviors/EnemyBehavior.gd"

var path: PackedVector2Array = []
var nav_timer: float = 0.0
var path_index: int = 0
var current_target_tile: Node2D = null
var current_taunt_target: Node2D = null
var base_attack_timer: float = 0.0
var anim_tween: Tween

# Constants used in logic
const WALL_SLAM_FACTOR = 0.5
const HEAVY_IMPACT_THRESHOLD = 50.0

func physics_process(delta: float) -> bool:
	if !GameManager.is_wave_active: return false

	# Update taunt target
	if enemy.get("faction") == "player":
		current_taunt_target = _find_nearest_hostile()
	elif enemy.has_method("find_attack_target"):
		current_taunt_target = enemy.find_attack_target()
	else:
		current_taunt_target = null

	# State Machine Logic
	match enemy.state:
		enemy.State.MOVE:
			nav_timer -= delta
			if nav_timer <= 0:
				update_path()
				nav_timer = 0.5

			var desired_velocity = calculate_move_velocity()

			if _should_attack(current_taunt_target):
				enemy.state = enemy.State.ATTACK_BASE
				enemy.velocity = Vector2.ZERO
			else:
				enemy.velocity = desired_velocity
				enemy.move_and_slide()
				if enemy.has_method("handle_collisions"):
					enemy.handle_collisions(delta)

		enemy.State.ATTACK_BASE:
			if _should_stop_attacking(current_taunt_target):
				enemy.state = enemy.State.MOVE
			else:
				attack_logic(delta, current_taunt_target)
				enemy.velocity = Vector2.ZERO

	return true # We handled the movement logic

func calculate_move_velocity() -> Vector2:
	if not GameManager.grid_manager:
		return Vector2.ZERO
	var target_pos = GameManager.grid_manager.global_position

	if enemy.get("faction") == "player":
		if current_taunt_target and is_instance_valid(current_taunt_target):
			target_pos = current_taunt_target.global_position
		else:
			# Stay put if no target
			return Vector2.ZERO
	elif current_taunt_target and is_instance_valid(current_taunt_target):
		target_pos = current_taunt_target.global_position
	elif current_target_tile and is_instance_valid(current_target_tile):
		target_pos = current_target_tile.global_position

	if path.size() > path_index:
		target_pos = path[path_index]

	var dist = enemy.global_position.distance_to(target_pos)
	if dist < 10:
		if path.size() > path_index:
			path_index += 1
			if path_index < path.size():
				target_pos = path[path_index]

	var direction = (target_pos - enemy.global_position).normalized()

	enemy.temp_speed_mod = 1.0
	# Slow logic is handled by SlowEffect modifying enemy.speed directly

	return direction * enemy.speed * enemy.temp_speed_mod

func update_path():
	if !GameManager.grid_manager: return
	var target_pos = Vector2.ZERO
	current_target_tile = null

	if current_taunt_target and is_instance_valid(current_taunt_target):
		target_pos = current_taunt_target.global_position
	else:
		if GameManager.grid_manager.has_method("get_closest_unlocked_tile"):
			current_target_tile = GameManager.grid_manager.get_closest_unlocked_tile(enemy.global_position)
			if current_target_tile:
				target_pos = current_target_tile.global_position
			else:
				target_pos = GameManager.grid_manager.global_position
		else:
			target_pos = GameManager.grid_manager.global_position

	path = GameManager.grid_manager.get_nav_path(enemy.global_position, target_pos)
	if path.size() == 0:
		path = []
	else:
		path_index = 0
		if path.size() > 0 and enemy.global_position.distance_to(path[0]) < 10:
			path_index = 1

func _should_attack(target: Node2D) -> bool:
	if enemy.get("faction") == "player" and (!target or !is_instance_valid(target)):
		return false
	if not GameManager.grid_manager:
		return false

	var target_pos = GameManager.grid_manager.global_position

	if target and is_instance_valid(target):
		target_pos = target.global_position
	elif current_target_tile and is_instance_valid(current_target_tile):
		# Only use tile position if we don't have a direct target
		if !target:
			target_pos = current_target_tile.global_position

	var dist = enemy.global_position.distance_to(target_pos)
	var attack_range = data.radius + 10.0

	if data.get("attackType") == "ranged":
		var range_val = data.get("range", 200.0)
		if dist < range_val:
			return true
	else:
		if dist < attack_range:
			return true
	return false

func _should_stop_attacking(target: Node2D) -> bool:
	if not GameManager.grid_manager:
		return false
	var target_pos = GameManager.grid_manager.global_position

	if target and is_instance_valid(target):
		target_pos = target.global_position
	elif current_target_tile and is_instance_valid(current_target_tile):
		if !target:
			target_pos = current_target_tile.global_position

	var dist = enemy.global_position.distance_to(target_pos)
	var attack_range = data.radius + 10.0

	if data.get("attackType") == "ranged":
		var range_val = data.get("range", 200.0)
		return dist > range_val * 1.1
	else:
		return dist > attack_range * 1.5

func attack_logic(delta, target: Node2D):
	if not GameManager.grid_manager:
		return
	var target_pos = GameManager.grid_manager.global_position
	var is_targeting_unit = (target != null)

	if target and is_instance_valid(target):
		target_pos = target.global_position
	elif current_target_tile and is_instance_valid(current_target_tile):
		target_pos = current_target_tile.global_position

	base_attack_timer -= delta
	if base_attack_timer <= 0:
		base_attack_timer = 1.0 / data.atkSpeed

		if enemy.blind_timer > 0:
			enemy.attack_missed.emit(enemy)
			GameManager.spawn_floating_text(enemy.global_position, "MISS", Color.GRAY)
			return

		if data.get("attackType") == "ranged":
			play_attack_animation(target_pos, func():
				if GameManager.combat_manager:
					var proj_type = data.get("proj", "pinecone")
					var core_pos = target_pos # Attack the target pos

					# var stats = { "damageType": "physical", "source": enemy }
					GameManager.combat_manager.spawn_projectile(enemy, enemy.global_position, null, {
						"target_pos": core_pos,
						"type": proj_type,
						"damage": data.dmg,
						"speed": data.get("projectileSpeed", 300.0),
						"damageType": "physical"
					})
			)
		else:
			play_attack_animation(target_pos, func():
				if is_targeting_unit:
					if target and is_instance_valid(target):
						if target.has_method("take_damage"):
							target.take_damage(data.dmg, enemy)
					# If target became invalid during animation, attack misses (do not hit core)
				else:
					# Default core attack
					GameManager.damage_core(data.dmg)
					if current_target_tile and not is_instance_valid(current_target_tile):
						enemy.state = enemy.State.MOVE
						current_target_tile = null
						update_path()
			)

func cancel_attack():
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
	if enemy.visual_controller:
		enemy.visual_controller.kill_tween()
		enemy.visual_controller.wobble_scale = Vector2.ONE

func _find_nearest_hostile() -> Node2D:
	var nearest = null
	var min_dist = 9999.0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == enemy: continue
		if other.get("faction") == "player": continue # Don't attack other charmed enemies

		var dist = enemy.global_position.distance_to(other.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = other
	return nearest

func play_attack_animation(target_pos: Vector2, hit_callback: Callable = Callable()):
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()

	anim_tween = enemy.create_tween()
	var original_pos = enemy.global_position
	var diff = target_pos - original_pos
	var direction = diff.normalized()

	var anim_type = "melee"
	if data.get("attackType") == "ranged":
		anim_type = data.get("rangedAnimType", "recoil")

	var vc = enemy.visual_controller

	if anim_type == "melee":
		# Phase 1: Windup
		anim_tween.set_parallel(true)
		anim_tween.tween_property(enemy, "global_position", original_pos - direction * Constants.ANIM_WINDUP_DIST, Constants.ANIM_WINDUP_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if vc:
			anim_tween.tween_property(vc, "wobble_scale", Constants.ANIM_WINDUP_SCALE, Constants.ANIM_WINDUP_TIME)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		anim_tween.set_parallel(false)

		# Phase 2: Strike
		anim_tween.set_parallel(true)
		anim_tween.tween_property(enemy, "global_position", original_pos + direction * Constants.ANIM_STRIKE_DIST, Constants.ANIM_STRIKE_TIME)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		if vc:
			anim_tween.tween_property(vc, "wobble_scale", Constants.ANIM_STRIKE_SCALE, Constants.ANIM_STRIKE_TIME)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		anim_tween.set_parallel(false)

		# Callback on impact
		anim_tween.tween_callback(func():
			spawn_slash_effect(target_pos)
			if hit_callback.is_valid():
				hit_callback.call()
		)

		# Phase 3: Recovery
		anim_tween.set_parallel(true)
		anim_tween.tween_property(enemy, "global_position", original_pos, Constants.ANIM_RECOVERY_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if vc:
			anim_tween.tween_property(vc, "wobble_scale", Vector2.ONE, Constants.ANIM_RECOVERY_TIME)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		anim_tween.set_parallel(false)

	elif anim_type == "recoil":
		anim_tween.tween_callback(func():
			if hit_callback.is_valid():
				hit_callback.call()
		)
		if vc:
			anim_tween.tween_property(vc, "wobble_scale", Vector2(0.8, 0.8), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			anim_tween.tween_property(vc, "wobble_scale", Vector2.ONE, 0.2)
		anim_tween.parallel().tween_property(enemy, "global_position", original_pos, 0.1)

	elif anim_type == "lunge":
		anim_tween.tween_property(enemy, "global_position", original_pos + direction * 10.0, 0.15)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		anim_tween.tween_callback(func():
			if hit_callback.is_valid():
				hit_callback.call()
		)
		anim_tween.tween_property(enemy, "global_position", original_pos, 0.2)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	elif anim_type == "elastic_shoot":
		if vc:
			var tween = vc.play_elastic_shoot()
			tween.tween_callback(func():
				if hit_callback.is_valid():
					hit_callback.call()
			).set_delay(0.4)
		else:
			if hit_callback.is_valid():
				hit_callback.call()

	elif anim_type == "elastic_slash":
		if vc:
			var tween = vc.play_elastic_slash()
			tween.tween_callback(func():
				spawn_slash_effect(target_pos)
				if hit_callback.is_valid():
					hit_callback.call()
			).set_delay(0.4)
		else:
			if hit_callback.is_valid():
				hit_callback.call()

func spawn_slash_effect(pos: Vector2):
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	enemy.get_parent().add_child(effect)
	effect.global_position = pos
	effect.rotation = randf() * TAU
	var shape = "slash"
	var col = Color.WHITE
	var type_key = enemy.type_key
	if type_key in ["wolf", "boss"]:
		shape = "bite"
		col = Color.RED
	elif type_key in ["slime", "poison"]:
		shape = "bite"
		col = Color.WHITE
	else:
		shape = "cross"
		col = Color.WHITE
	if randf() > 0.5: col = Color(1.0, 0.8, 0.8)
	effect.configure(shape, col)
	effect.play()
