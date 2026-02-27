extends Area2D
class_name ToadTrap

var duration: float = 25.0
var trigger_radius: float = 30.0

var owner_toad: Node
var level: int
var triggered: bool = false

signal trap_triggered(enemy, trap)

func _ready():
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

	body_entered.connect(_on_body_entered)

	# Set collision layer/mask to detect enemies (Layer 2)
	collision_layer = 0
	collision_mask = 2

func _on_body_entered(body):
	if triggered: return
	if body.is_in_group("enemies"):
		triggered = true
		trap_triggered.emit(body, self)
		_play_trigger_effect()
		queue_free()

func _play_trigger_effect():
	GameManager.spawn_floating_text(global_position, "TRAP!", Color.GREEN)
	# Could spawn a splash effect here if needed
	var SlashEffectScript = load("res://src/Scripts/Effects/SlashEffect.gd")
	if SlashEffectScript:
		var slash = SlashEffectScript.new()
		get_parent().add_child(slash)
		slash.global_position = global_position
		slash.configure("blob", Color.GREEN)
		slash.play()
