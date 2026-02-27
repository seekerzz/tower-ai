extends "res://src/Scripts/Projectiles/BaseProjectile.gd"

# Advanced Stats
var type: String = "pinecone"
var hit_list = []
var shared_hit_list_ref: Array = []
var effects: Dictionary = {} # Legacy stats holder

var is_meteor_falling: bool = false
var meteor_target: Vector2 = Vector2.ZERO

# Storage for all stats
var stats: Dictionary = {}

var pierce: int = 0
var bounce: int = 0
var split: int = 0
var chain: int = 0
var damage_type: String = "physical"
var is_critical: bool = false
var life: float = 2.0

# Visuals
var visual_node: Node2D = null # This will be our ProjectileVisuals instance
var is_fading: bool = false

# Dragon Breath State
enum State { MOVING, HOVERING, STUCK, RETURNING }
var state = State.MOVING
var dragon_breath_timer: float = 0.0

# Feather State
var feather_original_target_pos: Vector2 = Vector2.ZERO
var feather_stuck_pos: Vector2 = Vector2.ZERO

var target = null # Enemy node

const PROJECTILE_VISUALS_SCRIPT = preload("res://src/Scripts/Projectiles/ProjectileVisuals.gd")

func _ready():
	super._ready()

	# Instantiate Visuals Controller if not already created in setup
	if not visual_node:
		visual_node = PROJECTILE_VISUALS_SCRIPT.new()
		visual_node.name = "Visuals"
		add_child(visual_node)

	# Hide default legacy visuals
	if has_node("ColorRect"):
		get_node("ColorRect").hide()
	if has_node("Sprite2D"):
		get_node("Sprite2D").hide()
	if has_node("Polygon2D"):
		get_node("Polygon2D").hide()

func setup(start_pos, target_node, dmg, proj_speed, proj_type, incoming_stats = {}):
	position = start_pos
	target = target_node
	damage = dmg
	speed = proj_speed
	type = proj_type
	stats = incoming_stats

	# Ensure visual node exists because setup might be called before _ready
	if not visual_node:
		visual_node = PROJECTILE_VISUALS_SCRIPT.new()
		visual_node.name = "Visuals"
		add_child(visual_node)

	if stats.has("source"):
		source_unit = stats.source

	if stats.has("effects"):
		effects = stats.effects.duplicate()
		_parse_effects_to_payload()

	pierce = stats.get("pierce", 0)
	bounce = stats.get("bounce", 0)
	split = stats.get("split", 0)
	chain = stats.get("chain", 0)
	damage_type = stats.get("damageType", "physical")
	is_critical = stats.get("is_critical", false)

	if stats.has("life"):
		life = stats.get("life")

	if stats.has("shared_hit_list"):
		shared_hit_list_ref = stats.get("shared_hit_list")

	if stats.has("is_meteor"):
		is_meteor_falling = true
		meteor_target = stats["ground_pos"]
		if type == "fireball":
			type = "fireball" # Logic in Visuals handles fallback
		elif type != "pinecone":
			pass # Keep passed type (e.g. ink)
		else:
			type = "dragon_breath"

		speed = 1200.0
		rotation = (meteor_target - position).angle()

	# Initial rotation
	if not is_meteor_falling:
		if target and is_instance_valid(target):
			look_at(target.global_position)
		elif stats.has("target_pos"):
			look_at(stats.target_pos)

		if type == "feather":
			if target and is_instance_valid(target):
				feather_original_target_pos = target.global_position
			elif stats.has("target_pos"):
				feather_original_target_pos = stats.target_pos
			else:
				var r = stats.get("range", 1000.0)
				feather_original_target_pos = position + Vector2.RIGHT.rotated(rotation) * r

		if stats.get("angle") != null:
			rotation = stats.get("angle")

	# Logic for Black Hole
	if type == "black_hole_field":
		speed = 0.0
		if stats.has("duration"):
			life = stats["duration"]

	if is_critical:
		scale *= 1.2

	# Visual Setup
	if visual_node:
		visual_node.update_visuals(type, stats)
		if stats.get("hide_visuals", false):
			visual_node.hide()
			modulate.a = 0.0

