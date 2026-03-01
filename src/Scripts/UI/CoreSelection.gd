extends Control

const CoreCardScene = preload("res://src/Scenes/UI/CoreCard.tscn")

@onready var container = $ScrollContainer/HBoxContainer

# 可用图腾列表
const AVAILABLE_TOTEMS = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]

func _ready():
	# 连接全局 totem_confirmed 信号
	GameManager.totem_confirmed.connect(_on_totem_confirmed)

	var args = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())

	# 检查是否是AI模式
	var ai_mode = false
	for arg in args:
		if arg == "--ai-mode":
			ai_mode = true
			break

	if ai_mode:
		print("[CoreSelection] AI模式已启用，等待AI选择图腾...")
		call_deferred("_start_ai_mode")
		return

	# 检查测试模式
	for arg in args:
		if arg.begins_with("--run-test="):
			var case_id = arg.split("=")[1]
			call_deferred("_launch_test_mode", case_id)
			return

	_create_cards()

func _on_totem_confirmed(totem_id: String):
	"""监听 totem_confirmed 信号，自动处理场景切换"""
	print("[CoreSelection] 收到 totem_confirmed 信号: " + totem_id)

	# 验证图腾ID
	var core_data = {}
	if GameManager.data_manager and GameManager.data_manager.data.has("CORE_TYPES"):
		core_data = GameManager.data_manager.data["CORE_TYPES"]

	if not core_data.has(totem_id):
		print("[CoreSelection] 错误: 无效的图腾类型 " + totem_id)
		return

	# 恢复游戏（如果处于暂停状态）
	if get_tree().paused:
		get_tree().paused = false
		print("[CoreSelection] 游戏已恢复")

	# 初始化游戏会话
	_initialize_game_session()

	# Load MainGame scene
	var main_game_scene = load("res://src/Scenes/Game/MainGame.tscn")
	if main_game_scene:
		print("[CoreSelection] 正在切换到MainGame场景...")
		call_deferred("_change_to_main_game", main_game_scene)
	else:
		print("[CoreSelection] 错误: MainGame场景未找到!")

func _start_ai_mode():
	"""启动AI模式：暂停游戏，等待AI连接并选择图腾"""
	# 暂停游戏
	get_tree().paused = true

	# 等待AIManager就绪
	while not AIManager:
		await get_tree().create_timer(0.1).timeout

	print("[CoreSelection] AIManager已就绪，等待AI客户端连接...")

	# 等待AI客户端连接
	var timeout = 60.0
	var elapsed = 0.0
	while elapsed < timeout:
		if AIManager.is_ai_connected():
			print("[CoreSelection] AI客户端已连接，发送图腾选项...")
			_send_totem_selection_to_ai()
			return
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5

	print("[CoreSelection] 等待AI连接超时，切换到手动选择模式")
	get_tree().paused = false
	_create_cards()

func _send_totem_selection_to_ai():
	"""发送图腾选择状态给AI客户端"""
	var totem_info = _get_totem_info()
	var info_text = ""
	for totem_id in totem_info:
		info_text += "\n- %s (%s): %s" % [totem_info[totem_id]["name"], totem_id, totem_info[totem_id]["description"]]

	var message = "【图腾选择】请选择你的图腾。可用图腾包括：%s" % info_text
	AIManager.broadcast_text(message)
	print("[CoreSelection] 图腾选项已发送，等待AI选择...")

func _get_totem_info() -> Dictionary:
	"""获取图腾信息"""
	var info = {}
	if GameManager.data_manager and GameManager.data_manager.data.has("CORE_TYPES"):
		var core_data = GameManager.data_manager.data["CORE_TYPES"]
		for totem_id in AVAILABLE_TOTEMS:
			if core_data.has(totem_id):
				info[totem_id] = {
					"name": core_data[totem_id].get("name", totem_id),
					"description": core_data[totem_id].get("description", "")
				}
	return info

func _launch_test_mode(case_id: String):
	print("[Test] Launching: ", case_id)

	var suite_script = load("res://src/Scripts/Tests/TestSuite.gd")
	if !suite_script:
		printerr("[Test] Failed to load TestSuite.gd")
		return

	var suite = suite_script.new()
	var config = suite.get_test_config(case_id)

	if config.is_empty():
		printerr("[Test] Unknown test case: ", case_id)
		get_tree().quit()
		return

	GameManager.set_test_scenario(config)
	var test_core_type = config.get("core_type", "cornucopia")
	GameManager.core_type = test_core_type
	GameManager.totem_confirmed.emit(test_core_type)

func _create_cards():
	var core_data = {}
	if GameManager.data_manager and GameManager.data_manager.data.has("CORE_TYPES"):
		core_data = GameManager.data_manager.data["CORE_TYPES"]
	else:
		print("Error: CORE_TYPES not found in DataManager!")
		return

	for key in core_data.keys():
		var data = core_data[key]
		var card = CoreCardScene.instantiate()

		container.add_child(card)
		card.setup(key, data)
		card.card_selected.connect(_on_core_selected)

func _on_core_selected(core_key: String):
	"""玩家手动选择图腾 - 设置 core_type 并发射 totem_confirmed 信号"""
	GameManager.core_type = core_key
	print("[CoreSelection] 已选择图腾: " + core_key)

	# 发射全局信号，由 _on_totem_confirmed 处理场景切换
	GameManager.totem_confirmed.emit(core_key)

func _initialize_game_session():
	"""初始化游戏会话，确保商店和其他状态已准备好"""
	print("[CoreSelection] 初始化游戏会话...")

	# 确保SessionData已初始化
	if not GameManager.session_data:
		var SessionDataScript = load("res://src/Scripts/Data/SessionData.gd")
		GameManager.session_data = SessionDataScript.new()
		print("[CoreSelection] SessionData已创建")

	# 重置波次状态
	GameManager.session_data.wave = 1
	GameManager.session_data.is_wave_active = false

	# 初始化商店（如果为空）
	var needs_shop_init = true
	for i in range(4):
		if GameManager.session_data.get_shop_unit(i) != null:
			needs_shop_init = false
			break

	if needs_shop_init:
		print("[CoreSelection] 初始化商店...")
		# 刷新商店以获取初始单位
		BoardController.refresh_shop()

	print("[CoreSelection] 游戏会话初始化完成")

func _change_to_main_game(scene: PackedScene):
	get_tree().change_scene_to_packed(scene)
