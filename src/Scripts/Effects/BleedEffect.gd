extends "res://src/Scripts/Effects/StatusEffect.gd"

var stack_count: int = 0

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)
	type_key = "bleed"
	# Initialize stack_count
	stack_count = 1

func stack(params: Dictionary):
	# Update base class stacks and duration
	super.stack(params)

	# Logic specifically requested
	stack_count += 1
	# Duration refresh is handled by super.stack(params) if params contains "duration"
