class_name Enemy
extends CharacterBody2D

const EnemyBehavior = preload("res://src/Scripts/Enemies/Behaviors/EnemyBehavior.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

signal died
signal attack_missed(enemy)

enum State { MOVE, ATTACK_BASE, STUNNED, SUPPORT }
var state: State = State.MOVE

var faction: String = "enemy"
var type_key: String
var hp: float
var max_hp: float
var speed: float
var enemy_data: Dictionary

# Status Effects
# Refactored to use child nodes
# Preserving freeze/stun as timers for now (or could be effects too, but keeping scope focused)
var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var blind_timer: float = 0.0
var _env_cooldowns = {} # Trap Instance ID -> Cooldown Timer

var hit_flash_timer: float = 0.0

var temp_speed_mod: float = 1.0

var visual_controller: Node2D = null

var anim_config: Dictionary = {}
var base_speed: float = 40.0 # Default fallback

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_resistance: float = 1.0

# Physics Constants
const WALL_SLAM_FACTOR = 0.5
const HEAVY_IMPACT_THRESHOLD = 50.0
const TRANSFER_RATE = 0.8
const FLIP_THRESHOLD = 15.0

# Mass
var mass: float = 1.0
var is_facing_left: bool = false
var is_dying: bool = false

# Rotation Physics (Crab)
var angular_velocity: float = 0.0
var rotational_damping: float = 5.0
var rotation_sensitivity = 5.0

var invincible_timer: float = 0.0
var last_hit_direction: Vector2 = Vector2.ZERO

var behavior: EnemyBehavior

# Bleed System
var bleed_stacks: int = 0
var max_bleed_stacks: int = 30
var bleed_damage_per_stack: float = 3.0
var _bleed_source_unit: Object = null
var _bleed_display_timer: float = 0.0
const BLEED_DISPLAY_INTERVAL: float = 0.3

signal bleed_stack_changed(new_stacks: int)

func _ready():
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 2

	input_pickable = false
	GameManager._set_ignore_mouse_recursive(self)

	_ensure_visual_controller()
	GameManager.enemy_spawned.emit(self)

func setup(key: String, wave: int):
	_ensure_visual_controller()

	type_key = key
	enemy_data = Constants.ENEMY_VARIANTS[key]
	anim_config = enemy_data.get("anim_config", {})

	var base_hp = 100 + (wave * 80)
	hp = base_hp * enemy_data.hpMod
	max_hp = hp

	speed = (40 + (wave * 2)) * enemy_data.spdMod
	base_speed = speed

	# Collision Shape Logic
	var col_shape = get_node_or_null("CollisionShape2D")
	if !col_shape:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		add_child(col_shape)

	# Stats Setup
	mass = 1.0
	knockback_resistance = 1.0

	if enemy_data.get("is_boss", false) or type_key == "tank":
		knockback_resistance = 10.0
		mass = 5.0

	if enemy_data.get("shape") == "rect":
		# Crab Setup
		knockback_resistance = 8.0
		mass = 5.0

		# Setup Rectangle Collision
		var size_grid = enemy_data.get("size_grid", [1, 1])
		var tile_size = 60 # Default
		if GameManager.grid_manager:
			tile_size = GameManager.grid_manager.TILE_SIZE

		var rect_size = Vector2(size_grid[0] * tile_size, size_grid[1] * tile_size)

		var rect_shape = RectangleShape2D.new()
		rect_shape.size = rect_size * 0.8 # Slightly smaller than grid to avoid sticking
		col_shape.shape = rect_shape

	else:
		# Default Circle Collision
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = enemy_data.radius
		col_shape.shape = circle_shape

	var mass_mod = GameManager.get_stat_modifier("enemy_mass")
	mass *= mass_mod
	knockback_resistance *= mass_mod

	visual_controller.setup(anim_config, base_speed, speed)
	update_visuals()

	_init_behavior()

func _init_behavior():
	if type_key == "mutant_slime":
		behavior = load("res://src/Scripts/Enemies/Behaviors/MutantSlimeBehavior.gd").new()
	elif enemy_data.get("is_boss", false) or type_key == "boss":
		behavior = load("res://src/Scripts/Enemies/Behaviors/BossBehavior.gd").new()
	elif enemy_data.get("is_suicide", false):
		behavior = load("res://src/Scripts/Enemies/Behaviors/SuicideBehavior.gd").new()
	else:
		behavior = load("res://src/Scripts/Enemies/Behaviors/DefaultBehavior.gd").new()

	add_child(behavior)
	behavior.init(self, enemy_data)

func apply_charm(source_unit, duration: float = 3.0):
	if behavior:
		if behavior.has_method("cancel_attack"):
			behavior.cancel_attack()
		behavior.queue_free()

	var charmed_behavior = load("res://src/Scripts/Enemies/Behaviors/CharmedEnemyBehavior.gd").new()
	charmed_behavior.charm_duration = duration
	charmed_behavior.charm_source = source_unit
	add_child(charmed_behavior)
	behavior = charmed_behavior
	behavior.init(self, enemy_data)

	set_meta("charm_source", source_unit)
	faction = "player"
	modulate = Color(1.0, 0.5, 1.0)

func _ensure_visual_controller():
	if not visual_controller:
		visual_controller = load("res://src/Scripts/Components/VisualController.gd").new()
		add_child(visual_controller)

func update_visuals():
	var icon_texture = AssetLoader.get_enemy_icon(type_key)

	if icon_texture:
		var tex_rect = get_node_or_null("TextureRect")
		if !tex_rect:
			tex_rect = TextureRect.new()
			tex_rect.name = "TextureRect"
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.size = Vector2(40, 40)
			tex_rect.position = -tex_rect.size / 2
			tex_rect.pivot_offset = tex_rect.size / 2
			add_child(tex_rect)

		tex_rect.texture = icon_texture
		tex_rect.show()
		if has_node("Label"):
			$Label.hide()
	else:
		if has_node("TextureRect"):
			$TextureRect.hide()

		if has_node("Label"):
			$Label.show()
			$Label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$Label.text = enemy_data.icon
			$Label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			$Label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if $Label.size.x == 0:
				$Label.size = Vector2(40, 40)
				$Label.position = -$Label.size / 2
			$Label.pivot_offset = $Label.size / 2

	queue_redraw()

func _draw():
	if visual_controller:
		draw_set_transform(visual_controller.visual_offset, visual_controller.visual_rotation, visual_controller.wobble_scale)
	var color = enemy_data.color
	if hit_flash_timer > 0:
		color = Color.WHITE

	if enemy_data.get("shape") == "rect":
		var size_grid = enemy_data.get("size_grid", [2, 1])
		var tile_size = 60
		if GameManager.grid_manager:
			tile_size = GameManager.grid_manager.TILE_SIZE

		var w = size_grid[0] * tile_size
		var h = size_grid[1] * tile_size
		var rect = Rect2(-w/2, -h/2, w, h)
		draw_rect(rect, color)
	else:
		draw_circle(Vector2.ZERO, enemy_data.radius, color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if hp < max_hp and hp > 0:
		var hp_pct = hp / max_hp
		var bar_w = 20
		var bar_h = 4
		var bar_pos = Vector2(-bar_w/2, -enemy_data.radius - 8)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color.RED)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_pct, bar_h)), Color.GREEN)

	# Bleed Indicator
	if bleed_stacks > 0:
		var bleed_pos = Vector2(0, -enemy_data.radius - 20)
		var font = ThemeDB.fallback_font
		var font_size = 12
		draw_string(font, bleed_pos, str(bleed_stacks), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.RED)

