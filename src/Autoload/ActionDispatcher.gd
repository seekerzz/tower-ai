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

func _on_actions_received(actions: Array, request_id: String):
	if actions.size() == 0:
		return

	AILogger.action("ActionDispatcher 开始分发 %d 个动作 (request_id=%s)" % [actions.size(), request_id])

	for i in range(actions.size()):
		var action = actions[i]
		if not action is Dictionary:
			AILogger.error("动作格式错误: %s" % str(action))
			_emit_action_feedback(request_id, i, {"type": "invalid"}, {
				"success": false,
				"error_message": "动作格式错误，必须为字典"
			})
			continue

		var result = _execute_action(action)
		_emit_action_feedback(request_id, i, action, result)

		if not result.get("success", false):
			AILogger.error("动作执行失败: %s" % result.get("error_message", "未知错误"))

func _emit_action_feedback(request_id: String, action_index: int, action: Dictionary, result: Dictionary):
	if not AIManager or not AIManager.has_method("broadcast_event"):
		return

	var payload = {
		"request_id": request_id,
		"action_index": action_index,
		"action_type": action.get("type", ""),
		"action": action,
		"result": result,
		"snapshot": {
			"wave": GameManager.wave,
			"is_wave_active": GameManager.is_wave_active,
			"gold": GameManager.gold,
			"mana": GameManager.mana,
			"core_health": GameManager.core_health,
		}
	}

	if result.get("success", false):
		AIManager.broadcast_event("ActionResult", payload, request_id)
	else:
		AIManager.broadcast_event("ActionError", payload, request_id)

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
		"cheat_set_shop_unit":
			return _action_cheat_set_shop_unit(action)
		"cheat_upgrade_unit":
			return _action_cheat_upgrade_unit(action)
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
	if AIManager and AIManager.has_method("broadcast_event"):
		AIManager.broadcast_event("TotemSelected", {"totem_id": totem_id})
	return {"success": true}

func _action_cheat_set_shop_unit(action: Dictionary) -> Dictionary:
	if not OS.is_debug_build():
		return {"success": false, "error_message": "cheat actions are disabled in non-debug builds"}

	if not GameManager.session_data:
		return {"success": false, "error_message": "SessionData未初始化"}

	var shop_index = _to_int_index(action.get("shop_index", -1))
	if shop_index < 0 or shop_index >= 4:
		return {"success": false, "error_message": "shop_index 超出范围 (0-3)"}

	var unit_key = str(action.get("unit_key", ""))
	if unit_key == "":
		return {"success": false, "error_message": "unit_key 不能为空"}

	if not Constants.UNIT_TYPES.has(unit_key):
		return {"success": false, "error_message": "未知单位类型: %s" % unit_key}

	GameManager.session_data.set_shop_unit(shop_index, unit_key)
	return {"success": true, "shop_index": shop_index, "unit_key": unit_key}

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

func _action_cheat_upgrade_unit(action: Dictionary) -> Dictionary:
	if not OS.is_debug_build():
		return {"success": false, "error_message": "cheat actions are disabled in non-debug builds"}

	var grid_pos = _parse_position(action.get("grid_pos", null))
	if grid_pos == null: return {"success": false, "error_message": "无效位置"}

	if not GameManager.session_data:
		return {"success": false, "error_message": "SessionData未初始化"}

	var unit_data = GameManager.session_data.get_grid_unit(grid_pos)
	if not unit_data:
		return {"success": false, "error_message": "该位置没有单位"}

	var new_level = unit_data.get("level", 1) + 1
	unit_data["level"] = new_level
	GameManager.session_data.set_grid_unit(grid_pos, unit_data)

	if GameManager.grid_manager:
		var key = "%d,%d" % [grid_pos.x, grid_pos.y]
		if GameManager.grid_manager.tiles.has(key):
			var tile = GameManager.grid_manager.tiles[key]
			if tile.unit and tile.unit.has_method("set_level"):
				tile.unit.set_level(new_level)

	return {"success": true, "grid_pos": {"x": grid_pos.x, "y": grid_pos.y}, "new_level": new_level}

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