func _parse_effects_to_payload():
	# Convert legacy effects dict to payload_effects
	if effects.get("burn", 0.0) > 0.0:
		payload_effects.append({
			"script": load("res://src/Scripts/Effects/BurnEffect.gd"),
			"params": {
				"duration": effects["burn"], # Duration from legacy
				"damage": damage, # Pass projectile damage as burn base damage? Or source damage? BurnEffect defaults to 10.
				"stacks": 1
			}
		})

	if effects.get("poison", 0.0) > 0.0:
		payload_effects.append({
			"script": load("res://src/Scripts/Effects/PoisonEffect.gd"),
			"params": {
				"duration": effects["poison"],
				"damage": damage, # Using projectile damage
				"stacks": effects.get("poison_stacks", 1)
			}
		})

	if effects.get("slow", 0.0) > 0.0:
		payload_effects.append({
			"script": load("res://src/Scripts/Effects/SlowEffect.gd"),
			"params": {
				"duration": effects["slow"], # Duration
				"slow_factor": 0.5 # Hardcoded for now as legacy didn't specify factor
			}
		})

	if effects.get("bleed", 0.0) > 0.0:
		payload_effects.append({
			"script": load("res://src/Scripts/Effects/BleedEffect.gd"),
			"params": {
				"duration": effects["bleed"],
				"stack_count": 1
			}
		})

	# Freeze is handled manually in handle_hit for now or could be here if we implemented FreezeEffect

func fade_out():
	if is_fading: return
	if state == State.STUCK: return

	is_fading = true

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)

	if type != "swarm_wave" and type != "roar":
		tween.tween_property(self, "scale", scale * 1.5, 0.2)

	tween.chain().tween_callback(queue_free)

func _process(delta):
	if is_fading: return

	# Specialized logic overrides super._process or manages movement itself

	if is_meteor_falling:
		if is_instance_valid(target):
			meteor_target = target.global_position
			rotation = (meteor_target - global_position).angle()

		var dist = global_position.distance_to(meteor_target)
		if dist < 20.0:
			_on_meteor_hit()
			return

		position += Vector2.RIGHT.rotated(rotation) * speed * delta
		return

	if type == "dragon_breath":
		_process_dragon_breath(delta)
		return

	if type == "feather":
		_process_feather(delta)
		if state != State.RETURNING:
			return

		if state == State.RETURNING and source_unit and is_instance_valid(source_unit):
			if global_position.distance_to(source_unit.global_position) < 15.0:
				queue_free()
				return

	if type == "black_hole_field":
		_process_black_hole(delta)

	life -= delta
	if life <= 0:
		fade_out()
		return

	if type == "roar":
		scale += Vector2(delta, delta) * speed * 0.01
		modulate.a = max(0, modulate.a - delta * 0.8)
		# Visual update handled in ProjectileVisuals?
		# No, existing code updated WaveLine width here.
		# visual_node is ProjectileVisuals. We might need to access children.
		# For now, roar visual animation is static or we can access it.
		pass

	# Standard Homing / Movement
	var direction = Vector2.RIGHT.rotated(rotation)

	if is_instance_valid(target):
		var target_dir = (target.global_position - global_position).normalized()
		direction = target_dir
		rotation = direction.angle()

	position += direction * speed * delta

	# Enemy Ranged Attack
	if !is_instance_valid(target) and stats.has("target_pos") and source_unit and source_unit.is_in_group("enemies"):
		if global_position.distance_to(stats.target_pos) < 15.0:
			GameManager.damage_core(damage)
			_spawn_hit_visual(global_position)
			queue_free()
			return

	if visual_node:
		visual_node.rotation += delta * 15.0

func _process_black_hole(delta):
	var pull_radius = stats.get("skillRadius", 150.0)
	var pull_strength = stats.get("skillStrength", 3000.0)
	var black_hole_center = global_position

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var dist = black_hole_center.distance_to(enemy.global_position)
		if dist < pull_radius:
			var dir = (black_hole_center - enemy.global_position).normalized()
			var mass = 1.0
			if "mass" in enemy: mass = enemy.mass
			elif "knockback_resistance" in enemy: mass = max(enemy.knockback_resistance, 1.0)
			mass = max(mass, 0.1)

			var force_magnitude = (pull_strength / max(dist, 10.0)) * (1.0 / mass)
			var force_vector = dir * force_magnitude * delta

			if enemy.has_method("apply_force"):
				enemy.apply_force(force_vector)
			else:
				enemy.global_position += force_vector

func _process_dragon_breath(delta):
	if state == State.MOVING:
		life -= delta
		if life <= 0:
			fade_out()
			return

		if is_instance_valid(target):
			var dist = global_position.distance_to(target.global_position)
			var dir = (target.global_position - global_position).normalized()
			position += dir * speed * delta

			if dist < 10.0:
				state = State.HOVERING
				dragon_breath_timer = 3.0
		else:
			state = State.HOVERING
			dragon_breath_timer = 2.0

	elif state == State.HOVERING:
		dragon_breath_timer -= delta
		if dragon_breath_timer <= 0:
			fade_out()
			return

		var pull_radius = 150.0
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < pull_radius:
				var pull_dir = (global_position - enemy.global_position).normalized()
				enemy.global_position += pull_dir * 100.0 * delta
				enemy.take_damage(damage * delta, source_unit, damage_type)

