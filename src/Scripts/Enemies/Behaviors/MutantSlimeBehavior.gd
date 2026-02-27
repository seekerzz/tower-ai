extends "res://src/Scripts/Enemies/Behaviors/DefaultBehavior.gd"

var split_generation: int = 0
var hit_count: int = 0
var ancestor_max_hp: float = 0.0
var is_splitting: bool = false

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	super.init(enemy_node, enemy_data)
	if split_generation == 0:
		ancestor_max_hp = enemy.max_hp
		enemy.scale = Vector2(1.5, 1.5)

func on_hit(damage_info: Dictionary) -> bool:
	if is_splitting: return true

	hit_count += 1
	if hit_count >= 5 and split_generation < 2 and enemy.hp > 0:
		is_splitting = true
		_perform_split()
		return true

	return false

func set_split_info(gen: int, anc_hp: float):
	split_generation = gen
	ancestor_max_hp = anc_hp

func _perform_split():
	var child_hp = min(enemy.hp, enemy.max_hp / 2.0)

	for i in range(2):
		var child = load("res://src/Scenes/Game/Enemy.tscn").instantiate()
		child.setup(enemy.type_key, GameManager.wave)

		# Transfer properties to child behavior
		if child.behavior and child.behavior.has_method("set_split_info"):
			child.behavior.set_split_info(split_generation + 1, ancestor_max_hp)

		child.max_hp = child_hp
		child.hp = child_hp
		# child.hit_count starts at 0 by default in new behavior

		var new_scale = 1.0
		if split_generation + 1 == 1:
			new_scale = 1.0
		elif split_generation + 1 == 2:
			new_scale = 0.75

		child.scale = Vector2(new_scale, new_scale)
		child.invincible_timer = 0.5

		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		child.global_position = enemy.global_position + offset

		enemy.get_parent().add_child(child)

	enemy.queue_free()
