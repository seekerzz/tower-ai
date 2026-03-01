extends Node

signal action_executed(action_data: Dictionary, success: bool, result_data: Dictionary)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[ActionDispatcher] initialized")

func execute_action(action: Dictionary) -> Dictionary:
	var action_type = action.get("type", "")
	var result = {"success": false, "error_message": "Unknown action type: %s" % action_type}

	if NarrativeLogger:
		NarrativeLogger.log_action("ActionDispatcher received action: %s" % action_type, action)

	match action_type:
		"buy_unit":
			result = _action_buy_unit(action)
		"sell_unit":
			result = _action_sell_unit(action)
		"move_unit":
			result = _action_move_unit(action)
		"refresh_shop":
			result = _action_refresh_shop(action)
		"start_wave":
			result = _action_start_wave(action)
		"lock_shop_slot":
			result = _action_lock_shop_slot(action)
		"unlock_shop_slot":
			result = _action_unlock_shop_slot(action)
		"use_skill":
			result = _action_use_skill(action)
		# Fallback to AIActionExecutor style for cheat commands and info queries
		"cheat_add_gold", "cheat_add_mana", "cheat_spawn_unit", "cheat_set_time_scale", "cheat_set_shop_unit", "get_unit_info", "select_totem", "retry_wave":
			if AIActionExecutor:
				result = AIActionExecutor._execute_action(action)

	action_executed.emit(action, result.success, result)
	return result

func _action_buy_unit(action: Dictionary) -> Dictionary:
	var shop_index = _to_int_index(action.get("shop_index", -1))
	var unit_key = action.get("unit_key", "")

	if BoardController:
		var result = BoardController.buy_unit(shop_index, unit_key)
		if result.success and NarrativeLogger:
			var cost = 0
			if Constants.UNIT_TYPES.has(unit_key):
				cost = Constants.UNIT_TYPES[unit_key].get("cost", 0)
			NarrativeLogger.log_action("【动作】花费 %d 金币购买了 %s" % [cost, unit_key], {"action": action, "result": result})
		return result
	return {"success": false, "error_message": "BoardController not found"}

func _action_sell_unit(action: Dictionary) -> Dictionary:
	var zone = action.get("zone", "")
	var pos = action.get("pos", null)

	var parsed_pos = _parse_position(pos) if zone == "grid" else _to_int_index(pos)

	if BoardController:
		var unit_data = BoardController._get_unit_at(zone, parsed_pos)
		var unit_key = unit_data.get("key", "unknown") if unit_data else "unknown"
		var result = BoardController.sell_unit(zone, parsed_pos)
		if result.success and NarrativeLogger:
			NarrativeLogger.log_action("【动作】出售了位于 %s 的 %s" % [zone, unit_key], {"action": action, "result": result})
		return result
	return {"success": false, "error_message": "BoardController not found"}

func _action_move_unit(action: Dictionary) -> Dictionary:
	var from_zone = action.get("from_zone", "")
	var to_zone = action.get("to_zone", "")

	var from_pos = _parse_position(action.get("from_pos")) if from_zone == "grid" else _to_int_index(action.get("from_pos"))
	var to_pos = _parse_position(action.get("to_pos")) if to_zone == "grid" else _to_int_index(action.get("to_pos"))

	if BoardController:
		var result = BoardController.try_move_unit(from_zone, from_pos, to_zone, to_pos)
		if result.success and NarrativeLogger:
			NarrativeLogger.log_action("【动作】将单位从 %s 移动到 %s" % [from_zone, to_zone], {"action": action, "result": result})
		return result
	return {"success": false, "error_message": "BoardController not found"}

func _action_refresh_shop(action: Dictionary) -> Dictionary:
	if BoardController:
		var result = BoardController.refresh_shop()
		if result.success and NarrativeLogger:
			NarrativeLogger.log_action("【动作】刷新了商店", {"action": action, "result": result})
		return result
	return {"success": false, "error_message": "BoardController not found"}

func _action_start_wave(action: Dictionary) -> Dictionary:
	if BoardController:
		var result = BoardController.start_wave()
		if result.success and NarrativeLogger:
			NarrativeLogger.log_action("【动作】开始了新波次", {"action": action, "result": result})
		return result
	return {"success": false, "error_message": "BoardController not found"}

func _action_lock_shop_slot(action: Dictionary) -> Dictionary:
	if AIActionExecutor:
		return AIActionExecutor._action_lock_shop_slot(action)
	return {"success": false, "error_message": "AIActionExecutor not found"}

func _action_unlock_shop_slot(action: Dictionary) -> Dictionary:
	if AIActionExecutor:
		return AIActionExecutor._action_unlock_shop_slot(action)
	return {"success": false, "error_message": "AIActionExecutor not found"}

func _action_use_skill(action: Dictionary) -> Dictionary:
	if AIActionExecutor:
		return AIActionExecutor._action_use_skill(action)
	return {"success": false, "error_message": "AIActionExecutor not found"}


func _to_int_index(value) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return -1

func _parse_position(pos) -> Variant:
	if pos is Vector2i:
		return pos
	if pos is Dictionary:
		return Vector2i(pos.get("x", 0), pos.get("y", 0))
	if pos is Array and pos.size() == 2:
		return Vector2i(pos[0], pos[1])
	return null