func _handle_hit(target_node):
	if is_fading: return
	if type == "dragon_breath": return
	if type == "black_hole_field": return
	if type == "feather" and state == State.STUCK: return

	if target_node.is_in_group("enemies"):
		if source_unit and source_unit.is_in_group("enemies"):
			return

		if shared_hit_list_ref != null and target_node in shared_hit_list_ref: return
		if target_node in hit_list: return

		if type == "feather" and state == State.RETURNING:
			var pull_str = 0.0
			if source_unit and "unit_data" in source_unit and source_unit.unit_data.has("levels"):
				var lvl_stats = source_unit.unit_data["levels"][str(source_unit.level)]
				if lvl_stats.has("mechanics"):
					pull_str = lvl_stats["mechanics"].get("pull_strength", 0.0)

			if pull_str > 0:
				var dir = (source_unit.global_position - target_node.global_position).normalized()
				target_node.global_position += dir * (pull_str * 0.05)

		var final_damage_type = damage_type
		if is_critical:
			final_damage_type = "crit"
			# Emit crit signal for test logging
			if GameManager.has_signal("crit_occurred"):
				GameManager.crit_occurred.emit(source_unit, target_node, damage, false)
			if GameManager.current_mechanic and GameManager.current_mechanic.has_method("on_projectile_crit"):
				GameManager.current_mechanic.on_projectile_crit(self, target_node)
			# Emit global crit signal for units like Storm Eagle
			if GameManager.has_signal("projectile_crit"):
				GameManager.projectile_crit.emit(source_unit, target_node, damage)

		var kb_force = damage * speed * 0.005
		if type == "roar": kb_force *= 2.0
		if type == "snowball": kb_force *= 1.5

		if target_node.has_method("take_damage"):
			target_node.take_damage(damage, source_unit, final_damage_type, self, kb_force)

		# Apply Status Effects via Payload (New System)
		apply_payload(target_node)

		# Freeze (Legacy support since we didn't refactor FreezeEffect fully yet or projectile passes it differently)
		if effects.get("freeze", 0.0) > 0.0:
			if target_node.has_method("apply_freeze"):
				target_node.apply_freeze(effects["freeze"])
			else:
				target_node.set("freeze_timer", max(target_node.get("freeze_timer") if target_node.get("freeze_timer") else 0.0, effects["freeze"]))

		if source_unit and is_instance_valid(source_unit) and "behavior" in source_unit and source_unit.behavior:
			if source_unit.behavior.has_method("on_projectile_hit"):
				source_unit.behavior.on_projectile_hit(target_node, damage, self)

		hit_list.append(target_node)
		if shared_hit_list_ref != null:
			shared_hit_list_ref.append(target_node)

		var total_bounce = bounce + chain
		var bounced = false

		if bounce > 0:
			bounced = perform_physical_bounce(target_node)
		elif chain > 0:
			bounced = perform_bounce(target_node)

		if not bounced:
			if type == "roar":
				pass
			elif pierce > 0:
				pierce -= 1
			else:
				if split > 0 and type != "roar":
					perform_split()

				_spawn_hit_visual(target_node.global_position)
				if type != "feather":
					queue_free()

func _process_feather(delta):
	if (state == State.STUCK or state == State.RETURNING or state == State.MOVING) and (!source_unit or !is_instance_valid(source_unit)):
		queue_free()
		return

	if state == State.MOVING:
		var direction = Vector2.RIGHT.rotated(rotation)
		position += direction * speed * delta

		if source_unit and is_instance_valid(source_unit):
			var start_pos = source_unit.global_position
			var to_target = feather_original_target_pos - start_pos
			var to_current = global_position - start_pos
			var projected_dist = to_current.dot(to_target.normalized())
			var target_dist = to_target.length()

			if projected_dist >= target_dist + 40.0:
				_become_stuck()
		else:
			if global_position.distance_to(feather_original_target_pos) < 10.0:
				_become_stuck()

func _become_stuck():
	feather_stuck_pos = position
	state = State.STUCK
	set_deferred("monitoring", false)

	if visual_node:
		var tween = create_tween()
		var base_rot = rotation
		tween.tween_property(visual_node, "rotation", base_rot + 0.2, 0.05)
		tween.tween_property(visual_node, "rotation", base_rot - 0.2, 0.05)
		tween.tween_property(visual_node, "rotation", base_rot, 0.05)

	var dust = Polygon2D.new()
	dust.polygon = PackedVector2Array([Vector2(-2,-2), Vector2(2,-2), Vector2(2,2), Vector2(-2,2)])
	dust.color = Color(0.6, 0.6, 0.6, 0.5)
	dust.position = Vector2.ZERO
	add_child(dust)
	var t = create_tween()
	t.tween_property(dust, "scale", Vector2(2,2), 0.3)
	t.parallel().tween_property(dust, "modulate:a", 0.0, 0.3)
	t.tween_callback(dust.queue_free)

