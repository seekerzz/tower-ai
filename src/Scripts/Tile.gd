extends Node2D

var x: int
var y: int
var type: String = "normal"
var state: String = "locked_inner" # unlocked, locked_inner, locked_outer, spawn
var unit = null
var occupied_by: Vector2i
var random_frame_index: int = 0

signal tile_clicked(tile)

const DROP_HANDLER_SCRIPT = preload("res://src/Scripts/UI/TileDropHandler.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")
var TEXTURE_SHEET = null
var TEXTURE_SPAWN = null

func _init():
	if ResourceLoader.exists("res://assets/images/UI/tile_sheet.png"):
		TEXTURE_SHEET = load("res://assets/images/UI/tile_sheet.png")
	if ResourceLoader.exists("res://assets/images/UI/tile_spawn.png"):
		TEXTURE_SPAWN = load("res://assets/images/UI/tile_spawn.png")

func setup(grid_x: int, grid_y: int, tile_type: String = "normal"):
	x = grid_x
	y = grid_y
	type = tile_type

	random_frame_index = randi() % 25

	if has_node("BaseSprite"):
		var bs = $BaseSprite
		bs.hframes = 5
		bs.vframes = 5

	# Cleanup old nodes if they exist
	if has_node("ColorRect"): $ColorRect.queue_free()
	if has_node("VisualPanel"): $VisualPanel.queue_free()

	if !has_node("CoreSprite"):
		var cs = Sprite2D.new()
		cs.name = "CoreSprite"
		add_child(cs)

	update_visuals()

	# Add Drop Target
	var drop_target = Control.new()
	drop_target.set_script(DROP_HANDLER_SCRIPT)
	add_child(drop_target)
	drop_target.setup(self)

func set_state(new_state: String):
	state = new_state
	update_visuals()

func _adjust_sprite_scale(sprite: Sprite2D, target_size: float):
	if sprite.texture:
		var frame_width = sprite.texture.get_width() / sprite.hframes
		var scale_factor = target_size / max(frame_width, 1.0)
		sprite.scale = Vector2(scale_factor, scale_factor)

func update_visuals():
	var bs = get_node_or_null("BaseSprite")
	if !bs: return

	bs.visible = true
	bs.modulate = Color.WHITE

	var cs = get_node_or_null("CoreSprite")
	if cs: cs.visible = false

	if state == "spawn":
		if TEXTURE_SPAWN:
			bs.texture = TEXTURE_SPAWN
		bs.hframes = 5
		bs.vframes = 5
		bs.frame = random_frame_index
		_adjust_sprite_scale(bs, 60.0)

	elif state == "unlocked" or type == "core":
		if TEXTURE_SHEET:
			bs.texture = TEXTURE_SHEET
		bs.hframes = 5
		bs.vframes = 5
		bs.frame = random_frame_index
		_adjust_sprite_scale(bs, 60.0)

	elif "locked" in state:
		bs.visible = false
		bs.texture = null

	if type == "core":
		var core_key = GameManager.core_type
		var icon = AssetLoader.get_core_icon(core_key)

		if icon:
			if cs:
				cs.visible = true
				cs.texture = icon
				cs.hframes = 1
				cs.vframes = 1
				_adjust_sprite_scale(cs, 60.0)
			if has_node("Label"):
				$Label.visible = false
		else:
			if has_node("Label"):
				$Label.visible = true
				var core_name = "Core"
				if GameManager.data_manager and GameManager.data_manager.data.has("CORE_TYPES") and GameManager.data_manager.data["CORE_TYPES"].has(core_key):
					core_name = GameManager.data_manager.data["CORE_TYPES"][core_key].get("name", "Core")
				$Label.text = core_name
	else:
		if has_node("Label"):
			$Label.text = ""
			$Label.visible = true

func set_grid_visible(visible_state: bool):
	var b = get_node_or_null("Border")
	if b:
		b.visible = visible_state

func set_highlight(active: bool):
	var bs = get_node_or_null("BaseSprite")
	if !bs: return

	if active:
		bs.modulate = Color(1.2, 1.2, 1.2)
	else:
		bs.modulate = Color.WHITE

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(self)

func _on_area_2d_mouse_entered():
	if !GameManager.is_wave_active:
		set_highlight(true)

func _on_area_2d_mouse_exited():
	set_highlight(false)
