class_name Enemy
extends CharacterBody2D

const EnemyBehavior = preload("res://src/Scripts/Enemies/Behaviors/EnemyBehavior.gd")
const EnemyPresentationController = preload("res://src/Scripts/Enemies/Components/EnemyPresentationController.gd")
const EnemyStatusController = preload("res://src/Scripts/Enemies/Components/EnemyStatusController.gd")
const EnemyPhysicsController = preload("res://src/Scripts/Enemies/Components/EnemyPhysicsController.gd")
const EnemyDamageController = preload("res://src/Scripts/Enemies/Components/EnemyDamageController.gd")
const EnemyDeathController = preload("res://src/Scripts/Enemies/Components/EnemyDeathController.gd")

signal died
signal attack_missed(enemy)
signal bleed_stack_changed(new_stacks: int)

enum State { MOVE, ATTACK_BASE, STUNNED, SUPPORT }
var state: State = State.MOVE

var faction: String = "enemy"
var type_key: String
var hp: float
var max_hp: float
var speed: float
var enemy_data: Dictionary

var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var blind_timer: float = 0.0
var _env_cooldowns = {}

var hit_flash_timer: float = 0.0
var temp_speed_mod: float = 1.0
var visual_controller: Node2D = null
var anim_config: Dictionary = {}
var base_speed: float = 40.0

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_resistance: float = 1.0
const WALL_SLAM_FACTOR = 0.5
const HEAVY_IMPACT_THRESHOLD = 50.0
const TRANSFER_RATE = 0.8
const FLIP_THRESHOLD = 15.0

var mass: float = 1.0
var is_facing_left: bool = false
var is_dying: bool = false

var angular_velocity: float = 0.0
var rotational_damping: float = 5.0
var rotation_sensitivity = 5.0

var invincible_timer: float = 0.0
var last_hit_direction: Vector2 = Vector2.ZERO
var behavior: EnemyBehavior

var bleed_stacks: int = 0
var max_bleed_stacks: int = 30
var bleed_damage_per_stack: float = 3.0
var _bleed_source_unit: Object = null
var _bleed_display_timer: float = 0.0
const BLEED_DISPLAY_INTERVAL: float = 0.3

var _execute_warning_active: bool = false
var _execute_threshold: float = 0.0
var _execute_indicator: Label = null
var _execute_border: ColorRect = null

var _max_bleed_glow: ColorRect = null
var _max_bleed_particles_timer: float = 0.0
const MAX_BLEED_PARTICLE_INTERVAL: float = 0.2

var presentation: EnemyPresentationController
var status_controller: EnemyStatusController
var physics_controller: EnemyPhysicsController
var damage_controller: EnemyDamageController
var death_controller: EnemyDeathController

func _ready():
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 2
	input_pickable = false
	GameManager._set_ignore_mouse_recursive(self)

	presentation = EnemyPresentationController.new(self)
	status_controller = EnemyStatusController.new(self)
	physics_controller = EnemyPhysicsController.new(self)
	damage_controller = EnemyDamageController.new(self)
	death_controller = EnemyDeathController.new(self)

	presentation.ensure_visual_controller()
	GameManager.enemy_spawned.emit(self)