func recall():
	if state != State.STUCK and state != State.MOVING: return

	state = State.RETURNING
	target = source_unit
	pierce = 999
	hit_list.clear()
	shared_hit_list_ref = []

	monitoring = true

	var bodies = get_overlapping_bodies()
	for body in bodies:
		_handle_hit(body)

	var areas = get_overlapping_areas()
	for area in areas:
		_handle_hit(area)

	if visual_node:
		visual_node.modulate = Color.RED

func _spawn_hit_visual(pos: Vector2):
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	get_parent().add_child(effect)
	effect.global_position = pos
	effect.rotation = randf() * TAU

	var shape = "circle"
	var col = Color.WHITE

	if type == "pinecone":
		shape = "circle"
		col = Color("8B4513")
	elif type == "ink":
		shape = "blob"
		col = Color.BLACK
	elif type == "stinger":
		shape = "triangle"
		col = Color.YELLOW
	elif type == "pollen":
		shape = "star"
		col = Color.PINK
	else:
		shape = "slash"
		col = Color.WHITE

	effect.configure(shape, col)
	effect.play()

func _on_meteor_hit():
	is_meteor_falling = false
	var bounce_angle = rotation + randf_range(-0.5, 0.5)
	rotation = bounce_angle

	life = 0.3
	speed = 50.0
	target = null

	var SlashEffectScript = load("res://src/Scripts/Effects/SlashEffect.gd")
	if SlashEffectScript:
		var slash = SlashEffectScript.new()
		get_parent().add_child(slash)
		slash.global_position = global_position
		slash.rotation = rotation
		slash.modulate = Color.ORANGE
		slash.play()

	type = "meteor_debris"
	# Update visual if needed
	if visual_node:
		# Meteor debris visual? just reuse current or something
		pass

func perform_split():
	var angles = [rotation + 0.5, rotation - 0.5]
	var proj_scene = load("res://src/Scenes/Game/Projectile.tscn")

	for angle in angles:
		var proj = proj_scene.instantiate()
		var new_stats = {
			"pierce": 0,
			"bounce": 0,
			"split": 0,
			"chain": 0,
			"angle": angle,
			"source": source_unit,
			"damageType": damage_type
		}
		proj.setup(global_position, null, damage * 0.5, speed, type, new_stats)
		get_parent().call_deferred("add_child", proj)

func perform_bounce(current_hit_enemy):
	var search_range = 300.0
	var nearest = null
	var min_dist = search_range

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == current_hit_enemy or enemy in hit_list:
			continue

		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy

	if nearest:
		target = nearest
		damage *= 0.8
		if chain > 0: chain -= 1
		life = 1.0
		return true

	return false

func perform_physical_bounce(hit_node):
	var incident = Vector2.RIGHT.rotated(rotation)
	var normal = Vector2.ZERO

	if "enemy_data" in hit_node:
		var e_data = hit_node.enemy_data
		if e_data.get("shape") == "rect" or hit_node.type_key == "crab":
			var local_hit = hit_node.to_local(global_position)
			var size_grid = e_data.get("size_grid", [1,1])
			var w = size_grid[0] * 60
			var h = size_grid[1] * 60

			if h > 0:
				var aspect = w / h
				if abs(local_hit.x) > abs(local_hit.y) * aspect:
					normal = Vector2(sign(local_hit.x), 0).rotated(hit_node.rotation)
				else:
					normal = Vector2(0, sign(local_hit.y)).rotated(hit_node.rotation)
		else:
			if hit_node.velocity.length() > 0.1:
				normal = hit_node.velocity.normalized()
			else:
				normal = (global_position - hit_node.global_position).normalized()
	else:
		normal = (global_position - hit_node.global_position).normalized()

	var dot = incident.dot(normal)
	var reflect = incident - 2 * dot * normal

	rotation = reflect.angle()
	target = null

	damage *= 0.8
	bounce -= 1
	life = 1.0

	return true

func trigger_eagle_echo(target_node, multiplier: float):
	if not is_instance_valid(target_node): return

	var echo_damage = damage * multiplier
	var kb_force = damage * speed * 0.005 # Keep consistent with original

	if target_node.has_method("take_damage"):
		# Important: damage_type "eagle_crit" prevents infinite recursion
		target_node.take_damage(echo_damage, source_unit, "eagle_crit", self, kb_force)

	# Apply effects again (poison, burn, etc)
	apply_payload(target_node)
