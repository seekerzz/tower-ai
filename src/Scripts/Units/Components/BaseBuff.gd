extends RefCounted
class_name BaseBuff

var type: String
var source: Node2D
var unit: Node2D

func _init(buff_type: String, buff_source: Node2D, buff_unit: Node2D):
	type = buff_type
	source = buff_source
	unit = buff_unit

func on_apply():
	pass

func on_remove():
	pass

func modify_damage_taken(amount: float, source: Node2D) -> float:
	return amount
