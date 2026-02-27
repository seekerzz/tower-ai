extends Node2D

var _scaled_size: Vector2 = Vector2.ZERO
var impact_tween: Tween
var flexibility: float = 0.5 # Low for trees

func _ready():
	GameManager.world_impact.connect(_on_world_impact)

func _on_world_impact(direction: Vector2, strength: float):
	if impact_tween and impact_tween.is_valid():
		impact_tween.kill()

	# Skip shader effects in headless mode
	if Engine.is_editor_hint() or OS.has_feature("headless"):
		return

	impact_tween = create_tween()

	# Phase 1: Quick Impact
	# Trees are stiff, less sway
	var target_offset = direction * strength * flexibility

	impact_tween.tween_method(
		func(val): $Sprite2D.set_instance_shader_parameter("impact_offset", val),
		Vector2.ZERO,
		target_offset,
		0.15
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Phase 2: Recovery (Slower/Heavier for trees)
	impact_tween.tween_method(
		func(val): $Sprite2D.set_instance_shader_parameter("impact_offset", val),
		target_offset,
		Vector2.ZERO,
		2.0
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func setup(width_in_tiles: int):
	# Apply EnvironmentDecoration Material to allow shader effects if not present
	# We load the shader resource manually to ensure it matches
	# Skip shader setup in headless mode - instance uniforms are not supported in headless
	# Check RenderingServer to detect headless mode
	var is_headless = RenderingServer.get_rendering_device() == null
	if is_headless or OS.has_feature("headless"):
		_setup_texture_only(width_in_tiles)
		return

	var shader = load("res://src/Shaders/EnvironmentDecoration.gdshader")
	if shader and not $Sprite2D.material:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		$Sprite2D.material = mat

		# Set defaults
		mat.set_shader_parameter("sway_intensity", 3.0) # Less sway for trees
		mat.set_shader_parameter("sway_speed", 0.5)
		# Initialize instance uniforms - only if not in headless mode
		# Note: instance uniforms are not supported in headless mode (dummy renderer)
		if RenderingServer.get_rendering_device() != null:
			$Sprite2D.set_instance_shader_parameter("impact_offset", Vector2.ZERO)
			$Sprite2D.set_instance_shader_parameter("sway_phase", randf() * 6.28)
			$Sprite2D.set_instance_shader_parameter("global_scale", Vector2.ONE)


	var config = Constants.ENVIRONMENT_CONFIG
	var texture_path = config["tree_tile_set"]
	var columns = config["tree_columns"]

	# Load texture
	if not ResourceLoader.exists(texture_path):
		# print("Error: Tree texture not found: ", texture_path)
		return

	var texture = load(texture_path)
	$Sprite2D.texture = texture

	var texture_width = texture.get_width()
	var texture_height = texture.get_height()

	# Handle division by zero if texture is invalid or columns is 0
	if columns <= 0:
		columns = 1
	var frame_width = texture_width / float(columns)
	if frame_width == 0:
		frame_width = 1.0

	var rows = config.get("tree_rows", 1)
	if rows <= 0: rows = 1
	var frame_height = texture_height / float(rows)

	# Set up sprite frame
	$Sprite2D.hframes = columns
	$Sprite2D.vframes = rows
	$Sprite2D.frame = randi() % columns

	# Calculate Scale
	# base_scale = (Constants.TILE_SIZE * width_in_tiles) / (texture_width / columns)
	var base_scale = (Constants.TILE_SIZE * width_in_tiles) / frame_width
	var final_scale = base_scale * randf_range(0.9, 1.0)

	scale = Vector2(final_scale, final_scale)

	# Calculate and store actual pixel size
	_scaled_size = Vector2(frame_width * final_scale, frame_height * final_scale)

	# Alignment
	# Sprite2D bottom aligned to origin.
	# If centered=true (default), origin is center of sprite.
	# We want bottom of sprite at (0,0) of the Tree node.
	# The height of the sprite is texture_height / rows

	# Move sprite up by half its height so its bottom is at 0
	$Sprite2D.position.y = -frame_height / 2.0

	# Random flip
	if randf() > 0.5:
		$Sprite2D.flip_h = true

	update_z_index()

func _setup_texture_only(width_in_tiles: int):
	"""Setup only texture without shader - for headless mode"""
	var config = Constants.ENVIRONMENT_CONFIG
	var texture_path = config["tree_tile_set"]
	var columns = config["tree_columns"]

	# Load texture
	if not ResourceLoader.exists(texture_path):
		return

	var texture = load(texture_path)
	$Sprite2D.texture = texture

	var texture_width = texture.get_width()
	var texture_height = texture.get_height()

	# Handle division by zero if texture is invalid or columns is 0
	if columns <= 0:
		columns = 1
	var frame_width = texture_width / float(columns)
	if frame_width == 0:
		frame_width = 1.0

	var rows = config.get("tree_rows", 1)
	if rows <= 0: rows = 1
	var frame_height = texture_height / float(rows)

	# Set up sprite frame
	$Sprite2D.hframes = columns
	$Sprite2D.vframes = rows
	$Sprite2D.frame = randi() % columns

	# Calculate Scale
	var base_scale = (Constants.TILE_SIZE * width_in_tiles) / frame_width
	var final_scale = base_scale * randf_range(0.9, 1.0)

	scale = Vector2(final_scale, final_scale)

	# Calculate and store actual pixel size
	_scaled_size = Vector2(frame_width * final_scale, frame_height * final_scale)

	# Move sprite up by half its height so its bottom is at 0
	$Sprite2D.position.y = -frame_height / 2.0

	# Random flip
	if randf() > 0.5:
		$Sprite2D.flip_h = true

	update_z_index()

func get_pixel_size() -> Vector2:
	return _scaled_size

func update_z_index():
	# Visual intent: "Visual position lower (bottom of screen) occludes position upper (top of screen)"
	# In Godot (Y-Down): Bottom is Large Y. Top is Small Y.
	# So Large Y should have Higher Z-Index.
	# The prompt requested "Inverse Logic" (Small Y -> Large Z) likely assuming Y-Up coordinates.
	# To achieve the correct visual result in Godot, we use Standard Logic (Large Y -> Large Z).
	z_index = int(global_position.y)
