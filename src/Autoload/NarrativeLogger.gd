extends Node

## 自然语言日志管理器
## 将游戏状态和事件转化为人类可读的自然语言日志，并推送到AI

signal log_generated(log_entry: Dictionary)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect to GameManager and ActionDispatcher signals
	if GameManager:
		GameManager.wave_started.connect(_on_wave_started)
		GameManager.wave_ended.connect(_on_wave_ended)
		GameManager.damage_dealt.connect(_on_damage_dealt)
		GameManager.game_over.connect(_on_game_over)

	# Connect to ActionDispatcher
	if has_node("/root/ActionDispatcher"):
		var dispatcher = get_node("/root/ActionDispatcher")
		dispatcher.action_dispatched.connect(_on_action_dispatched)

func _on_wave_started():
	var narrative = "[Wave] Wave %d started." % GameManager.wave
	_create_log_entry("WaveStarted", {"wave": GameManager.wave}, narrative)

func _on_wave_ended():
	var narrative = "[Wave] Wave %d ended." % GameManager.wave
	_create_log_entry("WaveEnded", {"wave": GameManager.wave}, narrative)

func _on_game_over():
	var narrative = "[Core] Base destroyed! Game Over."
	_create_log_entry("GameOver", {"wave": GameManager.wave}, narrative)

func _on_damage_dealt(unit, amount):
	if unit == null and amount > 0:
		var health = max(0, GameManager.core_health - amount)
		var max_h = GameManager.max_core_health
		var narrative = "[Core] Base took %d damage, current HP: %d/%d" % [amount, health, max_h]
		_create_log_entry("CoreDamaged", {
			"damage": amount,
			"health": health,
			"max_health": max_h
		}, narrative)

func _on_action_dispatched(action_type: String, data: Dictionary):
	var narrative = "[Action] Player performed: %s" % action_type

	if action_type == "buy_unit":
		var cost_str = ""
		if GameManager.session_data:
			var unit_key = GameManager.session_data.get_shop_unit(data.get("shop_index", -1))
			if unit_key:
				narrative = "[Shop] Player purchased unit '%s' from slot %d" % [unit_key, data.get("shop_index", -1)]
	elif action_type == "refresh_shop":
		narrative = "[Shop] Player refreshed shop"
	elif action_type == "try_move_unit":
		var fz = data.get("from_zone", "")
		var tz = data.get("to_zone", "")
		var fp = data.get("from_pos", "")
		var tp = data.get("to_pos", "")
		narrative = "[Board] Player moved unit from %s(%s) to %s(%s)" % [fz, str(fp), tz, str(tp)]

	_create_log_entry("PlayerAction", {"action": action_type, "details": data}, narrative)

func _create_log_entry(event_type: String, data: Dictionary, narrative: String) -> Dictionary:
	var entry = {
		"event": event_type,
		"event_data": data,
		"narrative": narrative,
		"timestamp": Time.get_unix_time_from_system()
	}

	log_generated.emit(entry)
	print("[Narrative] ", narrative)

	# Try sending to websocket if connected
	if has_node("/root/AIManager"):
		var aim = get_node("/root/AIManager")
		if aim.websocket_peer and aim.is_client_connected:
			var state = aim.websocket_peer.get_ready_state()
			if state == WebSocketPeer.STATE_OPEN:
				var json_str = JSON.stringify(entry)
				aim.websocket_peer.send_text(json_str)

	return entry
