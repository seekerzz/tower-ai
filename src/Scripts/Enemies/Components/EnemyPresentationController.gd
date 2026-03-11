extends RefCounted
class_name EnemyPresentationController

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var enemy: CharacterBody2D

func _init(target_enemy: CharacterBody2D):
	enemy = target_enemy

func ensure_visual_controller():
	if not enemy.visual_controller:
		enemy.visual_controller = load("res://src/Scripts/Components/VisualController.gd").new()
		enemy.add_child(enemy.visual_controller)

func update_visuals():
	var icon_texture = AssetLoader.get_enemy_icon(enemy.type_key)

	if icon_texture:
		var tex_rect = enemy.get_node_or_null("TextureRect")
		if !tex_rect:
			tex_rect = TextureRect.new()
			tex_rect.name = "TextureRect"
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.size = Vector2(40, 40)
			tex_rect.position = -tex_rect.size / 2
			tex_rect.pivot_offset = tex_rect.size / 2
			enemy.add_child(tex_rect)

		tex_rect.texture = icon_texture
		tex_rect.show()
		if enemy.has_node("Label"):
			enemy.get_node("Label").hide()
	else:
		if enemy.has_node("TextureRect"):
			enemy.get_node("TextureRect").hide()

		if enemy.has_node("Label"):
			var label = enemy.get_node("Label")
			label.show()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.text = enemy.enemy_data.icon
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if label.size.x == 0:
				label.size = Vector2(40, 40)
				label.position = -label.size / 2
			label.pivot_offset = label.size / 2

	enemy.queue_redraw()

func draw_enemy():
	if enemy.visual_controller:
		enemy.draw_set_transform(enemy.visual_controller.visual_offset, enemy.visual_controller.visual_rotation, enemy.visual_controller.wobble_scale)
	var color = enemy.enemy_data.color
	if enemy.hit_flash_timer > 0:
		color = Color.WHITE

	if enemy.enemy_data.get("shape") == "rect":
		var size_grid = enemy.enemy_data.get("size_grid", [2, 1])
		var tile_size = 60
		if GameManager.grid_manager:
			tile_size = GameManager.grid_manager.TILE_SIZE

		var w = size_grid[0] * tile_size
		var h = size_grid[1] * tile_size
		enemy.draw_rect(Rect2(-w / 2, -h / 2, w, h), color)
	else:
		enemy.draw_circle(Vector2.ZERO, enemy.enemy_data.radius, color)

	enemy.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if enemy.hp < enemy.max_hp and enemy.hp > 0:
		var hp_pct = enemy.hp / enemy.max_hp
		var bar_w = 20
		var bar_h = 4
		var bar_pos = Vector2(-bar_w / 2, -enemy.enemy_data.radius - 8)
		enemy.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color.RED)
		enemy.draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_pct, bar_h)), Color.GREEN)

	if enemy.bleed_stacks > 0:
		var bleed_pos = Vector2(0, -enemy.enemy_data.radius - 20)
		enemy.draw_string(ThemeDB.fallback_font, bleed_pos, str(enemy.bleed_stacks), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.RED)

func process_effects(delta: float):
	if enemy.has_node("BurnParticles"):
		var has_burn = false
		for c in enemy.get_children():
			if c.get("type_key") == "burn":
				has_burn = true
		enemy.get_node("BurnParticles").emitting = has_burn

	if enemy.has_node("PoisonParticles"):
		var has_poison = false
		for c in enemy.get_children():
			if c.get("type_key") == "poison":
				has_poison = true
		enemy.get_node("PoisonParticles").emitting = has_poison

	if enemy.visual_controller:
		if enemy.has_node("TextureRect"):
			enemy.visual_controller.apply_to(enemy.get_node("TextureRect"))
		elif enemy.has_node("Label"):
			enemy.visual_controller.apply_to(enemy.get_node("Label"))

	var final_scale_x = enemy.visual_controller.wobble_scale.x if enemy.visual_controller else 1.0
	final_scale_x = -abs(final_scale_x) if enemy.is_facing_left else abs(final_scale_x)

	if enemy.has_node("TextureRect"):
		enemy.get_node("TextureRect").scale.x = final_scale_x
	if enemy.has_node("Label"):
		enemy.get_node("Label").scale.x = final_scale_x
	if enemy.has_node("Sprite2D"):
		enemy.get_node("Sprite2D").flip_h = enemy.is_facing_left

	if enemy.bleed_stacks > 0:
		enemy.modulate = Color(1.0, 0.5, 0.5)
		if enemy.bleed_stacks >= enemy.max_bleed_stacks:
			show_max_bleed_effect(delta)

	if enemy.hit_flash_timer > 0:
		enemy.hit_flash_timer -= delta
		if enemy.hit_flash_timer <= 0:
			enemy.queue_redraw()

	if enemy.freeze_timer > 0:
		enemy.freeze_timer -= delta
		enemy.modulate = Color(0.5, 0.5, 1.0)
	elif enemy.modulate == Color(0.5, 0.5, 1.0):
		enemy.modulate = Color.WHITE

