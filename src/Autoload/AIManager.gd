extends Node

## AI 管理器 - WebSocket 服务端
## 监听游戏事件，暂停游戏，下发状态给 AI 客户端

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

# ===== 心跳/保活 =====
var _last_ping_time: float = 0.0
const PING_INTERVAL: float = 10.0  # 每10秒发送一次ping

## AI 暂停标志 - 用于非原生暂停（只停逻辑，UI继续）
var ai_paused: bool = false:
	get:
		return ai_paused
	set(value):
		ai_paused = value
		AILogger.event("AI暂停状态: " + str(value))

## 检查游戏是否应该暂停（AI暂停或原生暂停）
func is_game_effectively_paused() -> bool:
	return ai_paused or get_tree().paused

func _parse_command_line_args():
	"""解析命令行参数，支持 --ai-port=<port>"""
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--ai-port="):
			var port_str = arg.substr("--ai-port=".length())
			var parsed_port = port_str.to_int()
			if parsed_port > 1024 and parsed_port < 65535:
				port = parsed_port
				AILogger.net_connection("使用自定义端口", str(port))
			else:
				AILogger.error("无效的端口: %s，使用默认 %d" % [port_str, DEFAULT_PORT])

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
	GameManager.enemy_died.connect(_on_enemy_died)

	# 核心受击
	GameManager.damage_dealt.connect(_on_damage_dealt)

	# 陷阱相关
	GameManager.trap_placed.connect(_on_trap_placed)
	GameManager.trap_triggered.connect(_on_trap_triggered)

	AILogger.event("游戏信号已连接")

# ===== 事件处理器 =====

func _on_wave_started():
	_pause_and_send("WaveStarted", {"wave": GameManager.wave})

func _on_wave_ended():
	_pause_and_send("WaveEnded", {"wave": GameManager.wave})

func _on_wave_reset():
	_send_state_async("WaveReset", {"wave": GameManager.wave})

func _on_wave_system_started(wave_number: int, wave_type: String, difficulty: float):
	"""波次系统开始新波次的回调 - 立即通知AI客户端"""
	AILogger.event("波次系统开始波次 %d，立即通知AI客户端" % wave_number)
	_pause_and_send("WaveStarted", {
		"wave": wave_number,
		"wave_type": wave_type,
		"difficulty": difficulty
	})

func _on_wave_system_ended(wave_number: int, stats: Dictionary):
	"""波次系统结束波次的回调 - 立即通知AI客户端，避免等待升级选择"""
	AILogger.event("波次系统结束波次 %d，立即通知AI客户端" % wave_number)
	# 构建包含波次统计的状态
	var event_data = {
		"wave": wave_number,
		"stats": {
			"duration": stats.get("duration", 0),
			"enemies_defeated": stats.get("enemies_defeated", 0),
			"enemies_spawned": stats.get("enemies_spawned", 0),
			"gold_earned": stats.get("gold_earned", 0)
		}
	}
	_pause_and_send("WaveEnded", event_data)

func _on_upgrade_selection_shown():
	"""升级选择界面显示时通知AI客户端"""
	AILogger.event("升级选择界面已显示，通知AI客户端")
	_send_state_async("UpgradeSelection", {
		"message": "Wave completed. Upgrade selection is now available. Send 'resume' action to continue."
	})

func _on_game_over():
	AILogger.event("游戏结束，发送 GameOver 事件给 AI")
	_pause_and_send("GameOver", {"wave": GameManager.wave, "core_health": GameManager.core_health})

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
	# 核心受击检测 - unit 为 null 表示核心受到伤害
	if unit == null and amount > 0:
		# 这是核心受到伤害
		var core_health = GameManager.core_health
		var max_health = GameManager.max_core_health
		var health_percent = core_health / max_health if max_health > 0 else 1.0

		# 构建核心受击事件数据
		var event_data = {
			"health": core_health,
			"max_health": max_health,
			"health_percent": health_percent,
			"damage": amount
		}

		# 根据血量百分比决定事件类型
		if health_percent < 0.3:
			_pause_and_send("CoreCritical", event_data)
		else:
			_pause_and_send("CoreDamaged", event_data)

func _on_trap_placed(trap_type: String, position: Vector2, source_unit):
	"""陷阱放置事件 - 发送给AI客户端"""
	var unit_type = source_unit.type_key if source_unit and source_unit.has_method("get") and source_unit.get("type_key") else "unknown"
	var unit_level = source_unit.level if source_unit and source_unit.has_method("get") and source_unit.get("level") else 1

	AILogger.event("陷阱已放置: %s 在位置 %s 由 %s(L%d) 放置" % [trap_type, str(position), unit_type, unit_level])

	_send_state_async("TrapPlaced", {
		"trap_type": trap_type,
		"position": _vec2_to_dict(position),
		"source_unit": unit_type,
		"source_unit_level": unit_level
	})

func _on_trap_triggered(trap_type: String, target_enemy, source_unit):
	"""陷阱触发事件 - 发送给AI客户端"""
	var unit_type = source_unit.type_key if source_unit and source_unit.has_method("get") and source_unit.get("type_key") else "unknown"
	var enemy_type = target_enemy.type_key if target_enemy and target_enemy.has_method("get") and target_enemy.get("type_key") else "unknown"
	var enemy_name = target_enemy.name if target_enemy and target_enemy.has_method("get") and target_enemy.get("name") else "unknown"
	var enemy_position = target_enemy.global_position if target_enemy else Vector2.ZERO

	AILogger.event("陷阱已触发: %s 击中目标 %s (类型:%s) 在位置 %s" % [trap_type, enemy_name, enemy_type, str(enemy_position)])

	_send_state_async("TrapTriggered", {
		"trap_type": trap_type,
		"target_enemy": enemy_type,
		"target_enemy_name": enemy_name,
		"target_position": _vec2_to_dict(enemy_position),
		"source_unit": unit_type,
		"poison_stacks": 2  # Toad陷阱固定给予2层中毒
	})

