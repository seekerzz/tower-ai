extends Node

## Screenshot Manager
## Handles taking screenshots automatically during combat events in GUI mode.

var _last_core_attack_time = 0.0
const CORE_ATTACK_DEBOUNCE = 2.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	if "--headless" in OS.get_cmdline_args():
		print("[ScreenshotManager] Headless mode detected, disabling screenshot automation.")
		return

	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.damage_dealt.connect(_on_damage_dealt)

func _on_wave_started():
	_capture_and_save("WaveStarted")

	# Start a timer influenced by Engine.time_scale (process mode is INHERIT by default for timers, meaning it uses time_scale)
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): _capture_and_save("Wave5Secs"))

func _on_wave_ended():
	_capture_and_save("WaveEnded")

func _on_damage_dealt(unit, amount: float):
	if unit == null and amount > 0:
		var current_time = Time.get_unix_time_from_system()
		if current_time - _last_core_attack_time >= CORE_ATTACK_DEBOUNCE:
			_last_core_attack_time = current_time
			_capture_and_save("CoreAttacked")

func _capture_and_save(event_name: String):
	# Wait until end of frame to ensure rendering is done before taking screenshot
	await get_tree().process_frame
	await get_tree().process_frame

	var img = get_viewport().get_texture().get_image()
	if img:
		save_screenshot_to_disk(img, event_name)

func get_base64_screenshot() -> String:
	# Requires waiting a frame in practice, but API definition returns empty/blocking string if called sync
	# Typically agents would call this async
	var img = get_viewport().get_texture().get_image()
	if img:
		var buffer = img.save_png_to_buffer()
		return Marshalls.raw_to_base64(buffer)
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
