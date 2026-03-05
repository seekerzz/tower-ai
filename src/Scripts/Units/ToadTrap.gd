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

		# 添加详细日志：记录陷阱触发信息
		var owner_name = owner_toad.type_key if owner_toad and owner_toad.has_method("get") and owner_toad.get("type_key") else "unknown"
		var body_name = body.name if body.has_method("get") and body.get("name") else body.name
		var body_type = body.type_key if body.has_method("get") and body.get("type_key") else "unknown"
		print("[ToadTrap] 陷阱被触发! 陷阱位置: %s, 拥有者: %s, 触发目标: %s (类型:%s)" % [
			str(global_position),
			owner_name,
			body_name,
			body_type
		])

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