# ===== 核心功能：暂停并发送状态 =====

func _pause_and_send(event_type: String, event_data: Dictionary = {}):
	if not is_client_connected:
		return

	last_event_type = event_type
	last_event_data = event_data

	# 使用AI暂停（非原生暂停，UI不灰屏）
	ai_paused = true
	AILogger.event("游戏已暂停 [%s]" % event_type)

	# 构建并发送状态
	var state = _build_state(event_type, event_data)
	_send_json(state)

	is_waiting_for_action = true
	state_sent.emit(event_type, state)

func _send_state_async(event_type: String, event_data: Dictionary = {}):
	AILogger.net("准备发送状态: %s (客户端连接: %s)" % [event_type, str(is_client_connected)])
	if not is_client_connected:
		AILogger.error("状态发送失败: 客户端未连接")
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

		# 从 enemy_data 获取攻击和机制信息
		if "enemy_data" in enemy and enemy.enemy_data:
			var data = enemy.enemy_data
			enemy_info["damage"] = data.get("dmg", 0)
			enemy_info["attack_speed"] = data.get("atkSpeed", 1.0)
			enemy_info["attack_type"] = data.get("attackType", "melee")
			enemy_info["is_boss"] = data.get("is_boss", false)
			enemy_info["is_suicide"] = data.get("is_suicide", false)
			enemy_info["radius"] = data.get("radius", 20.0)
			# 远程攻击的射程
			if data.get("attackType") == "ranged":
				enemy_info["range"] = data.get("range", 200.0)

		# 物理属性
		if "mass" in enemy:
			enemy_info["mass"] = enemy.mass
		if "knockback_resistance" in enemy:
			enemy_info["knockback_resistance"] = enemy.knockback_resistance

		# Debuff 信息（包含详细层数）
		var debuffs = _get_enemy_debuffs(enemy)
		if debuffs.size() > 0:
			enemy_info["debuffs"] = debuffs

		# 魅惑状态
		if "faction" in enemy and enemy.faction == "player":
			enemy_info["is_charmed"] = true

		enemies.append(enemy_info)

	return enemies

func _get_enemy_debuffs(enemy: Node) -> Array:
	var debuffs = []

	# 检查各种状态（包含层数信息）
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

func _get_effect_stacks(enemy: Node, effect_type: String) -> int:
	"""获取指定效果类型的层数"""
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
	if not websocket_peer:
		AILogger.error("发送失败: WebSocket peer 不存在")
		return

	var state = websocket_peer.get_ready_state()
	if state != WebSocketPeer.STATE_OPEN:
		AILogger.error("发送失败: WebSocket 未打开，状态: %d" % state)
		return

	var json_str = JSON.stringify(data)
	AILogger.net_json("发送", data)
	var err = websocket_peer.send_text(json_str)
	if err != OK:
		AILogger.error("发送失败: WebSocket 发送错误: %d" % err)

func _send_error(error_type: String, message: String):
	_send_json({
		"event": "Error",
		"error_type": error_type,
		"error_message": message
	})

func _send_ping():
	"""发送心跳保活消息"""
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

# ===== 游戏控制 =====

func resume_game(wait_time: float = 0.0):
	"""恢复游戏，可选延时后再次暂停"""
	if not ai_paused:
		return

	ai_paused = false
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

	# 处理 Unit 对象
	if unit is Node and unit.has_method("get_script"):
		var result = {}

		# 基础信息
		if "type_key" in unit:
			result["type"] = unit.type_key
		if "level" in unit:
			result["level"] = unit.level

		# 战斗属性
		if "damage" in unit:
			result["damage"] = unit.damage
		if "range_val" in unit:
			result["range"] = unit.range_val
		if "atk_speed" in unit:
			result["attack_speed"] = unit.atk_speed
		if "current_hp" in unit:
			result["hp"] = unit.current_hp
		if "max_hp" in unit:
			result["max_hp"] = unit.max_hp

		# 特殊属性
		if "crit_rate" in unit:
			result["crit_rate"] = unit.crit_rate
		if "crit_dmg" in unit:
			result["crit_damage"] = unit.crit_dmg
		if "bounce_count" in unit and unit.bounce_count > 0:
			result["bounce_count"] = unit.bounce_count
		if "split_count" in unit and unit.split_count > 0:
			result["split_count"] = unit.split_count

		# Buffs
		if "active_buffs" in unit and unit.active_buffs.size() > 0:
			result["buffs"] = unit.active_buffs.duplicate()

		# 技能冷却
		if "skill_cooldown" in unit and unit.skill_cooldown > 0:
			result["skill_cooldown"] = unit.skill_cooldown

		# 单位数据中的额外信息
		if "unit_data" in unit and unit.unit_data:
			var data = unit.unit_data
			if data.has("attackType"):
				result["attack_type"] = data.attackType
			if data.has("skill"):
				result["skill"] = data.skill
			if data.has("proj"):
				result["projectile_type"] = data.proj

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
