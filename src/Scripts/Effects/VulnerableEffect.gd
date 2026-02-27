extends Node

var duration: float = 0.0
var stacks: int = 0
var target: Node2D

func setup(t, _source, params):
	target = t
	stack(params)

func stack(params):
	duration = max(duration, params.get("duration", 0.0))
	stacks = min(stacks + params.get("stacks", 1), 5)

func _process(delta):
	duration -= delta
	if duration <= 0:
		queue_free()

func get_damage_multiplier() -> float:
	return 1.0 + (stacks * 0.1) # 10% bonus per stack
