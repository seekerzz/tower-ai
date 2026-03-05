extends "res://src/Scripts/Enemies/SupportEnemy.gd"

# Healer implementation

func find_support_target() -> Node2D:
	var potential_targets = get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var lowest_hp_pct = 1.0

	for enemy in potential_targets:
		if enemy == self: continue
		if !is_instance_valid(enemy): continue
		if enemy.hp >= enemy.max_hp: continue # Full health
		if enemy.is_dying: continue

		var dist = global_position.distance_to(enemy.global_position)
		if dist > support_range: continue

		var hp_pct = enemy.hp / enemy.max_hp
		if hp_pct < lowest_hp_pct:
			lowest_hp_pct = hp_pct
			best_target = enemy

	return best_target

func perform_support_action(target):
	if !is_instance_valid(target): return

	# Heal
	target.heal(heal_power)

	# Visual Feedback
	GameManager.spawn_floating_text(target.global_position, "+" + str(int(heal_power)), Color.GREEN)

	# Line Effect
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Color.GREEN
	line.points = [Vector2.ZERO, target.global_position - global_position]
	add_child(line)

	# Fade out line
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
