class_name TauntBehavior
extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var taunt_radius: float = 120.0
var taunt_interval: float = 6.0
var taunt_duration: float = 2.5
var taunt_timer: float = 0.0

func on_tick(delta: float):
	super.on_tick(delta)

	taunt_timer -= delta
	if taunt_timer <= 0:
		taunt_timer = taunt_interval
		_trigger_taunt()

func _trigger_taunt():
	# Use AggroManager to apply taunt
	# Assuming AggroManager is available as Autoload or global class
	AggroManager.apply_taunt(unit, taunt_radius, taunt_duration)
	# Emit signal for test logging
	GameManager.taunt_applied.emit(unit, taunt_radius, taunt_duration)
	_play_taunt_effect()

func _play_taunt_effect():
	# Visual feedback for taunt activation
	if unit:
		GameManager.spawn_floating_text(unit.global_position, "TAUNT!", Color.RED)
		_spawn_taunt_circle()

func _spawn_taunt_circle():
	var line = Line2D.new()
	var points = []
	var steps = 32
	for i in range(steps + 1):
		var angle = TAU * i / steps
		points.append(Vector2(cos(angle), sin(angle)) * taunt_radius)

	line.points = points
	line.width = 2.0
	line.default_color = Color(1, 0.5, 0, 0.5) # Orange
	line.closed = true
	line.name = "TauntCircleVisual"

	unit.add_child(line)

	var tween = unit.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, taunt_duration)
	tween.tween_callback(line.queue_free)
