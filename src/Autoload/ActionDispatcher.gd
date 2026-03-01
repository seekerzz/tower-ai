extends Node

## Action Dispatcher
## Routes asynchronous actions directly to BoardController and GameManager
## Replaces the old AIActionExecutor by avoiding blocking loops or explicit state confirmation

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Wait for AIManager
	await get_tree().process_frame

	if AIManager:
		AIManager.action_received.connect(_on_actions_received)
		AILogger.action("ActionDispatcher已连接到 AIManager")

func _on_actions_received(actions: Array):
	if actions.size() == 0:
		return

	AILogger.action("ActionDispatcher 开始分发 %d 个动作" % actions.size())

	for action in actions:
		if not action is Dictionary:
			AILogger.error("动作格式错误: %s" % str(action))
			continue

		var result = _execute_action(action)
		if not result.get("success", false):
			AILogger.error("动作执行失败: %s" % result.get("error_message", "未知错误"))

func _execute_action(action: Dictionary) -> Dictionary:
	var action_type = action.get("type", "")

	match action_type:
		"select_totem":
			return _action_select_totem(action)
		"buy_unit":
			return _action_buy_unit(action)
		"sell_unit":
			return _action_sell_unit(action)
		"move_unit":
			return _action_move_unit(action)
		"refresh_shop":
			return _action_refresh_shop(action)
		"lock_shop_slot":
			return _action_lock_shop_slot(action)
		"unlock_shop_slot":
			return _action_unlock_shop_slot(action)
		"start_wave":
			return _action_start_wave(action)
		"retry_wave":
			return _action_retry_wave(action)
		"use_skill":
			return _action_use_skill(action)
		_:
			return {"success": false, "error_message": "未知动作类型: %s" % action_type}

# ===== 动作实现 =====

func _action_select_totem(action: Dictionary) -> Dictionary:
	var totem_id = action.get("totem_id", "")
	var valid_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]
	if totem_id not in valid_totems:
		return {"success": false, "error_message": "无效的图腾类型"}
	GameManager.core_type = totem_id
	GameManager.totem_confirmed.emit(totem_id)
	return {"success": true}

func _action_buy_unit(action: Dictionary) -> Dictionary:
	var shop_index = _to_int_index(action.get("shop_index", -1))
	return BoardController.buy_unit(shop_index)

func _action_sell_unit(action: Dictionary) -> Dictionary:
	var zone = action.get("zone", "")
	var pos = null
	if zone == "bench":
		pos = _to_int_index(action.get("pos", -1))
	else:
		pos = _parse_position(action.get("pos", null))
	return BoardController.sell_unit(zone, pos)

func _action_move_unit(action: Dictionary) -> Dictionary:
	var from_zone = action.get("from_zone", "")
	var to_zone = action.get("to_zone", "")
	var from_pos = _to_int_index(action.get("from_pos", -1)) if from_zone == "bench" else _parse_position(action.get("from_pos", null))
	var to_pos = _to_int_index(action.get("to_pos", -1)) if to_zone == "bench" else _parse_position(action.get("to_pos", null))
	return BoardController.try_move_unit(from_zone, from_pos, to_zone, to_pos)

func _action_refresh_shop(_action: Dictionary) -> Dictionary:
	return BoardController.refresh_shop()

func _action_lock_shop_slot(action: Dictionary) -> Dictionary:
	var shop_index = _to_int_index(action.get("shop_index", -1))
	if GameManager.session_data:
		GameManager.session_data.set_shop_slot_locked(shop_index, true)
		return {"success": true}
	return {"success": false, "error_message": "SessionData未初始化"}

func _action_unlock_shop_slot(action: Dictionary) -> Dictionary:
	var shop_index = _to_int_index(action.get("shop_index", -1))
	if GameManager.session_data:
		GameManager.session_data.set_shop_slot_locked(shop_index, false)
		return {"success": true}
	return {"success": false, "error_message": "SessionData未初始化"}

func _action_start_wave(_action: Dictionary) -> Dictionary:
	return BoardController.start_wave()

func _action_retry_wave(_action: Dictionary) -> Dictionary:
	BoardController.retry_wave()
	return {"success": true}

func _action_use_skill(action: Dictionary) -> Dictionary:
	var grid_pos = _parse_position(action.get("grid_pos", null))
	if grid_pos == null: return {"success": false, "error_message": "无效位置"}

	if GameManager.grid_manager:
		var key = "%d,%d" % [grid_pos.x, grid_pos.y]
		if GameManager.grid_manager.tiles.has(key) and GameManager.grid_manager.tiles[key].unit:
			var unit = GameManager.grid_manager.tiles[key].unit
			if unit.skill_cooldown <= 0 and GameManager.consume_resource("mana", unit.skill_mana_cost):
				unit.activate_skill()
				return {"success": true}
	return {"success": false, "error_message": "技能释放失败"}

# ===== Helpers =====

func _parse_position(pos) -> Variant:
	if pos is Vector2i: return pos
	if pos is Dictionary: return Vector2i(pos.get("x", 0), pos.get("y", 0))
	if pos is Array and pos.size() == 2: return Vector2i(pos[0], pos[1])
	return null

func _to_int_index(value) -> int:
	if value is int: return value
	if value is float: return int(value)
	return -1
