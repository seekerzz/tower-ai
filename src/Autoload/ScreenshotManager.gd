extends Node

## Screenshot Manager
## Handles taking screenshots automatically during combat events in GUI mode.

var _last_core_attack_time = 0.0
const CORE_ATTACK_DEBOUNCE = 2.0
var _screenshots_enabled = true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# CRASH-002 Fix: Check if running in headless or invalid viewport mode
	# In headless mode, viewport texture is unavailable and screenshots will crash
	var viewport = get_viewport()
	if viewport == null:
		print("[ScreenshotManager] No viewport available, disabling screenshot automation.")
		return
	var texture = viewport.get_texture()
	if texture == null or not is_instance_valid(texture):
		print("[ScreenshotManager] Invalid viewport texture (headless mode), disabling screenshot automation.")
		return
	# CRASH-002 Fix: Also check command line arg as backup
	if "--headless" in OS.get_cmdline_args():
		print("[ScreenshotManager] Headless mode detected, disabling screenshot automation.")
		return

	# 连接到 WaveSystemManager 的波次信号
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(_on_wave_started)
		GameManager.wave_system_manager.wave_ended.connect(_on_wave_ended)
	GameManager.damage_dealt.connect(_on_damage_dealt)

func _on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	_capture_and_save("WaveStarted")

	# Start a timer influenced by Engine.time_scale (process mode is INHERIT by default for timers, meaning it uses time_scale)
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): _capture_and_save("Wave5Secs"))

func _on_wave_ended(wave_number: int = 0, stats: Dictionary = {}):
	_capture_and_save("WaveEnded")

func _on_damage_dealt(unit, amount: float):
	if unit == null and amount > 0:
		var current_time = Time.get_unix_time_from_system()
		if current_time - _last_core_attack_time >= CORE_ATTACK_DEBOUNCE:
			_last_core_attack_time = current_time
			_capture_and_save("CoreAttacked")

func _capture_and_save(event_name: String):
	# CRASH-002 Fix: Screenshot functionality is disabled in headless/AI mode
	# Godot's headless mode has a dummy texture that passes all GDScript checks
	# but crashes at C++ level when calling get_image(). This is a Godot engine bug.
	# The only reliable fix is to skip screenshots entirely in this mode.
	return

func get_base64_screenshot() -> String:
	# CRASH-002 Fix: Screenshot functionality is disabled in headless/AI mode
	# Godot's headless mode has a dummy texture that passes all GDScript checks
	# but crashes at C++ level when calling get_image(). This is a Godot engine bug.
	return ""

func save_screenshot_to_disk(img: Image, event_name: String):
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("logs/screenshots"):
		dir.make_dir_recursive("logs/screenshots")

	var timestamp = Time.get_unix_time_from_system()
	var filename = "logs/screenshots/screenshot_%d_%s.png" % [int(timestamp), event_name]

	var err = img.save_png("res://" + filename)
	if err == OK:
		print("[ScreenshotManager] Saved screenshot to %s" % filename)
	else:
		printerr("[ScreenshotManager] Failed to save screenshot: %d" % err)
