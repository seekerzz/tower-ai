extends Node

const StatusEffect = preload("res://src/Scripts/Effects/StatusEffect.gd")

## AI 管理器 - WebSocket 服务端
## 监听游戏事件，下发状态给 AI 客户端（主动推送）

# 默认端口，可通过 --ai-port=<port> 覆盖
const DEFAULT_PORT: int = 45678
var port: int = DEFAULT_PORT

# ===== 网络组件 =====
var tcp_server: TCPServer = null
var websocket_peer: WebSocketPeer = null
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
	_send_state_async("WaveStarted", {"wave": GameManager.wave})

func _on_wave_ended():
	_send_state_async("WaveEnded", {"wave": GameManager.wave})

func _on_wave_reset():
	is_game_over = false
	_send_state_async("WaveReset", {"wave": GameManager.wave})

func _on_wave_system_started(wave_number: int, wave_type: String, difficulty: float):
	AILogger.event("波次系统开始波次 %d，立即通知AI客户端" % wave_number)
	_send_state_async("WaveStarted", {
		"wave": wave_number,
		"wave_type": wave_type,
		"difficulty": difficulty
	})

func _on_wave_system_ended(wave_number: int, stats: Dictionary):
	AILogger.event("波次系统结束波次 %d，立即通知AI客户端" % wave_number)

	var unlocked_tiles = []
	if BoardController:
		unlocked_tiles = BoardController.get_unlocked_tiles()

	var event_data = {
		"wave": wave_number,
		"stats": {
			"duration": stats.get("duration", 0),
			"enemies_defeated": stats.get("enemies_defeated", 0),
			"enemies_spawned": stats.get("enemies_spawned", 0),
			"gold_earned": stats.get("gold_earned", 0)
		},
		"unlocked_tiles": unlocked_tiles
	}
	_send_state_async("WaveEnded", event_data)

func _on_upgrade_selection_shown():
	AILogger.event("升级选择界面已显示，通知AI客户端")
	_send_state_async("UpgradeSelection", {
		"message": "Wave completed. Upgrade selection is now available."
	})

func _on_game_over():
	is_game_over = true
	AILogger.event("游戏结束，发送 GameOver 事件给 AI")
	_send_state_async("GameOver", {"wave": GameManager.wave, "core_health": GameManager.core_health})

func _on_enemy_spawned(enemy: Node):
	if enemy and "enemy_data" in enemy and enemy.enemy_data:
		var data = enemy.enemy_data
		if data and data.get("is_boss", false):
			_send_state_async("BossSpawned", {
				"enemy_type": enemy.type_key if "type_key" in enemy else "unknown",
				"position": _vec2_to_dict(enemy.global_position)
			})

func _on_damage_dealt(unit, amount):
	if unit == null and amount > 0:
		var core_health = GameManager.core_health
		var max_health = GameManager.max_core_health
		var health_percent = core_health / max_health if max_health > 0 else 1.0

		var event_data = {
			"health": core_health,
			"max_health": max_health,
			"health_percent": health_percent,
			"damage": amount
		}

		if health_percent < 0.3:
			_send_state_async("CoreCritical", event_data)
		else:
			_send_state_async("CoreDamaged", event_data)

func _on_trap_placed(trap_type: String, position: Vector2, source_unit):
	var unit_type = source_unit.type_key if source_unit and source_unit.has_method("get") and source_unit.get("type_key") else "unknown"
	var unit_level = source_unit.level if source_unit and source_unit.has_method("get") and source_unit.get("level") else 1

	_send_state_async("TrapPlaced", {
		"trap_type": trap_type,
		"position": _vec2_to_dict(position),
		"source_unit": unit_type,
		"source_unit_level": unit_level
	})

func _on_trap_triggered(trap_type: String, target_enemy, source_unit):
	var unit_type = source_unit.type_key if source_unit and source_unit.has_method("get") and source_unit.get("type_key") else "unknown"
	var enemy_type = target_enemy.type_key if target_enemy and target_enemy.has_method("get") and target_enemy.get("type_key") else "unknown"
	var enemy_name = target_enemy.name if target_enemy and target_enemy.has_method("get") and target_enemy.get("name") else "unknown"
	var enemy_position = target_enemy.global_position if target_enemy else Vector2.ZERO

	_send_state_async("TrapTriggered", {
		"trap_type": trap_type,
		"target_enemy": enemy_type,
		"target_enemy_name": enemy_name,
		"target_position": _vec2_to_dict(enemy_position),
		"source_unit": unit_type,
		"poison_stacks": 2
	})

# ===== 发送状态 =====

func _send_state_async(event_type: String, event_data: Dictionary = {}):
	if not is_client_connected:
		return
	var state = _build_state(event_type, event_data)

	last_event_type = event_type
	last_event_data = event_data
	state_sent.emit(event_type, state)

	_send_json(state)

# ===== 广播文字日志 =====

