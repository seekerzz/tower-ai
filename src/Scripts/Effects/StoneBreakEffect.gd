extends Node2D
class_name StoneBreakEffect

func _ready():
	var particles = CPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.8
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 3
	particles.scale_amount_max = 6
	particles.color = Color(0.5, 0.5, 0.5, 1.0)
	add_child(particles)
	particles.emitting = true
	particles.one_shot = true

	# Play break sound if available, omitted for now

	await get_tree().create_timer(1.0).timeout
	queue_free()