func show_taunt_indicator(active: bool):
	var indicator = enemy.get_node_or_null("TauntIndicator")
	if active:
		if !indicator:
			indicator = Label.new()
			indicator.name = "TauntIndicator"
			indicator.text = "!"
			indicator.modulate = Color.RED
			indicator.add_theme_font_size_override("font_size", 24)
			indicator.position = Vector2(-10, -50)
			enemy.add_child(indicator)
		indicator.show()
	elif indicator:
		indicator.hide()

func set_execute_warning(active: bool, threshold: float = 0.0):
	enemy._execute_warning_active = active
	enemy._execute_threshold = threshold
	if active:
		_show_execute_warning()
	else:
		hide_execute_warning()

func _show_execute_warning():
	if not enemy._execute_indicator:
		enemy._execute_indicator = Label.new()
		enemy._execute_indicator.name = "ExecuteIndicator"
		enemy._execute_indicator.text = "☠"
		enemy._execute_indicator.add_theme_font_size_override("font_size", 24)
		enemy._execute_indicator.add_theme_color_override("font_color", Color(0.75, 0.22, 0.17))
		enemy._execute_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
		enemy._execute_indicator.add_theme_constant_override("outline_size", 3)
		enemy._execute_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enemy._execute_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		enemy._execute_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy.add_child(enemy._execute_indicator)

	var radius = enemy.enemy_data.get("radius", 20.0) if enemy.enemy_data else 20.0
	enemy._execute_indicator.position = Vector2(-15, -radius - 55)
	enemy._execute_indicator.size = Vector2(30, 30)
	enemy._execute_indicator.visible = true

	if not enemy._execute_border:
		enemy._execute_border = ColorRect.new()
		enemy._execute_border.name = "ExecuteBorder"
		enemy._execute_border.color = Color(0.75, 0.22, 0.17, 0.5)
		enemy._execute_border.size = Vector2(60, 60)
		enemy._execute_border.position = Vector2(-30, -30)
		enemy._execute_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy.add_child(enemy._execute_border)
		enemy._execute_border.z_index = -2

	if not enemy._execute_border.has_meta("pulsing"):
		enemy._execute_border.set_meta("pulsing", true)
		var tween = enemy.create_tween().set_loops()
		tween.tween_property(enemy._execute_border, "color:a", 0.8, 0.5)
		tween.tween_property(enemy._execute_border, "color:a", 0.3, 0.5)

func hide_execute_warning():
	if enemy._execute_indicator and is_instance_valid(enemy._execute_indicator):
		enemy._execute_indicator.visible = false
	if enemy._execute_border and is_instance_valid(enemy._execute_border):
		enemy._execute_border.queue_free()
		enemy._execute_border = null

func play_execute_effect():
	enemy.modulate = Color.WHITE
	var tween = enemy.create_tween()
	tween.tween_property(enemy, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(enemy, "scale", enemy.scale * 1.2, 0.3)

func show_max_bleed_effect(delta: float):
	if not enemy._max_bleed_glow:
		enemy._max_bleed_glow = ColorRect.new()
		enemy._max_bleed_glow.name = "MaxBleedGlow"
		enemy._max_bleed_glow.color = Color(0.9, 0.1, 0.1, 0.4)
		enemy._max_bleed_glow.size = Vector2(70, 70)
		enemy._max_bleed_glow.position = Vector2(-35, -35)
		enemy._max_bleed_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy.add_child(enemy._max_bleed_glow)
		enemy._max_bleed_glow.z_index = -1

		var tween = enemy.create_tween().set_loops()
		tween.tween_property(enemy._max_bleed_glow, "color:a", 0.7, 0.4)
		tween.tween_property(enemy._max_bleed_glow, "color:a", 0.3, 0.4)

	enemy._max_bleed_particles_timer -= delta
	if enemy._max_bleed_particles_timer <= 0:
		enemy._max_bleed_particles_timer = enemy.MAX_BLEED_PARTICLE_INTERVAL
		_spawn_bleed_particle()

func _spawn_bleed_particle():
	var particle = Node2D.new()
	particle.global_position = enemy.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	var visual = Polygon2D.new()
	var size = randf_range(3, 6)
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.5, 0),
		Vector2(0, size),
		Vector2(-size * 0.5, 0)
	])
	visual.color = Color(0.8, 0.0, 0.0, 0.8)
	particle.add_child(visual)
	if enemy.get_parent():
		enemy.get_parent().add_child(particle)
	var tween = particle.create_tween()
	tween.tween_property(particle, "global_position:y", particle.global_position.y + randf_range(30, 60), 0.5)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.5)
	tween.tween_callback(particle.queue_free)

func clear_max_bleed_effect():
	if enemy._max_bleed_glow and is_instance_valid(enemy._max_bleed_glow):
		enemy._max_bleed_glow.queue_free()
		enemy._max_bleed_glow = null
