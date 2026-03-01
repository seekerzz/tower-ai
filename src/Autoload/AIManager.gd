extends Node

const StatusEffect = preload("res://src/Scripts/Effects/StatusEffect.gd")

## AI 管理器 - WebSocket 服务端
## 监听游戏事件，下发状态给 AI 客户端（主动推送）

# 默认端口，可通过 --ai-port=<port> 覆盖
const DEFAULT_PORT: int = 45678
var port: int = DEFAULT_PORT

# ===== 网络组件 =====
var tcp_server: TCPServer = null
var websocket_peer = null # Removed strong type to allow mocking in tests
var is_client_connected: bool = false

# ===== 状态 =====
var is_waiting_for_action: bool = false
var last_event_type: String = ""
var last_event_data: Dictionary = {}
var is_game_over: bool = false

# ===== 心跳/保活 =====
var _last_ping_time: float = 0.0
const PING_INTERVAL: float = 10.0  # 每10秒发送一次ping

func _parse_command_line_args():
	"""解析命令行参数，支持 --ai-port=<port> 和 --ai-speed=<value>"""
	var args = OS.get_cmdline_args()
	var ai_mode_active = false
	var ai_speed = 0.5 # Default speed

	for arg in args:
		if arg.begins_with("--ai-port="):
			var port_str = arg.substr("--ai-port=".length())
			var parsed_port = port_str.to_int()
			if parsed_port > 1024 and parsed_port < 65535:
				port = parsed_port
				AILogger.net_connection("使用自定义端口", str(port))
			else:
				AILogger.error("无效的端口: %s，使用默认 %d" % [port_str, DEFAULT_PORT])
			ai_mode_active = true
		elif arg.begins_with("--ai-speed="):
			ai_speed = float(arg.substr("--ai-speed=".length()))
			ai_mode_active = true

	if ai_mode_active:
		Engine.time_scale = ai_speed
		AILogger.event("AI 模式已激活，设置游戏速度为: " + str(ai_speed))

# ===== 信号 =====
signal state_sent(event_type: String, state: Dictionary)
signal action_received(actions: Array)
signal client_connected
signal client_disconnected

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_command_line_args()  # 解析命令行参数
	# 延迟启动服务器，确保网络子系统就绪
	call_deferred("_delayed_start_server")
	_connect_game_signals()

func _delayed_start_server():
	await get_tree().create_timer(0.5).timeout
	_start_server()

func _exit_tree():
	_stop_server()

# ===== 服务器管理 =====

func _start_server():
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port)
	if err != OK:
		AILogger.error("WebSocket 服务器启动失败，端口: %d，错误码: %d" % [port, err])
		tcp_server = null
		return
	AILogger.net_connection("服务器已启动", "监听端口 %d" % port)

func _stop_server():
	if websocket_peer:
		websocket_peer.close()
		websocket_peer = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	is_client_connected = false
	AILogger.net_connection("服务器已停止")

func _process(_delta):
	# 处理新的 TCP 连接
	if tcp_server and tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		if conn:
			if websocket_peer:
				AILogger.net_connection("拒绝新连接", "已有客户端连接")
				conn.disconnect_from_host()
			else:
				websocket_peer = WebSocketPeer.new()
				websocket_peer.accept_stream(conn)
				AILogger.net_connection("收到TCP连接", "等待WebSocket握手...")

	# 处理 WebSocket
	if websocket_peer:
		websocket_peer.poll()
		var state = websocket_peer.get_ready_state()

		if state == WebSocketPeer.STATE_CONNECTING:
			# 正在握手，等待完成
			pass

		elif state == WebSocketPeer.STATE_OPEN:
			if not is_client_connected:
				is_client_connected = true
				AILogger.net_connection("客户端已连接", "WebSocket握手成功")
				client_connected.emit()

			# 发送心跳保活
			var current_time = Time.get_unix_time_from_system()
			if current_time - _last_ping_time > PING_INTERVAL:
				_send_ping()
				_last_ping_time = current_time

			while websocket_peer.get_available_packet_count() > 0:
				var packet = websocket_peer.get_packet()
				var text = packet.get_string_from_utf8()
				AILogger.net_json("接收", text)
				_handle_client_message(text)

		elif state == WebSocketPeer.STATE_CLOSED:
			AILogger.net_connection("客户端已断开")
			websocket_peer = null
			is_client_connected = false
			is_waiting_for_action = false
			client_disconnected.emit()

# ===== 游戏信号连接 =====

func _connect_game_signals():
	# 波次相关 - 连接GameManager的信号
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.wave_reset.connect(_on_wave_reset)
	GameManager.game_over.connect(_on_game_over)

	# 波次相关 - 连接WaveSystemManager的信号（用于立即获得波次结束通知）
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(_on_wave_system_started)
		GameManager.wave_system_manager.wave_ended.connect(_on_wave_system_ended)

	# 升级选择相关
	GameManager.upgrade_selection_shown.connect(_on_upgrade_selection_shown)

	# 敌人相关
	GameManager.enemy_spawned.connect(_on_enemy_spawned)

	# 核心受击
	GameManager.damage_dealt.connect(_on_damage_dealt)

	# 陷阱相关
	GameManager.trap_placed.connect(_on_trap_placed)
	GameManager.trap_triggered.connect(_on_trap_triggered)

	AILogger.event("游戏信号已连接")

# ===== 事件处理器 =====

func _on_wave_started():
	# NarrativeLogger handles wave started
	pass

func _on_wave_ended():
	# NarrativeLogger handles wave ended
	pass

func _on_wave_reset():
	is_game_over = false
	broadcast_text("【系统提示】波次已重置。")

