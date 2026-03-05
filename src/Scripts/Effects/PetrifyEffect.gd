extends Node2D
class_name PetrifyEffect

func _ready():
	var particles = CPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.6
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 25
	particles.direction = Vector2.UP
	particles.spread = 45
	particles.gravity = Vector2(0, -50)
	particles.initial_velocity_min = 30
	particles.initial_velocity_max = 60
	particles.scale_amount_min = 2
	particles.scale_amount_max = 5
	particles.color = Color(0.6, 0.6, 0.6, 1.0)
	add_child(particles)
	particles.emitting = true

	await get_tree().create_timer(0.8).timeout
	queue_free()