func _physics_process(delta):
	if !GameManager.is_wave_active: return

	if invincible_timer > 0:
		invincible_timer -= delta

	# Update Environmental Cooldowns
	var finished_cooldowns = []
	for trap_id in _env_cooldowns:
		_env_cooldowns[trap_id] -= delta
		if _env_cooldowns[trap_id] <= 0:
			finished_cooldowns.append(trap_id)

	for id in finished_cooldowns:
		_env_cooldowns.erase(id)

	# Process Timers and Effects
	if not is_dying:
		if enemy_data.get("shape") == "rect":
			# Apply Physics Rotation
			rotation += angular_velocity * delta * rotation_sensitivity
			angular_velocity = lerp(angular_velocity, 0.0, rotational_damping * delta)
		else:
			_update_facing_logic()

	if blind_timer > 0:
		blind_timer -= delta

	_process_effects(delta)
	_process_bleed_damage(delta)

	if visual_controller:
		visual_controller.update_speed(speed, temp_speed_mod)
		# NOTE: Idle animation handling is now responsibility of Behavior or simplified here.
		# visual_controller.set_idle_enabled(true) # Assuming always idle capable unless attacking

	if is_dying:
		return

	var is_knockback = knockback_velocity.length() > 10.0

	if is_knockback:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		handle_collisions(delta)
		return

	if stun_timer > 0:
		state = State.STUNNED
	elif state == State.STUNNED:
		state = State.MOVE

	if freeze_timer > 0:
		return

	if state == State.STUNNED:
		velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)
		move_and_slide()
		handle_collisions(delta)
	else:
		if behavior:
			behavior.physics_process(delta)

