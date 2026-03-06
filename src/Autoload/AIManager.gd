extends Node

## AI 管理器 - WebSocket 服务端
## 退化为纯粹的 TCP/WebSocket 端口监听与文本收发器

# 默认端口，可通过 --ai-port=<port> 覆盖
const DEFAULT_PORT: int = 45678
var port: int = DEFAULT_PORT

# ===== 网络组件 =====
var tcp_server: TCPServer = null
var websocket_peer = null # Removed strong type to allow mocking in tests
var is_client_connected: bool = false

# ===== 状态 =====
var is_waiting_for_action: bool = false
var is_game_over: bool = false

# ===== 心跳/保活 =====
var _last_ping_time: float = 0.0
const PING_INTERVAL: float = 10.0  # 每10秒发送一次ping

func _parse_command_line_args():
	var args = OS.get_cmdline_args()
	var ai_mode_active = false
	var ai_speed = 0.5

	for arg in args:
		if arg.begins_with("--ai-port="):
			var port_str = arg.substr("--ai-port=".length())
			var parsed_port = port_str.to_int()
			if parsed_port > 1024 and parsed_port < 65535:
				port = parsed_port
				if AILogger: AILogger.broadcast_log("连接", "使用自定义端口: " + str(port))
			else:
				if AILogger: AILogger.broadcast_log("错误", "无效的端口: %s，使用默认 %d" % [port_str, DEFAULT_PORT])
			ai_mode_active = true
		elif arg.begins_with("--ai-speed="):
			ai_speed = float(arg.substr("--ai-speed=".length()))
			ai_mode_active = true

	if ai_mode_active:
		Engine.time_scale = ai_speed
		if AILogger: AILogger.broadcast_log("事件", "AI 模式已激活，设置游戏速度为: " + str(ai_speed))

# ===== 信号 =====
signal action_received(actions: Array)
signal client_connected
signal client_disconnected

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_command_line_args()
	call_deferred("_delayed_start_server")

func _delayed_start_server():
	await get_tree().create_timer(0.5).timeout
	_start_server()

func _exit_tree():
	_stop_server()

func _start_server():
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port)
	if err != OK:
		if AILogger: AILogger.broadcast_log("错误", "WebSocket 服务器启动失败，端口: %d" % port)
		tcp_server = null
		return
	if AILogger: AILogger.broadcast_log("连接", "服务器已启动 - 监听端口 %d" % port)

func _stop_server():
	if websocket_peer:
		websocket_peer.close()
		websocket_peer = null
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	is_client_connected = false
	if AILogger: AILogger.broadcast_log("连接", "服务器已停止")

func _process(_delta):
	if tcp_server and tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		if conn:
			if websocket_peer:
				conn.disconnect_from_host()
			else:
				websocket_peer = WebSocketPeer.new()
				websocket_peer.accept_stream(conn)

	if websocket_peer:
		websocket_peer.poll()
		var state = websocket_peer.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			if not is_client_connected:
				is_client_connected = true
				client_connected.emit()

			var current_time = Time.get_unix_time_from_system()
			if current_time - _last_ping_time > PING_INTERVAL:
				_send_ping()
				_last_ping_time = current_time

			while websocket_peer.get_available_packet_count() > 0:
				var packet = websocket_peer.get_packet()
				var text = packet.get_string_from_utf8()
				_handle_client_message(text)

		elif state == WebSocketPeer.STATE_CLOSED:
			if AILogger: AILogger.broadcast_log("连接", "客户端已断开")
			websocket_peer = null
			is_client_connected = false
			is_waiting_for_action = false
			client_disconnected.emit()

func broadcast_text(text: String):
	if not is_client_connected or not websocket_peer:
		return
	if websocket_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		websocket_peer.send_text(text)

func _handle_client_message(text: String):
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK: return

	var data = json.get_data()
	if not data is Dictionary: return

	if data.has("actions") and data["actions"] is Array:
		action_received.emit(data["actions"])

func _send_ping():
	var core_health = GameManager.core_health
	var max_health = GameManager.max_core_health
	broadcast_text("【状态同步】当前核心血量：%.1f/%.1f" % [core_health, max_health])

func is_ai_connected() -> bool: return is_client_connected
func is_waiting_action() -> bool: return is_waiting_for_action
