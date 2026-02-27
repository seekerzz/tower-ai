extends Node

## AI 管理器 - WebSocket 服务端
## 监听游戏事件，暂停游戏，下发状态给 AI 客户端

const PORT: int = 9090

# ===== 网络组件 =====
var tcp_server: TCPServer = null
var websocket_peer: WebSocketPeer = null
var is_client_connected: bool = false

# ===== 状态 =====
var is_waiting_for_action: bool = false
var last_event_type: String = ""
var last_event_data: Dictionary = {}

# ===== 信号 =====
signal state_sent(event_type: String, state: Dictionary)
signal action_received(actions: Array)
signal client_connected
signal client_disconnected

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_server()
	_connect_game_signals()

func _exit_tree():
	_stop_server()

# ===== 服务器管理 =====

func _start_server():
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(PORT)
	if err != OK:
		AILogger.error("WebSocket 服务器启动失败，端口: %d，错误码: %d" % [PORT, err])
		return
	AILogger.net_connection("服务器已启动", "监听端口 %d" % PORT)

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
				is_client_connected = true
				AILogger.net_connection("客户端已连接")
				client_connected.emit()

	# 处理 WebSocket 消息
	if websocket_peer:
		websocket_peer.poll()
		var state = websocket_peer.get_ready_state()

		if state == WebSocketPeer.STATE_CLOSED:
			AILogger.net_connection("客户端已断开")
			websocket_peer = null
			is_client_connected = false
			is_waiting_for_action = false
			client_disconnected.emit()
			return

		if state == WebSocketPeer.STATE_OPEN:
			while websocket_peer.get_available_packet_count() > 0:
				var packet = websocket_peer.get_packet()
				var text = packet.get_string_from_utf8()
				AILogger.net_json("接收", text)
				_handle_client_message(text)

# ===== 游戏信号连接 =====

func _connect_game_signals():
	# 波次相关
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.wave_reset.connect(_on_wave_reset)
	GameManager.game_over.connect(_on_game_over)

	# 敌人相关
	GameManager.enemy_spawned.connect(_on_enemy_spawned)
	GameManager.enemy_died.connect(_on_enemy_died)

	# 核心受击
	GameManager.damage_dealt.connect(_on_damage_dealt)

	AILogger.event("游戏信号已连接")

# ===== 事件处理器 =====

func _on_wave_started():
	_pause_and_send("WaveStarted", {"wave": GameManager.wave})

func _on_wave_ended():
	_pause_and_send("WaveEnded", {"wave": GameManager.wave})

func _on_wave_reset():
	_send_state_async("WaveReset", {"wave": GameManager.wave})

func _on_game_over():
	_pause_and_send("GameOver", {"wave": GameManager.wave})

func _on_enemy_spawned(enemy: Node):
	# Boss 生成时暂停
	if enemy and "enemy_data" in enemy and enemy.enemy_data:
		var data = enemy.enemy_data
		if data and data.get("is_boss", false):
			_pause_and_send("BossSpawned", {
				"enemy_type": enemy.type_key if "type_key" in enemy else "unknown",
				"position": _vec2_to_dict(enemy.global_position)
			})

func _on_enemy_died(enemy: Node, killer_unit):
	# 可以在这里添加特定逻辑
	pass

func _on_damage_dealt(unit, amount):
	# 核心受击检测
	if unit == null and amount > 0:
		# 这是核心受到伤害
		var core_health = GameManager.core_health
		var max_health = GameManager.max_core_health
		if core_health / max_health < 0.3:
			_pause_and_send("CoreCritical", {
				"health": core_health,
				"max_health": max_health,
				"damage": amount
			})

# ===== 核心功能：暂停并发送状态 =====

func _pause_and_send(event_type: String, event_data: Dictionary = {}):
	if not is_client_connected:
		return

	last_event_type = event_type
	last_event_data = event_data

	# 暂停游戏
	get_tree().paused = true
	AILogger.event("游戏已暂停 [%s]" % event_type)

	# 构建并发送状态
	var state = _build_state(event_type, event_data)
	_send_json(state)

	is_waiting_for_action = true
	state_sent.emit(event_type, state)

func _send_state_async(event_type: String, event_data: Dictionary = {}):
	if not is_client_connected:
		return
	var state = _build_state(event_type, event_data)
	_send_json(state)

# ===== 状态构建 =====

func _build_state(event_type: String, event_data: Dictionary) -> Dictionary:
	var state = {
		"event": event_type,
		"event_data": event_data,
		"timestamp": Time.get_unix_time_from_system(),
		"global": _build_global_state(),
		"board": _build_board_state()
	}

	# 战斗阶段才下发敌人列表
	if GameManager.is_wave_active:
		state["enemies"] = _build_enemies_state()

	return state

func _build_global_state() -> Dictionary:
	var session = GameManager.session_data
	if not session:
		return {}

	return {
		"wave": session.wave,
		"gold": session.gold,
		"mana": session.mana,
		"max_mana": session.max_mana,
		"core_health": session.core_health,
		"max_core_health": session.max_core_health,
		"is_wave_active": session.is_wave_active,
		"shop_refresh_cost": session.shop_refresh_cost
	}