func broadcast_narrative(event_data: Dictionary):
	if not is_client_connected:
		return
	_send_json(event_data)

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
			"name": enemy.type_key if "type_key" in enemy else "unknown",
			"hp": enemy.hp if "hp" in enemy else 0,
			"position": _vec2_to_dict(enemy.global_position),
			"state": _enemy_state_to_string(enemy.state) if "state" in enemy else "unknown"
		}

		var debuffs = _get_enemy_debuffs(enemy)
		if debuffs.size() > 0:
			enemy_info["debuffs"] = debuffs

		if "faction" in enemy and enemy.faction == "player":
			enemy_info["is_charmed"] = true

		if "behavior" in enemy and enemy.behavior:
			var behavior = enemy.behavior
			if behavior.has_method("set_split_info"):
				enemy_info["split_generation"] = behavior.get("split_generation", 0)

		enemies.append(enemy_info)

	return enemies

func _get_enemy_debuffs(enemy: Node) -> Array:
	var debuffs = []

	if enemy.has_method("has_status"):
		if enemy.has_status("poison"):
			var poison_stacks = _get_effect_stacks(enemy, "poison")
			debuffs.append({"type": "poison", "stacks": poison_stacks})
		if enemy.has_status("burn"):
			var burn_stacks = _get_effect_stacks(enemy, "burn")
			debuffs.append({"type": "burn", "stacks": burn_stacks})
		if enemy.has_status("slow"):
			var slow_stacks = _get_effect_stacks(enemy, "slow")
			debuffs.append({"type": "slow", "stacks": slow_stacks})
		if enemy.has_status("vulnerable"):
			var vuln_stacks = _get_effect_stacks(enemy, "vulnerable")
			debuffs.append({"type": "vulnerable", "stacks": vuln_stacks})

	if "bleed_stacks" in enemy and enemy.bleed_stacks > 0:
		debuffs.append({"type": "bleed", "stacks": enemy.bleed_stacks})

	if "stun_timer" in enemy and enemy.stun_timer > 0:
		debuffs.append({"type": "stun", "duration": enemy.stun_timer})
	if "freeze_timer" in enemy and enemy.freeze_timer > 0:
		debuffs.append({"type": "freeze", "duration": enemy.freeze_timer})
	if "blind_timer" in enemy and enemy.blind_timer > 0:
		debuffs.append({"type": "blind", "duration": enemy.blind_timer})

	return debuffs

func _get_effect_stacks(enemy: Node, effect_type: String) -> int:
	for c in enemy.get_children():
		if c is StatusEffect and c.type_key == effect_type:
			if "stacks" in c:
				return c.stacks
			return 1
	return 1

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
		_send_state_async("GameOver", {"wave": GameManager.wave, "core_health": 0, "message": "Game already over"})
		return

	if data.has("actions"):
		var actions = data["actions"]
		if actions is Array:
			action_received.emit(actions)
		else:
			_send_error("InvalidFormat", "actions 必须是数组")

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

# ===== 辅助函数 =====

func _unit_to_dict(unit) -> Dictionary:
	if unit == null: return {}
	if unit is Dictionary: return unit
	if unit is Node and unit.has_method("get_script"):
		var result = {}
		if "type_key" in unit: result["type"] = unit.type_key
		if "level" in unit: result["level"] = unit.level
		if "damage" in unit: result["damage"] = unit.damage
		if "range_val" in unit: result["range"] = unit.range_val
		if "atk_speed" in unit: result["attack_speed"] = unit.atk_speed
		if "current_hp" in unit: result["hp"] = unit.current_hp
		if "max_hp" in unit: result["max_hp"] = unit.max_hp
		if "crit_rate" in unit: result["crit_rate"] = unit.crit_rate
		if "crit_dmg" in unit: result["crit_damage"] = unit.crit_dmg
		if "bounce_count" in unit and unit.bounce_count > 0: result["bounce_count"] = unit.bounce_count
		if "split_count" in unit and unit.split_count > 0: result["split_count"] = unit.split_count
		if "active_buffs" in unit and unit.active_buffs.size() > 0: result["buffs"] = unit.active_buffs.duplicate()
		if "skill_cooldown" in unit and unit.skill_cooldown > 0: result["skill_cooldown"] = unit.skill_cooldown

		if "unit_data" in unit and unit.unit_data:
			var data = unit.unit_data
			if data.has("attackType"): result["attack_type"] = data.attackType
			if data.has("skill"): result["skill"] = data.skill
			if data.has("proj"): result["projectile_type"] = data.proj
		return result
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
	match state:
		0: return "move"
		1: return "attack_base"
		2: return "stunned"
		3: return "support"
		_: return "unknown"

# ===== 公共 API =====

func force_send_state(event_type: String, event_data: Dictionary = {}):
	_send_state_async(event_type, event_data)

func is_ai_connected() -> bool:
	return is_client_connected

func is_waiting_action() -> bool:
	return is_waiting_for_action
