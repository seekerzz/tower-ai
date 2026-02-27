class_name EnemyBehavior
extends Node

var enemy: CharacterBody2D
var data: Dictionary

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	enemy = enemy_node
	data = enemy_data

func physics_process(delta: float) -> bool:
	# Returns true if the behavior handled movement/physics entirely
	return false

func update_attack(delta: float):
	pass

func cancel_attack():
	pass

func on_hit(damage_info: Dictionary) -> bool:
	# Returns true if the hit was intercepted/handled (e.g. split) and should stop default processing
	return false

func on_death(killer_unit) -> bool:
	# Returns true if death was handled (e.g. special animation that delays queue_free)
	return false
