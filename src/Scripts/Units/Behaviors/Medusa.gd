extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

const PetrifiedStatus = preload("res://src/Scripts/Effects/PetrifiedStatus.gd")
const PetrifyEffectScene = preload("res://src/Scenes/Effects/PetrifyEffect.tscn")

var _petrify_timer: float = 0.0
var _petrify_interval: float = 5.0

func on_setup():
	super.on_setup()
	_petrify_timer = 0.0

func on_combat_tick(delta: float) -> bool:
	if not GameManager.is_wave_active: return true

	_petrify_timer += delta
	if _petrify_timer >= _petrify_interval:
		_petrify_timer = 0
		_cast_petrify_gaze()

	# Return false to allow standard attacks
	return false

func _cast_petrify_gaze():
	var target = _find_nearest_non_petrified_enemy()
	if target and is_instance_valid(target):
		_petrify_enemy(target)

func _find_nearest_non_petrified_enemy() -> Node2D:
	var min_dist = 9999.0
	var nearest = null
	var petrify_range = 150.0

	for enemy in unit.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue

		# Check if already has status
		if enemy.has_method("has_status") and enemy.has_status("petrified"):
			continue

		var dist = unit.global_position.distance_to(enemy.global_position)
		if dist < petrify_range and dist < min_dist:
			min_dist = dist
			nearest = enemy

	return nearest

func _petrify_enemy(enemy: Node2D):
	var duration = 1.0
	if unit.level >= 2:
		duration = 1.5
	if unit.level >= 3:
		duration = 2.0

	# Apply PetrifiedStatus with source reference
	if enemy.has_method("apply_status"):
		enemy.apply_status(PetrifiedStatus, {"duration": duration, "source": unit})

	# Visual feedback
	GameManager.spawn_floating_text(enemy.global_position, "石化!", Color.GRAY)
	_play_petrify_effect(enemy.global_position)

	# Emit signal for test logging
	if GameManager.has_signal("petrify_applied"):
		GameManager.petrify_applied.emit(enemy, duration, unit)

func _play_petrify_effect(pos: Vector2):
	var effect = PetrifyEffectScene.instantiate()
	effect.global_position = pos
	unit.get_tree().current_scene.add_child(effect)