func handle_environmental_impact(trap_node):
	var trap_id = trap_node.get_instance_id()

	if _env_cooldowns.has(trap_id) and _env_cooldowns[trap_id] > 0:
		return

	if not trap_node.props: return
	var type = trap_node.props.get("type")

	if type == "reflect":
		take_damage(trap_node.props.get("strength", 10.0), trap_node, "physical")
		_env_cooldowns[trap_id] = 0.5
	elif type == "poison":
		# Legacy: apply_poison(null, 1, 3.0)
		apply_status(load("res://src/Scripts/Effects/PoisonEffect.gd"), {"duration": 3.0, "damage": 10.0, "stacks": 1})
		_env_cooldowns[trap_id] = 0.5
	elif type == "slow":
		# Legacy: slow_timer = 0.1
		apply_status(load("res://src/Scripts/Effects/SlowEffect.gd"), {"duration": 0.1, "slow_factor": 0.5})

	if trap_node.has_method("spawn_splash_effect"):
		trap_node.spawn_splash_effect(global_position)

func _update_facing_logic():
	if !GameManager.grid_manager: return

	var core_pos = GameManager.grid_manager.global_position
	var diff_x = global_position.x - core_pos.x

	if diff_x > FLIP_THRESHOLD:
		is_facing_left = true
	elif diff_x < -FLIP_THRESHOLD:
		is_facing_left = false

func _process_effects(delta):
	# Burn and Poison are now handled by child Nodes.
	# We just need to handle built-in timers and visual sync if needed.

	if has_node("BurnParticles"):
		# This node might not exist or needs to be controlled by BurnEffect?
		# If it's a legacy child node in the scene, we can keep this or let BurnEffect handle particles.
		# For now, we assume BurnEffect handles logic.
		# If BurnParticles exists in the scene, we should check if we have a BurnEffect.
		var has_burn = false
		for c in get_children():
			if c.get("type_key") == "burn": has_burn = true
		$BurnParticles.emitting = has_burn

	if has_node("PoisonParticles"):
		var has_poison = false
		for c in get_children():
			if c.get("type_key") == "poison": has_poison = true
		$PoisonParticles.emitting = has_poison

	if stun_timer > 0: stun_timer -= delta

	# Apply Visual Controller transforms
	if visual_controller:
		if has_node("TextureRect"):
			visual_controller.apply_to($TextureRect)
		elif has_node("Label"):
			visual_controller.apply_to($Label)

	# Handling facing flip on top of visual controller scale
	var final_scale_x = 1.0
	if visual_controller:
		final_scale_x = visual_controller.wobble_scale.x

	if is_facing_left:
		final_scale_x = -abs(final_scale_x)
	else:
		final_scale_x = abs(final_scale_x)

	# Force override X scale for facing
	if has_node("TextureRect"):
		$TextureRect.scale.x = final_scale_x
	if has_node("Label"):
		$Label.scale.x = final_scale_x

	if has_node("Sprite2D"):
		$Sprite2D.flip_h = is_facing_left

	if bleed_stacks > 0:
		modulate = Color(1.0, 0.5, 0.5) # Red tint for bleed

	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0: queue_redraw()

	if freeze_timer > 0:
		freeze_timer -= delta
		modulate = Color(0.5, 0.5, 1.0)
	else:
		# If not frozen, color is white OR handled by PoisonEffect/SlowEffect
		# We should not forcibly reset to White if effects are active,
		# but PoisonEffect resets on exit.
		# However, if we were frozen, we want to return to whatever state we should be.
		# For simplicity, if not frozen, we don't touch modulate here, letting effects drive it.
		# But we must ensure if we just unfroze, we don't stay blue.
		if modulate == Color(0.5, 0.5, 1.0):
			modulate = Color.WHITE


