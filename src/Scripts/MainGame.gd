extends Node2D

@onready var grid_manager = $GridManager
@onready var combat_manager = $CombatManager
@onready var shop = $CanvasLayer/Shop
@onready var bench_ui = find_child("Bench", true, false)
@onready var main_gui = $CanvasLayer/MainGUI
@onready var camera = $Camera2D
@onready var background = $Background


# Camera Control
var zoom_target: Vector2 = Vector2(0.8, 0.8)
var zoom_tween: Tween
var default_zoom: Vector2 = Vector2(0.8, 0.8)
var default_position: Vector2 = Vector2(640, 400)
var min_allowed_zoom: Vector2 = Vector2(0.5, 0.5)

var shake_offset: Vector2 = Vector2.ZERO
var noise_shake_strength: float = 0.0

var summon_manager: Node

func _ready():
	# Initialize SummonManager
	var SummonManagerScript = load("res://src/Scripts/Managers/SummonManager.gd")
	summon_manager = SummonManagerScript.new()
	summon_manager.name = "SummonManager"
	add_child(summon_manager)
	GameManager.summon_manager = summon_manager

	GameManager.ui_manager = main_gui
	GameManager.main_game = self

	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)

	# 连接 BoardController 信号
	BoardController.unit_moved.connect(_on_unit_moved)
	BoardController.unit_sold.connect(_on_unit_sold)

	# Camera Setup
	# Calculate min allowed zoom (maximum field of view)
	calculate_min_allowed_zoom()

	setup_background()

	# Initial camera position will be set by zoom_to_fit_board later or we call it now to verify
	call_deferred("zoom_to_shop_open")

	# 连接 SessionData 信号以更新 Bench UI
	if GameManager.session_data:
		GameManager.session_data.bench_updated.connect(_on_bench_updated)

	# Initial Setup - 开局不再赠送松鼠，玩家需自行购买
	if bench_ui:
		bench_ui.refresh_from_session_data()

	get_tree().root.size_changed.connect(_on_viewport_size_changed)

	# 通知 AI 客户端场景加载完成
	if AIManager and AIManager.is_ai_connected():
		print("[MainGame] 场景加载完成，发送 TotemSelected 给 AI")
		AIManager._send_state_async("TotemSelected", {"totem_id": GameManager.core_type})

	if GameManager.is_running_test:
		call_deferred("_attach_test_runner")

func _attach_test_runner():
	# 运行 BoardController 测试
	var test_script = load("res://src/Scripts/Tests/BoardControllerTest.gd")
	if test_script:
		var test_runner = test_script.new()
		add_child(test_runner)
	else:
		printerr("[MainGame] Failed to load BoardControllerTest.gd")

func _on_viewport_size_changed():
	calculate_min_allowed_zoom()
	setup_background()
	_adjust_zoom(0) # Re-clamp zoom

func _process(delta):
	# Apply impulse shake decay
	if shake_offset.length_squared() > 1.0:
		shake_offset = shake_offset.lerp(Vector2.ZERO, 10.0 * delta)
	else:
		shake_offset = Vector2.ZERO

	# Apply noise shake decay
	if noise_shake_strength > 0.0:
		noise_shake_strength = lerp(noise_shake_strength, 0.0, 5.0 * delta)
		if noise_shake_strength < 1.0: noise_shake_strength = 0.0

	var total_shake = shake_offset
	if noise_shake_strength > 0.0:
		total_shake += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * noise_shake_strength

	if camera:
		camera.offset = total_shake

func apply_impulse_shake(direction: Vector2, strength: float):
	shake_offset += direction * strength

func apply_camera_shake(strength: float):
	noise_shake_strength = strength

func setup_background():
	if not background: return
	background.position = grid_manager.position

	# Calculate required scale
	# Viewport size
	var vp_size = get_viewport_rect().size
	var min_zoom = min_allowed_zoom.x # Assuming uniform

	# Max view height in world units
	var view_h = vp_size.y / min_zoom
	var view_w = vp_size.x / min_zoom

	# Calculate offset
	var SHOP_HEIGHT = 180
	var visible_height = vp_size.y - SHOP_HEIGHT
	var screen_center_y = vp_size.y / 2.0
	var visible_center_y = visible_height / 2.0
	var shift_y = screen_center_y - visible_center_y
	var world_shift_y = shift_y / min_zoom

	# The camera view extends from (center + shift) +/- (size / 2)
	# Relative to grid center (0):
	# Top: world_shift_y - view_h / 2
	# Bottom: world_shift_y + view_h / 2

	# We need the background (centered at 0) to cover this.
	# Half-height of background must be > max(abs(Top), abs(Bottom))

	var max_y_dist = max(abs(world_shift_y - view_h/2), abs(world_shift_y + view_h/2))
	var req_h = max_y_dist * 2

	var req_w = view_w # No shift in X usually

	var tex_size = Vector2.ZERO
	if background.texture:
		tex_size = background.texture.get_size()

	if tex_size.x > 0 and tex_size.y > 0:
		var scale_x = req_w / tex_size.x
		var scale_y = req_h / tex_size.y

		var s = max(scale_x, scale_y) * 1.05 # Margin

		background.scale = Vector2(s, s)

