extends "res://src/Scripts/Enemies/Behaviors/DefaultBehavior.gd"

var split_generation: int = 0
var hit_count: int = 0
var ancestor_max_hp: float = 0.0
var is_splitting: bool = false

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	super.init(enemy_node, enemy_data)
	if split_generation == 0:
		ancestor_max_hp = enemy.get_node("Stats").max_hp
		enemy.scale = Vector2(1.5, 1.5)

func on_hit(damage_info: Dictionary) -> bool:
	if is_splitting: return true

	hit_count += 1
	if hit_count >= 5 and split_generation < 2 and enemy.get_node("Stats").current_hp > 0:
		is_splitting = true
		_perform_split()
		return true

	return false

func set_split_info(gen: int, anc_hp: float):
	split_generation = gen
	ancestor_max_hp = anc_hp

func _perform_split():
	var child_hp = min(enemy.get_node("Stats").current_hp, enemy.get_node("Stats").max_hp / 2.0)
	var parent = enemy.get_parent()
	var spawn_position = enemy.global_position
	var type_key = enemy.type_key
	var current_gen = split_generation
	var current_anc_hp = ancestor_max_hp

	# CRASH-003 FIX: Use call_deferred to avoid physics query flush error
	# Defer the actual spawning to avoid modifying physics state during query flush
	call_deferred("_call_deferred_spawn_children", parent, spawn_position, type_key, child_hp, current_gen, current_anc_hp)

	# Defer the parent removal as well
	enemy.call_deferred("queue_free")

func _call_deferred_spawn_children(parent, spawn_position, type_key, child_hp, current_gen, current_anc_hp):
	# This function is called via call_deferred to avoid physics state modification during query flush
	for i in range(2):
		var child = load("res://src/Scenes/Game/Enemy.tscn").instantiate()
		var current_wave = GameManager.session_data.wave if GameManager.session_data else 1

		# CRASH-003 FIX: Defer the setup call to avoid physics state modification
		# setup() modifies collision shapes which can't be done during physics query
		# Store setup data in child metadata for deferred application
		child.set_meta("_deferred_setup_data", {
			"type_key": type_key,
			"current_wave": current_wave,
			"child_hp": child_hp,
			"current_gen": current_gen,
			"current_anc_hp": current_anc_hp,
			"spawn_position": spawn_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		})

		parent.add_child(child)

		# CRASH-003 FIX: Use await to defer setup to next frame
		# This ensures physics state is not being modified during query flush
		child.global_position = spawn_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		_apply_child_setup_deferred(child)

func _apply_child_setup_deferred(child):
	# Wait for next frame to avoid physics state modification during query flush
	await child.get_tree().process_frame

	var data = child.get_meta("_deferred_setup_data")
	child.setup(data["type_key"], data["current_wave"])

	# Transfer properties to child behavior
	if child.behavior and child.behavior.has_method("set_split_info"):
		child.behavior.set_split_info(data["current_gen"] + 1, data["current_anc_hp"])

	child.max_hp = data["child_hp"]
	child.hp = data["child_hp"]

	var new_scale = 1.0
	if data["current_gen"] + 1 == 1:
		new_scale = 1.0
	elif data["current_gen"] + 1 == 2:
		new_scale = 0.75

	child.scale = Vector2(new_scale, new_scale)
	child.invincible_timer = 0.5

	# WAVE-FIX: 连接死亡信号到 WaveSystemManager，确保分裂产生的敌人被正确追踪
	if GameManager.wave_system_manager and child.has_signal("died"):
		child.died.connect(GameManager.wave_system_manager._on_enemy_died.bind(child))