func _on_wave_system_started(wave_number: int, wave_type: String, difficulty: float):
	# NarrativeLogger handles wave started
	AILogger.event("波次系统开始波次 %d，立即通知AI客户端" % wave_number)

func _on_wave_system_ended(wave_number: int, stats: Dictionary):
	# NarrativeLogger handles wave ended
	AILogger.event("波次系统结束波次 %d，立即通知AI客户端" % wave_number)

func _on_upgrade_selection_shown():
	AILogger.event("升级选择界面已显示，通知AI客户端")
	broadcast_text("【系统提示】波次完成，可以进行升级选择了。")

func _on_game_over():
	is_game_over = true
	AILogger.event("游戏结束，发送 GameOver 事件给 AI")
	broadcast_text("【系统提示】游戏结束，图腾核心已被摧毁！")

func _on_enemy_spawned(enemy: Node):
	if enemy and "enemy_data" in enemy and enemy.enemy_data:
		var data = enemy.enemy_data
		if data and data.get("is_boss", false):
			var enemy_type = enemy.type_key if "type_key" in enemy else "未知"
			broadcast_text("【Boss出现】强大的 %s 出现了！" % enemy_type)

func _on_damage_dealt(unit, amount):
	# NarrativeLogger handles core damage
	if unit == null and amount > 0:
		var core_health = GameManager.core_health
		var max_health = GameManager.max_core_health
		var health_percent = core_health / max_health if max_health > 0 else 1.0

		if health_percent < 0.3:
			broadcast_text("【危险警告】图腾核心血量低于30%！")

func _on_trap_placed(trap_type: String, position: Vector2, source_unit):
	var unit_type = source_unit.type_key if source_unit and source_unit.has_method("get") and source_unit.get("type_key") else "未知单位"
	broadcast_text("【陷阱放置】%s 放置了一个陷阱（类型：%s）。" % [unit_type, trap_type])

func _on_trap_triggered(trap_type: String, target_enemy, source_unit):
	var unit_type = source_unit.type_key if source_unit and source_unit.has_method("get") and source_unit.get("type_key") else "未知单位"
	var enemy_name = target_enemy.name if target_enemy and target_enemy.has_method("get") and target_enemy.get("name") else "未知敌人"
	broadcast_text("【陷阱触发】%s 踩中了 %s 放置的陷阱（类型：%s）。" % [enemy_name, unit_type, trap_type])


# ===== 广播文字日志 =====

func broadcast_text(text: String):
	if not is_client_connected:
		return
	if not websocket_peer:
		return

	var state = websocket_peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		websocket_peer.send_text(text)


# ===== 客户端消息处理 =====

func _handle_client_message(text: String):
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		_send_error("InvalidJSON", "无法解析 JSON: %s" % text)
		return

	var data = json.get_data()
	if not data is Dictionary:
		_send_error("InvalidFormat", "消息必须是 JSON 对象")
		return

	if is_game_over:
		broadcast_text("【游戏结束】当前波次：%d，核心血量：0。" % GameManager.wave)
		return

	if data.has("type") and data["type"] == "observe":
		var state_text = _generate_natural_language_state()
		broadcast_text(state_text)
		return

	if data.has("actions"):
		var actions = data["actions"]
		if actions is Array:
			action_received.emit(actions)
		else:
			_send_error("InvalidFormat", "actions 必须是数组")

func _generate_natural_language_state() -> String:
	var wave = GameManager.wave
	var gold = GameManager.gold
	var hp = GameManager.core_health
	var max_hp = GameManager.max_core_health

	var desc = "当前状态：第 %d 波，金币 %d，核心血量 %.1f/%.1f。 " % [wave, gold, hp, max_hp]

	if GameManager.session_data:
		var grid_desc = ""
		for key in GameManager.session_data.grid_units:
			var unit = GameManager.session_data.grid_units[key]
			var pos = key
			var type = unit.type_key if typeof(unit) == TYPE_OBJECT and "type_key" in unit else "未知"
			var level = unit.level if typeof(unit) == TYPE_OBJECT and "level" in unit else 1
			grid_desc += "%s(Lv%d)在%s，" % [type, level, pos]
		if grid_desc != "":
			desc += "场上单位：" + grid_desc.trim_suffix("，") + "。"
		else:
			desc += "场上没有单位。"

		var shop_desc = ""
		for i in range(4):
			var unit_key = GameManager.session_data.get_shop_unit(i)
			if unit_key:
				shop_desc += "%s，" % unit_key
		if shop_desc != "":
			desc += " 商店提供：" + shop_desc.trim_suffix("，") + "。"

	return desc

# ===== 网络发送 =====

func _send_json(data: Dictionary):
	if not websocket_peer:
		return

	var state = websocket_peer.get_ready_state()
	if state != WebSocketPeer.STATE_OPEN:
		return

	var json_str = JSON.stringify(data)
	websocket_peer.send_text(json_str)

func _send_error(error_type: String, message: String):
	_send_json({
		"event": "Error",
		"error_type": error_type,
		"error_message": message
	})

func _send_ping():
	_send_json({
		"event": "Ping",
		"timestamp": Time.get_unix_time_from_system()
	})

func send_action_error(error_message: String, failed_action: Dictionary):
	_send_json({
		"event": "ActionError",
		"error_message": error_message,
		"failed_action": failed_action
	})


# ===== 公共 API =====

func force_send_state(event_type: String, event_data: Dictionary = {}):
	# Fallback if anything still calls this for legacy state passing
	var state_json = JSON.stringify({"event": event_type, "data": event_data})
	broadcast_text(state_json)

func is_ai_connected() -> bool:
	return is_client_connected

func is_waiting_action() -> bool:
	return is_waiting_for_action
