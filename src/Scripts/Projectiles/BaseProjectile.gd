extends Area2D

var speed: float = 400.0
var damage: float = 10.0
var payload_effects: Array = [] # Array of { "script": Script, "params": Dictionary }
var source_unit: Object = null # Relaxed from Node to Object to support RefCounted sources (e.g. MeteorSource)

func _ready():
	# Ensure signals are connected if not already
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_2d_area_entered):
		area_entered.connect(_on_area_2d_area_entered)

	# Add Layer 10 (Petrified Enemies) to collision mask
	set_collision_mask_value(10, true)

func _process(delta):
	# Default simple movement: Move right based on rotation
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_body_entered(body):
	_handle_hit(body)

func _on_area_2d_area_entered(area):
	_handle_hit(area)

func _handle_hit(target):
	# Virtual method to be overridden
	pass

func apply_payload(target):
	if target.has_method("apply_status"):
		for effect_data in payload_effects:
			# Ensure source is set in params if not present
			var params = effect_data.params.duplicate()
			if not params.has("source"):
				params["source"] = source_unit

			target.apply_status(effect_data.script, params)