func _build_board_state() -> Dictionary:
	var session = GameManager.session_data
	if not session:
		return {"shop": [], "bench": [], "grid": []}

	# 商店状态
	var shop = []
	for i in range(4):
		var unit_key = session.get_shop_unit(i)
		shop.append({
			"index": i,
			"unit_key": unit_key,
			"locked": session.is_shop_slot_locked(i)
		})

	# 备战区状态
	var bench = []
	for i in range(Constants.BENCH_SIZE):
		var unit = session.get_bench_unit(i)
		bench.append({
			"index": i,
			"unit": _unit_to_dict(unit)
		})

	# 网格状态
	var grid = []
	for key in session.grid_units:
		var unit = session.grid_units[key]
		var pos = _key_to_vec2i(key)
		grid.append({
			"position": {"x": pos.x, "y": pos.y},
			"unit": _unit_to_dict(unit)
		})

	return {
		"shop": shop,
		"bench": bench,
		"grid": grid
	}

func _build_enemies_state() -> Array:
	var enemies = []
	var enemy_nodes = get_tree().get_nodes_in_group("enemies")

	for enemy in enemy_nodes:
		if not is_instance_valid(enemy):
			continue

		var enemy_info = {
			"type": enemy.type_key if "type_key" in enemy else "unknown",
			"hp": enemy.hp if "hp" in enemy else 0,
			"max_hp": enemy.max_hp if "max_hp" in enemy else 0,
			"position": _vec2_to_dict(enemy.global_position),
			"speed": enemy.speed if "speed" in enemy else 0,
			"state": _enemy_state_to_string(enemy.state) if "state" in enemy else "unknown"
		}

		# Debuff 信息
		var debuffs = _get_enemy_debuffs(enemy)
		if debuffs.size() > 0:
			enemy_info["debuffs"] = debuffs

		enemies.append(enemy_info)

	return enemies

func _get_enemy_debuffs(enemy: Node) -> Array:
	var debuffs = []

	# 检查各种状态
	if enemy.has_method("has_status"):
		if enemy.has_status("poison"):
			debuffs.append({"type": "poison"})
		if enemy.has_status("burn"):
			debuffs.append({"type": "burn"})
		if enemy.has_status("slow"):
			debuffs.append({"type": "slow"})
		if enemy.has_status("vulnerable"):
			debuffs.append({"type": "vulnerable"})

	# 流血层数
	if "bleed_stacks" in enemy and enemy.bleed_stacks > 0:
		debuffs.append({"type": "bleed", "stacks": enemy.bleed_stacks})

	# 眩晕/冻结/失明计时器
	if "stun_timer" in enemy and enemy.stun_timer > 0:
		debuffs.append({"type": "stun", "duration": enemy.stun_timer})
	if "freeze_timer" in enemy and enemy.freeze_timer > 0:
		debuffs.append({"type": "freeze", "duration": enemy.freeze_timer})
	if "blind_timer" in enemy and enemy.blind_timer > 0:
		debuffs.append({"type": "blind", "duration": enemy.blind_timer})

	return debuffs

# ===== 客户端消息处理 =====

func _handle_client_message(text: String):
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		AILogger.error("JSON 解析失败: %s" % text)
		_send_error("InvalidJSON", "无法解析 JSON: %s" % text)
		return

	var data = json.get_data()
	if not data is Dictionary:
		AILogger.error("消息格式错误，期望对象: %s" % text)
		_send_error("InvalidFormat", "消息必须是 JSON 对象")
		return

	# 检查是否是动作数组
	if data.has("actions"):
		var actions = data["actions"]
		if actions is Array:
			action_received.emit(actions)
		else:
			_send_error("InvalidFormat", "actions 必须是数组")
	else:
		AILogger.net("收到非动作消息: %s" % JSON.stringify(data))

# ===== 网络发送 =====

func _send_json(data: Dictionary):
	if not websocket_peer or websocket_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	var json_str = JSON.stringify(data)
	AILogger.net_json("发送", data)
	websocket_peer.send_text(json_str)

func _send_error(error_type: String, message: String):
	_send_json({
		"event": "Error",
		"error_type": error_type,
		"error_message": message
	})

func send_action_error(error_message: String, failed_action: Dictionary):
	_send_json({
		"event": "ActionError",
		"error_message": error_message,
		"failed_action": failed_action
	})

# ===== 游戏控制 =====

func resume_game(wait_time: float = 0.0):
	"""恢复游戏，可选延时后再次暂停"""
	if not get_tree().paused:
		return

	get_tree().paused = false
	AILogger.event("游戏已恢复" + (" (%.1f秒后唤醒)" % wait_time if wait_time > 0 else ""))

	if wait_time > 0:
		# 使用受 time_scale 影响的计时器
		var timer = get_tree().create_timer(wait_time)
		timer.timeout.connect(_on_wakeup_timer_timeout)

func _on_wakeup_timer_timeout():
	AILogger.event("AI 唤醒计时器触发")
	_pause_and_send("AI_Wakeup", {})

# ===== 辅助函数 =====

func _unit_to_dict(unit) -> Dictionary:
	if unit == null:
		return {}
	if unit is Dictionary:
		return unit
	return {}

func _vec2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

func _vec2i_to_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}

func _key_to_vec2i(key: String) -> Vector2i:
	var parts = key.split(",")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO

func _dict_to_vec2i(d: Dictionary) -> Vector2i:
	return Vector2i(d.get("x", 0), d.get("y", 0))

func _enemy_state_to_string(state) -> String:
	if state == null:
		return "unknown"
	# Enemy.State 枚举
	match state:
		0: return "move"
		1: return "attack_base"
		2: return "stunned"
		3: return "support"
		_: return "unknown"

# ===== 公共 API =====

func force_send_state(event_type: String, event_data: Dictionary = {}):
	"""强制发送当前状态（用于测试）"""
	_pause_and_send(event_type, event_data)

func is_ai_connected() -> bool:
	return is_client_connected

func is_waiting_action() -> bool:
	return is_waiting_for_action
