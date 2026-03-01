extends Node

var is_gui_mode: bool = true
var _screenshot_dir: String = "logs/screenshots"
var _last_damage_screenshot_time: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Check if running in headless mode
	var args = OS.get_cmdline_args()
	if "--headless" in args:
		is_gui_mode = false
		return

	# Ensure directory exists
	var dir = DirAccess.open("res://") if OS.has_feature("editor") else DirAccess.open("user://")
	# When testing, we might want to just dump to local relative directory
	var abs_dir = ProjectSettings.globalize_path("res://" + _screenshot_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	if GameManager:
		GameManager.wave_started.connect(_on_wave_started)
		GameManager.wave_ended.connect(_on_wave_ended)
		GameManager.game_over.connect(_on_game_over)
		GameManager.damage_dealt.connect(_on_damage_dealt)

func _on_wave_started():
	if not is_gui_mode: return
	_take_screenshot("wave_started")

	# 战斗进行 5 秒钟时，需要受 time_scale 影响
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_on_wave_5_seconds)

func _on_wave_5_seconds():
	if not is_gui_mode: return
	if GameManager.is_wave_active:
		_take_screenshot("wave_5_seconds_combat")

func _on_wave_ended():
	if not is_gui_mode: return
	_take_screenshot("wave_ended")

func _on_game_over():
	if not is_gui_mode: return
	_take_screenshot("game_over")

func _on_damage_dealt(unit, amount):
	if not is_gui_mode: return
	# Only capture core damage
	if unit == null and amount > 0:
		var current_time = Time.get_unix_time_from_system()
		# 防抖 1 秒
		if current_time - _last_damage_screenshot_time >= 1.0:
			_last_damage_screenshot_time = current_time
			_take_screenshot("core_damaged")

func _take_screenshot(event_name: String):
	# Delay screenshot by 1 frame to ensure rendering is complete
	call_deferred("_deferred_take_screenshot", event_name)

func _deferred_take_screenshot(event_name: String):
	var viewport = get_viewport()
	if not viewport: return

	var texture = viewport.get_texture()
	if not texture: return

	var image = texture.get_image()
	if image:
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		var filename = "%s_%s.png" % [timestamp, event_name]
		var filepath = ProjectSettings.globalize_path("res://" + _screenshot_dir + "/" + filename)
		image.save_png(filepath)
		print("[ScreenshotManager] Saved screenshot to %s" % filepath)