func setup(key: String, wave: int):
	presentation.ensure_visual_controller()
	type_key = key
	enemy_data = Constants.ENEMY_VARIANTS[key]
	anim_config = enemy_data.get("anim_config", {})

	var base_hp = 100 + (wave * 80)
	hp = base_hp * enemy_data.hpMod
	max_hp = hp
	speed = (40 + (wave * 2)) * enemy_data.spdMod
	base_speed = speed

	var col_shape = get_node_or_null("CollisionShape2D")
	if !col_shape:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		add_child(col_shape)

	mass = 1.0
	knockback_resistance = 1.0
	if enemy_data.get("is_boss", false) or type_key == "tank":
		knockback_resistance = 10.0
		mass = 5.0

	if enemy_data.get("shape") == "rect":
		knockback_resistance = 8.0
		mass = 5.0
		var size_grid = enemy_data.get("size_grid", [1, 1])
		var tile_size = GameManager.grid_manager.TILE_SIZE if GameManager.grid_manager else 60
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(size_grid[0] * tile_size, size_grid[1] * tile_size) * 0.8
		col_shape.shape = rect_shape
	else:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = enemy_data.radius
		col_shape.shape = circle_shape

	var mass_mod = GameManager.get_stat_modifier("enemy_mass")
	mass *= mass_mod
	knockback_resistance *= mass_mod

	visual_controller.setup(anim_config, base_speed, speed)
	presentation.update_visuals()
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
	if GameManager.has_signal("charm_applied"):
		GameManager.charm_applied.emit(self, duration, source_unit)

func _physics_process(delta):
	if !GameManager.is_wave_active:
		return
	if invincible_timer > 0:
		invincible_timer -= delta
	status_controller.process_environmental_cooldowns(delta)
	physics_controller.process_orientation(delta)
	status_controller.process_blind_timer(delta)
	status_controller.process_stun_timer(delta)
	presentation.process_effects(delta)
	damage_controller.process_bleed_damage(delta)
	if visual_controller:
		visual_controller.update_speed(speed, temp_speed_mod)
	if is_dying:
		return
	if physics_controller.handle_knockback(delta):
		return
	physics_controller.update_state_from_stun()
	if freeze_timer > 0:
		return
	if state == State.STUNNED:
		physics_controller.process_stunned_movement(delta)
	elif behavior:
		behavior.physics_process(delta)

func _draw():
	presentation.draw_enemy()

func update_visuals():
	presentation.update_visuals()

func handle_environmental_impact(trap_node):
	status_controller.handle_environmental_impact(trap_node)

func handle_collisions(delta):
	physics_controller.handle_collisions(delta)

func apply_physics_stagger(duration: float):
	physics_controller.apply_physics_stagger(duration)

func apply_status(effect_script: Script, params: Dictionary):
	status_controller.apply_status(effect_script, params)

func add_poison_stacks(amount: int):
	status_controller.add_poison_stacks(amount)

func apply_stun(duration: float):
	status_controller.apply_stun(duration)

func apply_freeze(duration: float):
	status_controller.apply_freeze(duration)

func apply_blind(duration: float):
	status_controller.apply_blind(duration)

func apply_debuff(type: String, stacks: int = 1):
	status_controller.apply_debuff(type, stacks)

func add_debuff(type: String, stacks: int, duration: float):
	status_controller.add_debuff(type, stacks, duration)

func is_trap(node):
	return status_controller.is_trap(node)

func has_status(type_key: String) -> bool:
	return status_controller.has_status(type_key)

func heal(amount: float):
	damage_controller.heal(amount)

func add_bleed_stacks(stacks: int, source_unit = null):
	damage_controller.add_bleed_stacks(stacks, source_unit)

func take_damage(amount: float, source_unit = null, damage_type: String = "physical", hit_source: Node2D = null, kb_force: float = 0.0):
	damage_controller.take_damage(amount, source_unit, damage_type, hit_source, kb_force, true)

func die(killer_unit = null):
	death_controller.die(killer_unit)

func find_attack_target() -> Node2D:
	var target = AggroManager.get_target_for_enemy(self)
	presentation.show_taunt_indicator(target != null)
	return target

func _show_taunt_indicator(active: bool):
	presentation.show_taunt_indicator(active)

func set_execute_warning(active: bool, threshold: float = 0.0):
	presentation.set_execute_warning(active, threshold)

func _hide_execute_warning():
	presentation.hide_execute_warning()

func play_execute_effect():
	presentation.play_execute_effect()

func _clear_max_bleed_effect():
	presentation.clear_max_bleed_effect()
