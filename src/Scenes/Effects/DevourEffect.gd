class_name DevourEffect
extends Node2D

@onready var particles: CPUParticles2D = $CPUParticles2D
var tween: Tween

func _ready():
	# Red vortex effect
	particles.amount = 30
	particles.lifetime = 0.8
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10
	particles.orbit_velocity_min = 2.0
	particles.orbit_velocity_max = 3.0
	particles.scale_amount_min = 3
	particles.scale_amount_max = 6
	particles.color = Color.DARK_RED
	particles.one_shot = true
	particles.emitting = true

	# Scale up then disappear
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.5)
	tween.tween_callback(queue_free)
