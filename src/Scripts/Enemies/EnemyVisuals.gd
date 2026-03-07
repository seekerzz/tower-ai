extends Node2D

var enemy: Node = null

var _execute_indicator: Label = null
var _execute_border: ColorRect = null

var _max_bleed_glow: ColorRect = null
var _max_bleed_particles_timer: float = 0.0
const MAX_BLEED_PARTICLE_INTERVAL: float = 0.2

var hit_flash_timer: float = 0.0
var _base_color: Color = Color.WHITE

var _taunt_indicator: Label = null

func _ready():
    # Attempt to find the parent Enemy
    enemy = get_parent()
    if enemy and enemy is CharacterBody2D: # Checking loosely for Enemy class traits
        # Connect to enemy signals
        if enemy.has_signal("hp_changed"):
            enemy.hp_changed.connect(_on_hp_changed)
        if enemy.has_signal("status_applied"):
            enemy.status_applied.connect(_on_status_applied)
        if enemy.has_signal("bleed_stack_changed"):
            enemy.bleed_stack_changed.connect(_on_bleed_stack_changed)
        if enemy.has_signal("died"):
            enemy.died.connect(_on_died)

        _base_color = enemy.enemy_data.get("color", Color.WHITE) if enemy.get("enemy_data") else Color.WHITE

func _process(delta):
    if hit_flash_timer > 0:
        hit_flash_timer -= delta
        queue_redraw()

    if enemy and enemy.get("bleed_stacks") != null and enemy.bleed_stacks >= 30:
        _show_max_bleed_effect(delta)

func _draw():
    if not enemy or not enemy.get("enemy_data"):
        return

    var enemy_data = enemy.enemy_data

    var visual_controller = enemy.get("visual_controller")
    if visual_controller:
        draw_set_transform(visual_controller.visual_offset, visual_controller.visual_rotation, visual_controller.wobble_scale)

    var color = enemy_data.get("color", Color.WHITE)
    if hit_flash_timer > 0:
        color = Color.WHITE
    elif enemy.has_method("has_status") and enemy.has_status("freeze"):
        color = Color(0.5, 0.5, 1.0) # Apply freeze color natively here

    if enemy_data.get("shape") == "rect":
        var size_grid = enemy_data.get("size_grid", [2, 1])
        var tile_size = 60 # Default fallback
        # GameManager check if needed, but we can hardcode or lookup differently
        if Engine.has_singleton("GameManager"):
             var gm = Engine.get_singleton("GameManager")
             if gm and gm.get("grid_manager"):
                  tile_size = gm.grid_manager.TILE_SIZE
        var w = size_grid[0] * tile_size
        var h = size_grid[1] * tile_size
        var rect = Rect2(-w/2, -h/2, w, h)
        draw_rect(rect, color)
    else:
        var radius = enemy_data.get("radius", 20.0)
        draw_circle(Vector2.ZERO, radius, color)

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _on_hp_changed(old_hp: float, new_hp: float):
    if new_hp < old_hp:
        hit_flash_timer = 0.1
        queue_redraw()

    # Execute warning logic
    if enemy and enemy.get("_execute_warning_active") != null:
        if enemy._execute_warning_active:
            _show_execute_warning()
        else:
            _hide_execute_warning()

func _on_status_applied(type_key: String, duration: float, source: Object):
    if type_key == "freeze":
        queue_redraw()

func _on_bleed_stack_changed(new_stacks: int):
    if enemy and new_stacks < 30:
        _clear_max_bleed_effect()

func _on_died(killer = null):
    _clear_max_bleed_effect()
    _hide_execute_warning()

# --- Copied View Logic ---

func _show_execute_warning():
    var enemy_data = enemy.enemy_data if enemy and enemy.get("enemy_data") else {}
    if not _execute_indicator:
        _execute_indicator = Label.new()
        _execute_indicator.name = "ExecuteIndicator"
        _execute_indicator.text = "☠"
        _execute_indicator.add_theme_font_size_override("font_size", 24)
        _execute_indicator.add_theme_color_override("font_color", Color(0.75, 0.22, 0.17))
        _execute_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
        _execute_indicator.add_theme_constant_override("outline_size", 3)
        _execute_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _execute_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        _execute_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_execute_indicator)

    var radius = enemy_data.get("radius", 20.0)
    _execute_indicator.position = Vector2(-15, -radius - 55)
    _execute_indicator.size = Vector2(30, 30)
    _execute_indicator.visible = true

    if not _execute_border:
        _execute_border = ColorRect.new()
        _execute_border.name = "ExecuteBorder"
        _execute_border.color = Color(0.75, 0.22, 0.17, 0.5)
        _execute_border.size = Vector2(60, 60)
        _execute_border.position = Vector2(-30, -30)
        _execute_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_execute_border)
        _execute_border.z_index = -2

    if not _execute_border.has_meta("pulsing"):
        _execute_border.set_meta("pulsing", true)
        var tween = create_tween().set_loops()
        tween.tween_property(_execute_border, "color:a", 0.8, 0.5)
        tween.tween_property(_execute_border, "color:a", 0.3, 0.5)

func _hide_execute_warning():
    if _execute_indicator and is_instance_valid(_execute_indicator):
        _execute_indicator.visible = false
    if _execute_border and is_instance_valid(_execute_border):
        _execute_border.queue_free()
        _execute_border = null

func _show_max_bleed_effect(delta: float):
    if not _max_bleed_glow:
        _max_bleed_glow = ColorRect.new()
        _max_bleed_glow.name = "MaxBleedGlow"
        _max_bleed_glow.color = Color(0.9, 0.1, 0.1, 0.4)
        _max_bleed_glow.size = Vector2(70, 70)
        _max_bleed_glow.position = Vector2(-35, -35)
        _max_bleed_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_max_bleed_glow)
        _max_bleed_glow.z_index = -1

        var tween = create_tween().set_loops()
        tween.tween_property(_max_bleed_glow, "color:a", 0.7, 0.4)
        tween.tween_property(_max_bleed_glow, "color:a", 0.3, 0.4)

    _max_bleed_particles_timer -= delta
    if _max_bleed_particles_timer <= 0:
        _max_bleed_particles_timer = MAX_BLEED_PARTICLE_INTERVAL
        _spawn_bleed_particle()

func _spawn_bleed_particle():
    var particle = Node2D.new()
    particle.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))

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

    if get_parent() and get_parent().get_parent():
        get_parent().get_parent().add_child(particle)

    var fall_distance = randf_range(30, 60)
    var tween = particle.create_tween()
    tween.tween_property(particle, "global_position:y", particle.global_position.y + fall_distance, 0.5)
    tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.5)
    tween.tween_callback(particle.queue_free)

func _clear_max_bleed_effect():
    if _max_bleed_glow and is_instance_valid(_max_bleed_glow):
        _max_bleed_glow.queue_free()
        _max_bleed_glow = null
