extends RefCounted
class_name EnemyDeathController

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var enemy: CharacterBody2D

func _init(target_enemy: CharacterBody2D):
	enemy = target_enemy

func on_death_rewards():
	var soul_amount = 1
	if enemy.faction == "player" and enemy.has_meta("charm_source"):
		soul_amount += 1
		GameManager.spawn_floating_text(enemy.global_position, "+1 Soul (Charm)", Color.MAGENTA)
	TotemManager.add_resource("wolf", soul_amount)

func die(killer_unit = null):
	if enemy.is_dying:
		return

	if enemy.has_meta("is_clone") and enemy.get_meta("is_clone"):
		enemy.queue_free()
		return

	enemy.is_dying = true
	if enemy.has_meta("is_petrified") and enemy.get_meta("is_petrified"):
		play_petrified_death_effect()
	on_death_rewards()
	if GameManager.combat_manager and killer_unit:
		GameManager.combat_manager.check_kill_bonuses(killer_unit, enemy)
	enemy.emit_signal("died")
	GameManager.enemy_died.emit(enemy, killer_unit)
	GameManager.add_gold(1)
	if GameManager.reward_manager and "scrap_recycling" in GameManager.reward_manager.acquired_artifacts:
		if GameManager.grid_manager:
			var core_pos = GameManager.grid_manager.global_position
			if enemy.global_position.distance_to(core_pos) < 200.0:
				GameManager.damage_core(-5)
				GameManager.add_gold(1)
				GameManager.spawn_floating_text(enemy.global_position, "+1💰 (Recycle)", Color.GOLD, enemy.last_hit_direction)
	GameManager.spawn_floating_text(enemy.global_position, "+1💰", Color.YELLOW, enemy.last_hit_direction)
	var handled = false
	if enemy.behavior:
		handled = enemy.behavior.on_death(killer_unit)
	enemy._clear_max_bleed_effect()
	enemy._hide_execute_warning()
	if !handled:
		enemy.queue_free()

func play_petrified_death_effect():
	var damage_percent = 0.1
	var petrify_source = enemy.get_meta("petrify_source", null)
	if petrify_source and is_instance_valid(petrify_source) and petrify_source.get("level"):
		if petrify_source.level >= 3:
			damage_percent = 0.2

	var shatter = load("res://src/Scenes/Effects/PetrifiedShatterEffect.tscn").instantiate()
	shatter.global_position = enemy.global_position
	shatter.launch_direction = enemy.last_hit_direction
	shatter.damage_percent = damage_percent
	shatter.source_max_hp = enemy.max_hp
	shatter.enemy_texture = AssetLoader.get_enemy_icon(enemy.type_key)
	shatter.enemy_color = enemy.enemy_data.color
	enemy.get_tree().current_scene.add_child(shatter)
	enhance_petrified_shatter_effect(enemy.global_position)

func enhance_petrified_shatter_effect(pos: Vector2):
	if GameManager.has_signal("world_impact"):
		GameManager.world_impact.emit(Vector2(randf_range(-1, 1), randf_range(-1, 1)), 8.0)
	var label = Label.new()
	label.text = "碎裂!"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.55))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -30)
	var container = Node2D.new()
	container.global_position = pos + Vector2(0, -50)
	container.add_child(label)
	container.z_index = 180
	enemy.get_tree().root.add_child(container)
	var tween = container.create_tween()
	container.scale = Vector2(0.5, 0.5)
	tween.tween_property(container, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.4)
	tween.tween_property(container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(container.queue_free)
	show_aoe_damage_circle(pos)

func show_aoe_damage_circle(pos: Vector2):
	var circle = Node2D.new()
	circle.global_position = pos
	var visual = Polygon2D.new()
	var points = PackedVector2Array()
	var radius = 100.0
	for i in range(32):
		var angle = (float(i) / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = points
	visual.color = Color(0.5, 0.55, 0.55, 0.3)
	circle.add_child(visual)
	var border = Line2D.new()
	border.points = points
	border.width = 2.0
	border.default_color = Color(0.5, 0.55, 0.55, 0.8)
	circle.add_child(border)
	enemy.get_tree().root.add_child(circle)
	var tween = circle.create_tween()
	tween.tween_property(circle, "scale", Vector2(1.2, 1.2), 0.4)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(border, "modulate:a", 0.0, 0.4)
	tween.tween_callback(circle.queue_free)
