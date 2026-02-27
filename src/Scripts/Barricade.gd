extends Area2D

var type: String
var props: Dictionary

@onready var collision_shape = $CollisionShape2D
# @onready var line_2d = $Line2D # Deprecated
var visual_rect: ColorRect = null

var trap_timer: float = 0.0
var is_triggered: bool = false
var flash_timer: float = 0.0

# Signal for trap trigger - used by LureSnake
signal trap_triggered(enemy: Node2D, trap_position: Vector2)

func init(grid_pos: Vector2i, type_key: String):
	type = type_key
	if Constants.BARRICADE_TYPES.has(type_key):
		props = Constants.BARRICADE_TYPES[type_key]

		var tile_size = Constants.TILE_SIZE
		var offset = Vector2(-tile_size/2.0, -tile_size/2.0)

		# Setup Visuals
		var label = Label.new()
		label.text = props.get("icon", "?")
		label.add_theme_font_size_override("font_size", 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(tile_size, tile_size)
		label.position = offset
		add_child(label)

		# Hide Line2D if it exists
		if has_node("Line2D"):
			$Line2D.visible = false

		# Setup Physics
		var rect = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		collision_shape.shape = rect

		# Collision Settings
		# Detect Enemies (Layer 2)
		collision_layer = 4 # Trap Layer
		collision_mask = 2 # Enemy Layer
		monitoring = true
		monitorable = true

		body_entered.connect(_on_body_entered)

		# Snowball Trap Logic: Start Timer
		if props.get("type") == "trap_freeze":
			trap_timer = 3.0
			GameManager.spawn_floating_text(global_position, "3...", Color.WHITE)

	else:
		push_error("Invalid barricade type: " + type_key)

func _process(delta):
	if !props: return

	# Continuous Effect Application (moved from Enemy.check_traps)
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.has_method("handle_environmental_impact"):
			body.handle_environmental_impact(self)

	# Snowball Trap Logic
	if props.get("type") == "trap_freeze" and !is_triggered:
		trap_timer -= delta
		flash_timer += delta

		# Visual Feedback: Flashing
		# Frequency increases as timer decreases
		var frequency = 5.0 + (3.0 - trap_timer) * 5.0
		var alpha = 0.5 + 0.5 * sin(flash_timer * frequency)
		modulate.a = alpha

		if trap_timer <= 0:
			trigger_freeze_explosion()

func trigger_freeze_explosion():
	is_triggered = true
	GameManager.spawn_floating_text(global_position, "Freeze!", Color.CYAN)

	# Visual Effect
	spawn_splash_effect(global_position)

	# Logic: Freeze enemies in 3x3 range
	var center_pos = global_position
	var range_sq = (Constants.TILE_SIZE * 1.5) ** 2

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.global_position.distance_squared_to(center_pos) <= range_sq:
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(2.0)
			elif enemy.has_method("apply_stun"):
				enemy.apply_stun(2.0)

	if GameManager.grid_manager:
		GameManager.grid_manager.remove_obstacle(self)
	queue_free()

func spawn_splash_effect(pos: Vector2):
	var color = props.get("color", Color.WHITE)
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	get_parent().add_child(effect)
	effect.global_position = pos
	effect.configure("cross", color)
	effect.scale = Vector2(2, 2)
	effect.play()

func _on_body_entered(body):
	# Emit signal for any enemy entering trap - used by LureSnake
	if body.is_in_group("enemies"):
		emit_signal("trap_triggered", body, global_position)

	if props.get("type") == "reflect":
		if body.has_method("handle_environmental_impact"):
			body.handle_environmental_impact(self)
