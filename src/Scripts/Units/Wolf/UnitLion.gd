class_name UnitLion
extends Unit

var shockwave_radius: float = 0.0
var shockwave_timer: float = 0.0

func _ready():
    super._ready()

func _process_combat(delta):
    if cooldown > 0:
        cooldown -= delta
        return

    if GameManager.combat_manager:
        var enemy = GameManager.combat_manager.find_nearest_enemy(global_position, range_val)
        if enemy:
            _perform_attack()
            cooldown = atk_speed * GameManager.get_stat_modifier("attack_interval")

func _perform_attack():
    var shockwave_scene = load("res://src/Scenes/Effects/Shockwave.tscn")
    if shockwave_scene:
        var shockwave = shockwave_scene.instantiate()
        shockwave.global_position = global_position
        shockwave.damage = damage
        shockwave.radius = range_val
        get_tree().current_scene.add_child(shockwave)
    else:
        _fallback_shockwave()

    if visual_holder:
        var tween = create_tween()
        tween.tween_property(visual_holder, "scale", Vector2(1.5, 1.5), 0.1)
        tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)

func _fallback_shockwave():
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if global_position.distance_to(enemy.global_position) <= range_val:
            enemy.take_damage(damage, self, "physical")

    shockwave_radius = 0.0
    shockwave_timer = 0.3
    queue_redraw()

func _process(delta):
    super._process(delta)
    if shockwave_timer > 0:
        shockwave_timer -= delta
        shockwave_radius = range_val * (1.0 - (shockwave_timer / 0.3))
        queue_redraw()
        if shockwave_timer <= 0:
            shockwave_radius = 0.0
            queue_redraw()

func _draw():
    super._draw()
    if shockwave_radius > 0:
        draw_circle(Vector2.ZERO, shockwave_radius, Color(1, 0.5, 0, 0.3))
        draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 32, Color(1, 0.5, 0, 0.8), 2.0)
