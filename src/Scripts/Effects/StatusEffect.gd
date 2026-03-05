extends Node
class_name StatusEffect

# Properties
var duration: float = 0.0
var stacks: int = 1
var source_unit: Object = null
var type_key: String = ""

# Virtual Methods
func setup(target: Node, source: Object, params: Dictionary):
	# Initialize effect
	source_unit = source
	if params.has("duration"):
		duration = params.duration
	if params.has("stacks"):
		stacks = params.stacks

	# Connect to host death if needed
	if target.has_signal("died"):
		if not target.died.is_connected(_on_host_died):
			target.died.connect(_on_host_died)
	elif target.has_signal("tree_exiting"):
		# Fallback if no specific died signal, but strictly speaking tree_exiting handles all removal
		# However, for "Death Rattle" we specifically want death, not just unloading.
		# Enemy.gd usually calls queue_free() on death.
		pass

func apply(delta: float):
	# Called every frame
	duration -= delta
	if duration <= 0:
		queue_free()

func stack(params: Dictionary):
	# Called when applying same effect again
	if params.has("duration"):
		duration = max(duration, params.duration) # Refresh duration
	if params.has("stacks"):
		stacks += params.stacks

func _on_host_died():
	# Override for death rattle
	pass

func _process(delta):
	apply(delta)