func handle_collisions(delta):
	var count = get_slide_collision_count()
	for i in range(count):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		var momentum = knockback_velocity.length() * mass

		if knockback_velocity.length() > 50.0:
			if collider is StaticBody2D or (collider is TileMap) or (collider.get_class() == "StaticBody2D"):
				var impact = momentum
				knockback_velocity = Vector2.ZERO
				velocity = Vector2.ZERO

				var dmg = impact * WALL_SLAM_FACTOR
				if dmg > 1:
					take_damage(dmg, null, "physical", null, 0)
					GameManager.spawn_floating_text(global_position, "Slam!", Color.GRAY)

				if impact > HEAVY_IMPACT_THRESHOLD:
					var impact_dir = -collision.get_normal()
					var norm_strength = clamp(impact / 100.0, 0.0, 3.0)
					GameManager.trigger_impact(impact_dir, norm_strength)

				apply_physics_stagger(1.5)

			elif collider is CharacterBody2D and collider.is_in_group("enemies"):
				var target = collider
				if target.has_method("apply_physics_stagger"):
					var t_mass = 1.0
					if "mass" in target: t_mass = target.mass

					var ratio = mass / t_mass

					if "knockback_velocity" in target:
						target.knockback_velocity = knockback_velocity * ratio * TRANSFER_RATE

					if mass > t_mass * 1.5:
						target.apply_physics_stagger(1.0)

					if t_mass > mass * 2:
						apply_physics_stagger(0.5)
						knockback_velocity = -knockback_velocity * 0.5
					else:
						knockback_velocity = knockback_velocity * 0.5

func apply_physics_stagger(duration: float):
	if behavior:
		behavior.cancel_attack()

	if visual_controller:
		visual_controller.kill_tween()
		visual_controller.wobble_scale = Vector2.ONE

	apply_stun(duration)

func apply_status(effect_script: Script, params: Dictionary):
	if not effect_script: return

	# Instantiate a dummy to check type_key?
	# Or rely on type_key being passed in params or standard way to check existance.
	# We need to know if we already have this effect.
	# We can check by script type or a 'key' property if we instance it.

	# Optimization: check children by script
	var existing = null
	for c in get_children():
		if c.get_script() == effect_script:
			existing = c
			break

	if existing:
		existing.stack(params)
	else:
		var effect = effect_script.new()
		add_child(effect)
		effect.setup(self, params.get("source", null), params)

	# Emit debuff_applied signal
	var stacks = params.get("stacks", 1)
	if existing and existing.get("stacks"):
		stacks = existing.stacks

	var type_key = ""
	if existing:
		type_key = existing.type_key
	else:
		# Temporarily instantiate to check type or use passed params if available?
		# Or rely on effect.setup having set type_key.
		# If new effect was added, it is the last child or we can reference it.
		# But we didn't keep reference in variable 'effect' in 'else' block available here easily without refactoring.
		# Let's refactor slightly to keep reference.
		pass

	# Refactoring to capture effect type
	var effect_ref = existing
	if not effect_ref:
		# Retrieve the newly added child (last child)
		effect_ref = get_child(get_child_count() - 1)

	if effect_ref and "type_key" in effect_ref:
		type_key = effect_ref.type_key
		if "stacks" in effect_ref:
			stacks = effect_ref.stacks
		GameManager.debuff_applied.emit(self, type_key, stacks)

func add_poison_stacks(amount: int):
	apply_status(load("res://src/Scripts/Effects/PoisonEffect.gd"), {
		"duration": 5.0,
		"damage": 10.0,
		"stacks": amount,
		"source": null # Or pass self/GameManager if needed
	})

func apply_stun(duration: float):
	stun_timer = duration
	GameManager.spawn_floating_text(global_position, "Stunned!", Color.GRAY)

func apply_freeze(duration: float):
	freeze_timer = duration
	GameManager.spawn_floating_text(global_position, "Frozen!", Color.CYAN)

func apply_blind(duration: float):
	blind_timer = duration
	GameManager.spawn_floating_text(global_position, "Blind!", Color.GRAY)

