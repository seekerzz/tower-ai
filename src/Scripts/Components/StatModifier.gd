class_name StatModifier
extends RefCounted

enum Type {
	FLAT,
	PERCENT
}

var type: int
var value: float
var duration: float
var source_id: String
var _initial_duration: float

func _init(_type: int, _value: float, _duration: float = 0.0, _source_id: String = ""):
	self.type = _type
	self.value = _value
	self.duration = _duration
	self._initial_duration = _duration
	self.source_id = _source_id

func is_permanent() -> bool:
	return is_zero_approx(_initial_duration) or _initial_duration < 0.0

func is_expired() -> bool:
	if is_permanent():
		return false
	return duration <= 0.0

func tick(delta: float) -> void:
	if not is_permanent():
		duration -= delta
		if duration < 0.0:
			duration = 0.0