func calculate_min_allowed_zoom():
	# Calculate zoom needed to see the battlefield when shop is open
	var map_width = Constants.MAP_WIDTH * Constants.TILE_SIZE
	var map_height = Constants.MAP_HEIGHT * Constants.TILE_SIZE

	var SHOP_HEIGHT = 180
	var viewport_size = get_viewport_rect().size
	var visible_height = viewport_size.y - SHOP_HEIGHT

	var zoom_x = viewport_size.x / (map_width * 1.1) # 10% margin
	var zoom_y = visible_height / (map_height * 1.1)
	var final_zoom = min(zoom_x, zoom_y)

	# Clamp to reasonable values
	final_zoom = clamp(final_zoom, 0.3, 1.0)

	min_allowed_zoom = Vector2(final_zoom, final_zoom)
	# print("Calculated Min Allowed Zoom: ", min_allowed_zoom)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
			camera.position -= event.relative / camera.zoom

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(-0.1)

func _adjust_zoom(amount: float):
	zoom_target += Vector2(amount, amount)

	# Clamp zoom so we don't zoom out more than allowed (min_allowed_zoom)
	zoom_target.x = max(zoom_target.x, min_allowed_zoom.x)
	zoom_target.y = max(zoom_target.y, min_allowed_zoom.y)

	# Max zoom in
	zoom_target.x = min(zoom_target.x, 2.0)
	zoom_target.y = min(zoom_target.y, 2.0)

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.tween_property(camera, "zoom", zoom_target, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func zoom_to_fit_board():
	# Shop Closed (Combat)
	# Recalculate based on full screen
	var map_width = Constants.MAP_WIDTH * Constants.TILE_SIZE
	var map_height = Constants.MAP_HEIGHT * Constants.TILE_SIZE

	var viewport_size = get_viewport_rect().size
	var zoom_x = viewport_size.x / (map_width * 1.05)
	var zoom_y = viewport_size.y / (map_height * 1.05)
	var final_zoom = min(zoom_x, zoom_y)

	# Ensure we respect min allowed zoom (though combat zoom usually is > min allowed)
	final_zoom = max(final_zoom, min_allowed_zoom.x)

	var target_zoom = Vector2(final_zoom, final_zoom)
	var target_pos = grid_manager.position

	zoom_target = target_zoom

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.set_parallel(true)
	zoom_tween.tween_property(camera, "zoom", target_zoom, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom_tween.tween_property(camera, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func zoom_to_shop_open():
	# Shop Open (Planning)
	# This should roughly match min_allowed_zoom logic but setting position correctly

	var target_zoom = min_allowed_zoom
	zoom_target = target_zoom

	# Recalculate position offset for shop
	var viewport_size = get_viewport_rect().size
	var SHOP_HEIGHT = 180
	var visible_height = viewport_size.y - SHOP_HEIGHT

	var screen_center_y = viewport_size.y / 2.0
	var visible_center_y = visible_height / 2.0
	var shift_y = screen_center_y - visible_center_y

	var target_pos = grid_manager.position
	target_pos.y += shift_y / target_zoom.y

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.set_parallel(true)
	zoom_tween.tween_property(camera, "zoom", target_zoom, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom_tween.tween_property(camera, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_wave_started():
	zoom_to_fit_board()

func _on_wave_ended():
	zoom_to_shop_open()

# ===== SessionData 信号处理 =====

func _on_bench_updated(bench_units: Dictionary):
	# SessionData 的 bench_updated 信号回调
	# Bench UI 会自动监听此信号并更新，这里不需要额外操作
	pass

# ===== BoardController 信号处理 =====

func _on_unit_moved(from_zone: String, from_pos: Variant,
					to_zone: String, to_pos: Variant, unit_data: Dictionary):
	# 单位移动后，SessionData 会发射 bench_updated 信号
	# Bench UI 会自动更新，这里不需要手动更新
	pass

func _on_unit_sold(zone: String, pos: Variant, gold_refund: int):
	# 单位出售后，SessionData 会发射 bench_updated 信号
	# Bench UI 会自动更新，这里不需要手动更新
	pass

func skip_wave():
	if not GameManager.is_wave_active:
		return

	# Clear all enemies
	# In headless mode, get_tree() may return Window instead of SceneTree
	# Use Engine.get_main_loop() which should return SceneTree
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.has_method("call_group"):
		main_loop.call_group("enemies", "queue_free")
	else:
		# Fallback: manually find and free enemies
		var enemies = get_tree().get_nodes_in_group("enemies") if get_tree() else []
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.queue_free()

	# Stop spawning
	if combat_manager:
		combat_manager.enemies_to_spawn = 0

	# End wave
	GameManager.end_wave()
