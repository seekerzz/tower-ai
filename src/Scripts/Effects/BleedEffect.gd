extends "res://src/Scripts/Effects/StatusEffect.gd"

var stack_count: int = 0
const MAX_STACKS = 25  # 流血最大层数从30层降低到25层

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
	# 限制最大层数
	if stack_count > MAX_STACKS:
		stack_count = MAX_STACKS
	if stacks > MAX_STACKS:
		stacks = MAX_STACKS
	# Duration refresh is handled by super.stack(params) if params contains "duration"