func apply_debuff(type: String, stacks: int = 1):
	match type:
		"poison":
			apply_status(load("res://src/Scripts/Effects/PoisonEffect.gd"), {"duration": 5.0, "damage": 20.0, "stacks": stacks})
		"burn":
			apply_status(load("res://src/Scripts/Effects/BurnEffect.gd"), {"duration": 5.0, "damage": 20.0, "stacks": stacks})
		"bleed":
			add_bleed_stacks(stacks)
		"slow":
			apply_status(load("res://src/Scripts/Effects/SlowEffect.gd"), {"duration": 3.0, "slow_factor": 0.5})

func is_trap(node):
	if node.get("type") and Constants.BARRICADE_TYPES.has(node.type):
		var b_type = Constants.BARRICADE_TYPES[node.type].type
		return b_type == "slow" or b_type == "poison" or b_type == "reflect"
	return false

func heal(amount: float):
	if hp <= 0: return
	hp = min(hp + amount, max_hp)
	queue_redraw()

func add_bleed_stacks(stacks: int, source_unit = null):
	var old_stacks = bleed_stacks
	bleed_stacks = min(bleed_stacks + stacks, max_bleed_stacks)
	if bleed_stacks != old_stacks:
		bleed_stack_changed.emit(bleed_stacks)
		queue_redraw()

	# Track the bleed source for lifesteal
	if source_unit and _bleed_source_unit == null:
		_bleed_source_unit = source_unit

func _process_bleed_damage(delta: float):
	if bleed_stacks > 0:
		var damage = bleed_stacks * bleed_damage_per_stack * delta

		# Throttle floating text display
		_bleed_display_timer -= delta
		var should_show_text = _bleed_display_timer <= 0
		if should_show_text:
			_bleed_display_timer = BLEED_DISPLAY_INTERVAL

		# Apply damage without floating text for small ticks, show text periodically
		_take_bleed_damage(damage, _bleed_source_unit, should_show_text)

func _take_bleed_damage(amount: float, source_unit = null, show_text: bool = true):
	if invincible_timer > 0:
		return

	if behavior:
		var handled = behavior.on_hit({
			"amount": amount,
			"source_unit": source_unit,
			"damage_type": "bleed"
		})
		if handled: return

	# Vulnerable Effect Check
	for child in get_children():
		if child.has_method("get_damage_multiplier"):
			amount *= child.get_damage_multiplier()

	hp -= amount

	# Only show floating text periodically
	if show_text:
		hit_flash_timer = 0.1
		queue_redraw()
		var display_val = max(1, int(amount))
		GameManager.spawn_floating_text(global_position, str(display_val), "bleed", Vector2.ZERO)

	GameManager.enemy_hit.emit(self, source_unit, amount)

	# Emit bleed_damage signal for test logging
	if GameManager.has_signal("bleed_damage"):
		GameManager.bleed_damage.emit(self, amount, bleed_stacks, source_unit)

	if source_unit:
		GameManager.damage_dealt.emit(source_unit, amount)

	if hp <= 0:
		die(source_unit)

func add_debuff(type: String, stacks: int, duration: float):
	if type == "vulnerable":
		apply_status(load("res://src/Scripts/Effects/VulnerableEffect.gd"), {"duration": duration, "stacks": stacks})

func take_damage(amount: float, source_unit = null, damage_type: String = "physical", hit_source: Node2D = null, kb_force: float = 0.0):
	if source_unit == GameManager:
		print("[Enemy] Taking global damage from GameManager: ", amount)

	if invincible_timer > 0:
		return

	if behavior:
		var handled = behavior.on_hit({
			"amount": amount,
			"source_unit": source_unit,
			"damage_type": damage_type,
			"hit_source": hit_source,
			"kb_force": kb_force
		})
		if handled: return

	# Vulnerable Effect Check
	for child in get_children():
		if child.has_method("get_damage_multiplier"):
			amount *= child.get_damage_multiplier()

	hp -= amount
	hit_flash_timer = 0.1
	queue_redraw()
	var hit_dir = Vector2.ZERO
	if hit_source and is_instance_valid(hit_source) and "speed" in hit_source:
		hit_dir = Vector2.RIGHT.rotated(hit_source.rotation)
	last_hit_direction = hit_dir

	if enemy_data.get("shape") == "rect":
		# Torque calculation
		var hit_pos = global_position
		if hit_source and "global_position" in hit_source:
			hit_pos = hit_source.global_position

		var r = hit_pos - global_position
		var force_dir = hit_dir
		if force_dir == Vector2.ZERO and hit_source:
			force_dir = (global_position - hit_source.global_position).normalized()

		var torque = r.x * force_dir.y - r.y * force_dir.x
		angular_velocity += torque * 0.05

	if kb_force > 0:
		var applied_force = kb_force / max(0.1, knockback_resistance)
		knockback_velocity += hit_dir * applied_force
	var display_val = max(1, int(amount))
	GameManager.spawn_floating_text(global_position, str(display_val), damage_type, hit_dir)

	GameManager.enemy_hit.emit(self, source_unit, amount)

	if source_unit:
		GameManager.damage_dealt.emit(source_unit, amount)

	if hp <= 0:
		die(source_unit)

