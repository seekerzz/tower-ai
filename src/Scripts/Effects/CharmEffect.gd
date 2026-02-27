class_name CharmEffect
extends Node2D

var particles: CPUParticles2D

func _ready():
    particles = CPUParticles2D.new()
    particles.amount = 20
    particles.lifetime = 0.5
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    particles.emission_sphere_radius = 20
    particles.direction = Vector2.UP
    particles.spread = 30
    particles.gravity = Vector2.ZERO
    particles.initial_velocity_min = 20
    particles.initial_velocity_max = 40
    particles.scale_amount_min = 2
    particles.scale_amount_max = 4
    particles.color = Color.MAGENTA
    add_child(particles)
    particles.emitting = true

    await get_tree().create_timer(1.0).timeout
    queue_free()