func _on_death():
	# 增加狼图腾魂魄（魅惑击杀额外+1）
	var soul_amount = 1
	if faction == "player" and has_meta("charm_source"):
		soul_amount += 1
		GameManager.spawn_floating_text(global_position, "+1 Soul (Charm)", Color.MAGENTA)

	TotemManager.add_resource("wolf", soul_amount)

func die(killer_unit = null):
	if is_dying:
		return
	is_dying = true

	# Check for petrified state
	if has_meta("is_petrified") and get_meta("is_petrified"):
		_play_petrified_death_effect()

	_on_death()

	# Kill Bonus Check
	if GameManager.combat_manager and killer_unit:
		GameManager.combat_manager.check_kill_bonuses(killer_unit, self)

	emit_signal("died")
	GameManager.enemy_died.emit(self, killer_unit)

	GameManager.add_gold(1)
	if GameManager.reward_manager and "scrap_recycling" in GameManager.reward_manager.acquired_artifacts:
		if GameManager.grid_manager:
			var core_pos = GameManager.grid_manager.global_position
			if global_position.distance_to(core_pos) < 200.0:
				GameManager.damage_core(-5)
				GameManager.add_gold(1)
				GameManager.spawn_floating_text(global_position, "+1💰 (Recycle)", Color.GOLD, last_hit_direction)
	GameManager.spawn_floating_text(global_position, "+1💰", Color.YELLOW, last_hit_direction)

	var handled = false
	if behavior:
		handled = behavior.on_death(killer_unit)

	if !handled:
		queue_free()

func _play_petrified_death_effect():
	# Calculate damage percent
	var damage_percent = 0.1  # Default LV1/LV2
	var petrify_source = get_meta("petrify_source", null)
	if petrify_source and is_instance_valid(petrify_source) and petrify_source.get("level"):
		if petrify_source.level >= 3:
			damage_percent = 0.2  # LV3: 20%

	var shatter = load("res://src/Scenes/Effects/PetrifiedShatterEffect.tscn").instantiate()
	shatter.global_position = global_position
	shatter.launch_direction = last_hit_direction
	shatter.damage_percent = damage_percent
	shatter.source_max_hp = max_hp
	shatter.enemy_texture = AssetLoader.get_enemy_icon(type_key)
	shatter.enemy_color = enemy_data.color

	get_tree().current_scene.add_child(shatter)

func find_attack_target() -> Node2D:
	# First check taunt units
	# Assuming AggroManager is available as Autoload
	var target = AggroManager.get_target_for_enemy(self)
	if target:
		_show_taunt_indicator(true)
		return target

	_show_taunt_indicator(false)
	# Default attack core (return null implies default behavior in DefaultBehavior)
	return null

func _show_taunt_indicator(active: bool):
	var indicator = get_node_or_null("TauntIndicator")
	if active:
		if !indicator:
			indicator = Label.new()
			indicator.name = "TauntIndicator"
			indicator.text = "!"
			indicator.modulate = Color.RED
			indicator.add_theme_font_size_override("font_size", 24)
			indicator.position = Vector2(-10, -50)
			add_child(indicator)
		indicator.show()
	else:
		if indicator:
			indicator.hide()

func has_status(type_key: String) -> bool:
	for c in get_children():
		if c is StatusEffect and c.type_key == type_key:
			return true
	return false
