extends Node

## AI 动作执行器 - 纯路由器
## 只负责解析 JSON 参数并调用 BoardController 对应方法
## 所有业务校验都在 BoardController 中进行

# ===== 执行状态 =====
var _is_executing: bool = false
var _current_action_index: int = 0
var _current_actions: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 等待一帧确保 AIManager 已初始化
	await get_tree().process_frame

	AILogger.action("动作执行器已初始化")

	# 连接 AIManager 的动作接收信号
	if AIManager:
		AIManager.action_received.connect(_on_actions_received)
		AILogger.action("已连接到 AIManager")

# ===== 动作接收 =====

func _on_actions_received(actions: Array):
	if _is_executing:
		AILogger.error("收到新动作数组，但当前仍在执行中")
		return

	_is_executing = true
	_current_actions = actions
	_current_action_index = 0

	AILogger.action("开始执行 %d 个动作" % actions.size())

	# 逐个执行动作
	var result_data = {}
	for i in range(actions.size()):
		_current_action_index = i
		var action = actions[i]

		if not action is Dictionary:
			_send_action_error("动作必须是对象", action)
			_is_executing = false
			return

		var result = _execute_action(action)
		if not result.success:
			_send_action_error(result.error_message, action)
			_is_executing = false
			return

		# 收集结果数据（如 unit_info）
		var action_type = action.get("type", "")
		if action_type == "get_unit_info" and result.has("unit_info"):
			result_data["unit_info"] = result.unit_info
		elif action_type == "use_skill":
			result_data["skill_used"] = true
			if result.has("skill"):
				result_data["skill"] = result.skill

		AILogger.action("动作 %d/%d 执行成功: %s" % [i + 1, actions.size(), action.get("type", "unknown")])

	_is_executing = false
	_current_actions = []
	AILogger.action("所有动作执行完成")

	# 发送成功响应
	if AIManager:
		AILogger.action("正在发送 ActionsCompleted 响应...")
		AIManager._send_state_async("ActionsCompleted", result_data)
		AILogger.action("ActionsCompleted 响应已发送")
	else:
		AILogger.error("AIManager 未初始化，无法发送响应")

# ===== 动作执行 =====

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
		"resume":
			return _action_resume(action)
		# 作弊指令
		"cheat_add_gold":
			return _action_cheat_add_gold(action)
		"cheat_add_mana":
			return _action_cheat_add_mana(action)
		"cheat_spawn_unit":
			return _action_cheat_spawn_unit(action)
		"cheat_set_time_scale":
			return _action_cheat_set_time_scale(action)
		"cheat_set_shop_unit":
			return _action_cheat_set_shop_unit(action)
		# 技能指令
		"use_skill":
			return _action_use_skill(action)
		"get_unit_info":
			return _action_get_unit_info(action)
		_:
			return {"success": false, "error_message": "未知动作类型: %s" % action_type}

# ===== 具体动作实现（纯路由，无业务逻辑） =====

func _action_select_totem(action: Dictionary) -> Dictionary:
	var totem_id = action.get("totem_id", "")

	# 基本参数校验（仅检查参数存在性和类型）
	var valid_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]
	if totem_id not in valid_totems:
		return {"success": false, "error_message": "无效的图腾类型: %s (有效选项: %s)" % [totem_id, valid_totems]}

	# 直接设置图腾类型，发射全局信号
	GameManager.core_type = totem_id
	AILogger.action("AI 选择了图腾: %s" % totem_id)

	# 发射全局信号，让 UI 组件监听并处理
	GameManager.totem_confirmed.emit(totem_id)

	return {"success": true}

func _action_buy_unit(action: Dictionary) -> Dictionary:
	var shop_index_raw = action.get("shop_index", -1)

	# 类型检查
	if not (shop_index_raw is int or shop_index_raw is float):
		return {"success": false, "error_message": "商店索引类型错误: 期望数字，得到 %s" % typeof(shop_index_raw)}

	var shop_index = _to_int_index(shop_index_raw)

	# 直接调用 BoardController，所有业务校验都在其中进行
	var result = BoardController.buy_unit(shop_index)
	return result

func _action_sell_unit(action: Dictionary) -> Dictionary:
	var zone = action.get("zone", "")
	var pos = action.get("pos", null)

	# 基本参数校验
	if zone != "bench" and zone != "grid":
		return {"success": false, "error_message": "无效的区域: %s (应为 'bench' 或 'grid')" % zone}

	# 转换位置格式
	var sell_pos = null
	if zone == "bench":
		sell_pos = _to_int_index(pos)
		if sell_pos < 0:
			return {"success": false, "error_message": "无效的备战区索引: %s" % str(pos)}
	else:  # grid
		sell_pos = _parse_position(pos)
		if sell_pos == null:
			return {"success": false, "error_message": "无效的网格位置: %s" % str(pos)}

	# 直接调用 BoardController，所有业务校验都在其中进行
	var result = BoardController.sell_unit(zone, sell_pos)
	return result

func _action_move_unit(action: Dictionary) -> Dictionary:
	var from_zone = action.get("from_zone", "")
	var from_pos = action.get("from_pos", null)
	var to_zone = action.get("to_zone", "")
	var to_pos = action.get("to_pos", null)

	# 基本参数校验
	if from_zone != "bench" and from_zone != "grid":
		return {"success": false, "error_message": "无效的来源区域: %s" % from_zone}
	if to_zone != "bench" and to_zone != "grid":
		return {"success": false, "error_message": "无效的目标区域: %s" % to_zone}

	# 转换位置格式
	var from_pos_typed: Variant
	var to_pos_typed: Variant

	if from_zone == "grid":
		from_pos_typed = _parse_position(from_pos)
		if from_pos_typed == null:
			return {"success": false, "error_message": "无效的来源网格位置: %s" % str(from_pos)}
	else:  # bench
		var bench_idx = _to_int_index(from_pos)
		if bench_idx < 0:
			return {"success": false, "error_message": "无效的来源备战区索引: %s" % str(from_pos)}
		from_pos_typed = bench_idx

	if to_zone == "grid":
		to_pos_typed = _parse_position(to_pos)
		if to_pos_typed == null:
			return {"success": false, "error_message": "无效的目标网格位置: %s" % str(to_pos)}
	else:  # bench
		var bench_idx = _to_int_index(to_pos)
		if bench_idx < 0:
			return {"success": false, "error_message": "无效的目标备战区索引: %s" % str(to_pos)}
		to_pos_typed = bench_idx

	AILogger.action("[DEBUG] move_unit: from_zone=%s, from_pos=%s, to_zone=%s, to_pos=%s" % [from_zone, str(from_pos_typed), to_zone, str(to_pos_typed)])

	# 直接调用 BoardController，所有业务校验都在其中进行
	var result = BoardController.try_move_unit(from_zone, from_pos_typed, to_zone, to_pos_typed)
	return result

func _action_refresh_shop(action: Dictionary) -> Dictionary:
	# 直接调用 BoardController，所有业务校验都在其中进行
	var result = BoardController.refresh_shop()
	return result

func _action_lock_shop_slot(action: Dictionary) -> Dictionary:
	var shop_index_raw = action.get("shop_index", -1)

	# 类型检查
	if not (shop_index_raw is int or shop_index_raw is float):
		return {"success": false, "error_message": "商店索引类型错误: 期望数字，得到 %s" % typeof(shop_index_raw)}

	var shop_index = _to_int_index(shop_index_raw)
	if shop_index < 0 or shop_index >= 4:
		return {"success": false, "error_message": "商店索引越界: %d (有效范围: 0-3)" % shop_index}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	session.set_shop_slot_locked(shop_index, true)
	AILogger.action("商店槽位 %d 已锁定" % shop_index)
	return {"success": true}

func _action_unlock_shop_slot(action: Dictionary) -> Dictionary:
	var shop_index_raw = action.get("shop_index", -1)

	# 类型检查
	if not (shop_index_raw is int or shop_index_raw is float):
		return {"success": false, "error_message": "商店索引类型错误: 期望数字，得到 %s" % typeof(shop_index_raw)}

	var shop_index = _to_int_index(shop_index_raw)
	if shop_index < 0 or shop_index >= 4:
		return {"success": false, "error_message": "商店索引越界: %d (有效范围: 0-3)" % shop_index}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	session.set_shop_slot_locked(shop_index, false)
	AILogger.action("商店槽位 %d 已解锁" % shop_index)
	return {"success": true}

func _action_start_wave(action: Dictionary) -> Dictionary:
	# 直接调用 BoardController，所有业务校验都在其中进行
	var result = BoardController.start_wave()
	return result

func _action_retry_wave(action: Dictionary) -> Dictionary:
	BoardController.retry_wave()
	return {"success": true}

func _action_resume(action: Dictionary) -> Dictionary:
	var wait_time = action.get("wait_time", 0.0)

	if wait_time < 0:
		return {"success": false, "error_message": "wait_time 不能为负数"}

	if AIManager:
		AIManager.resume_game(wait_time)

	return {"success": true}

# ===== 作弊指令 =====

func _action_cheat_add_gold(action: Dictionary) -> Dictionary:
	var amount = action.get("amount", 0)

	if amount <= 0:
		return {"success": false, "error_message": "amount 必须为正数"}

	GameManager.add_gold(amount)
	AILogger.action("[作弊] 添加 %d 金币" % amount)
	return {"success": true}

func _action_cheat_add_mana(action: Dictionary) -> Dictionary:
	var amount = action.get("amount", 0.0)

	if amount <= 0:
		return {"success": false, "error_message": "amount 必须为正数"}

	var session = GameManager.session_data
	if session:
		session.mana = min(session.max_mana, session.mana + amount)
		AILogger.action("[作弊] 添加 %.1f 法力" % amount)
		return {"success": true}
	return {"success": false, "error_message": "SessionData 未初始化"}

func _action_cheat_spawn_unit(action: Dictionary) -> Dictionary:
	var unit_type = action.get("unit_type", "")
	var level = action.get("level", 1)
	var zone = action.get("zone", "bench")
	var pos = action.get("pos", null)

	if not Constants.UNIT_TYPES.has(unit_type):
		return {"success": false, "error_message": "无效的单位类型: %s" % unit_type}

	if level < 1 or level > 3:
		return {"success": false, "error_message": "等级必须在 1-3 之间"}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	var unit_data = {
		"key": unit_type,
		"level": level,
		"grid_pos": null
	}

	if zone == "bench":
		var bench_index = _to_int_index(pos) if pos != null else _find_empty_bench_slot()
		if bench_index == -1:
			return {"success": false, "error_message": "备战区已满"}
		session.set_bench_unit(bench_index, unit_data)
		AILogger.action("[作弊] 生成单位 %s LV%d 到备战区槽位 %d" % [unit_type, level, bench_index])
	elif zone == "grid":
		var grid_pos = _parse_position(pos)
		if grid_pos == null:
			return {"success": false, "error_message": "无效的网格位置"}
		session.set_grid_unit(grid_pos, unit_data)
		if GameManager.grid_manager:
			GameManager.grid_manager.place_unit(unit_type, grid_pos.x, grid_pos.y)
		AILogger.action("[作弊] 生成单位 %s LV%d 到网格 %s" % [unit_type, level, str(pos)])
	else:
		return {"success": false, "error_message": "无效的区域: %s" % zone}

	return {"success": true}

func _action_cheat_set_time_scale(action: Dictionary) -> Dictionary:
	var scale = action.get("scale", 1.0)

	if scale < 0.1 or scale > 10.0:
		return {"success": false, "error_message": "time_scale 必须在 0.1-10.0 之间"}

	Engine.time_scale = scale
	AILogger.action("[作弊] 设置 time_scale = %.2f" % scale)
	return {"success": true}

func _action_cheat_set_shop_unit(action: Dictionary) -> Dictionary:
	var shop_index_raw = action.get("shop_index", -1)
	var unit_key = action.get("unit_key", "")

	# 类型检查
	if not (shop_index_raw is int or shop_index_raw is float):
		return {"success": false, "error_message": "商店索引类型错误: 期望数字，得到 %s" % typeof(shop_index_raw)}

	var shop_index = _to_int_index(shop_index_raw)

	# 基本参数校验
	if shop_index < 0 or shop_index >= 4:
		return {"success": false, "error_message": "商店索引越界: %d (有效范围: 0-3)" % shop_index}

	if not Constants.UNIT_TYPES.has(unit_key):
		return {"success": false, "error_message": "无效的单位类型: %s" % unit_key}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	# 设置商店单位
	session.set_shop_unit(shop_index, unit_key)
	AILogger.action("[作弊] 设置商店槽位 %d 为单位 %s" % [shop_index, unit_key])

	return {"success": true}

func _action_use_skill(action: Dictionary) -> Dictionary:
	var grid_pos = _parse_position(action.get("grid_pos", null))
	var skill_index = action.get("skill_index", 0)

	if grid_pos == null:
		return {"success": false, "error_message": "无效的技能目标位置"}

	var grid_manager = GameManager.grid_manager
	if not grid_manager:
		return {"success": false, "error_message": "GridManager 未初始化"}

	var key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if not grid_manager.tiles.has(key):
		return {"success": false, "error_message": "目标位置 (%d,%d) 不存在" % [grid_pos.x, grid_pos.y]}

	var tile = grid_manager.tiles[key]
	if not tile.unit:
		return {"success": false, "error_message": "目标位置没有单位"}

	var unit = tile.unit
	if not unit.unit_data.has("skill"):
		return {"success": false, "error_message": "单位 %s 没有技能" % unit.type_key}

	if unit.skill_cooldown > 0:
		return {"success": false, "error_message": "技能冷却中: %.1f秒" % unit.skill_cooldown}

	var final_cost = unit.skill_mana_cost

	if not GameManager.consume_resource("mana", final_cost):
		return {"success": false, "error_message": "法力不足: 需要 %.0f" % final_cost}

	# Activate the skill
	unit.activate_skill()
	AILogger.action("单位 %s 在 (%d,%d) 使用了技能" % [unit.type_key, grid_pos.x, grid_pos.y])

	return {"success": true, "skill": unit.unit_data.skill, "cost": final_cost}

func _action_get_unit_info(action: Dictionary) -> Dictionary:
	var grid_pos = _parse_position(action.get("grid_pos", null))
	var zone = action.get("zone", "grid")
	var pos = action.get("pos", null)

	var unit = null

	if zone == "grid":
		if grid_pos == null:
			return {"success": false, "error_message": "无效的位置"}
		var grid_manager = GameManager.grid_manager
		if not grid_manager:
			return {"success": false, "error_message": "GridManager 未初始化"}
		var key = "%d,%d" % [grid_pos.x, grid_pos.y]
		if grid_manager.tiles.has(key) and grid_manager.tiles[key].unit:
			unit = grid_manager.tiles[key].unit
	elif zone == "bench":
		var bench_index = _to_int_index(pos)
		if bench_index >= 0 and bench_index < Constants.BENCH_SIZE:
			var session = GameManager.session_data
			if session:
				var unit_data = session.get_bench_unit(bench_index)
				if unit_data:
					return {"success": true, "unit": unit_data}
			return {"success": false, "error_message": "备战区位置 %d 没有单位" % bench_index}

	if not unit:
		return {"success": false, "error_message": "未找到单位"}

	# Build unit info
	var unit_info = {
		"type_key": unit.type_key,
		"level": unit.level,
		"hp": unit.current_hp,
		"max_hp": unit.max_hp,
		"damage": unit.damage,
		"atk_speed": unit.atk_speed,
		"range": unit.range_val,
		"crit_rate": unit.crit_rate,
	}

	# Add skill info if available
	if unit.unit_data.has("skill"):
		unit_info["skill"] = {
			"name": unit.unit_data.skill,
			"cooldown": unit.skill_cooldown,
			"max_cooldown": unit.unit_data.get("skillCd", 10.0),
			"mana_cost": unit.skill_mana_cost,
			"ready": unit.skill_cooldown <= 0 and GameManager.mana >= unit.skill_mana_cost
		}

	# Add buffs info
	if unit.active_buffs.size() > 0:
		unit_info["buffs"] = unit.active_buffs.duplicate()

	if unit.temporary_buffs.size() > 0:
		unit_info["temporary_buffs"] = []
		for buff in unit.temporary_buffs:
			unit_info["temporary_buffs"].append({
				"stat": buff.get("stat", "unknown"),
				"amount": buff.get("amount", 0),
				"duration": buff.get("duration", 0)
			})

	AILogger.action("获取单位信息: %s 在 (%d,%d)" % [unit.type_key, unit.grid_pos.x if unit.grid_pos else -1, unit.grid_pos.y if unit.grid_pos else -1])

	return {"success": true, "unit_info": unit_info}

# ===== 辅助函数 =====

func _find_empty_bench_slot() -> int:
	var session = GameManager.session_data
	if not session:
		return -1
	for i in range(Constants.BENCH_SIZE):
		if session.get_bench_unit(i) == null:
			return i
	return -1

func _parse_position(pos) -> Variant:
	if pos is Vector2i:
		return pos
	if pos is Dictionary:
		return Vector2i(pos.get("x", 0), pos.get("y", 0))
	if pos is Array and pos.size() == 2:
		return Vector2i(pos[0], pos[1])
	return null

func _to_int_index(value) -> int:
	"""Convert a value (int or float from JSON) to an integer index.

	JSON numbers are parsed as floats in Godot, so we need to handle both types.
	Returns -1 if the value cannot be converted to a valid index."""
	if value is int:
		return value
	if value is float:
		return int(value)
	return -1

func _send_action_error(error_message: String, failed_action: Dictionary):
	AILogger.error("动作执行失败: %s" % error_message)
	AILogger.error("失败动作详情: %s" % JSON.stringify(failed_action))

	if AIManager:
		AILogger.action("正在发送 ActionError 响应...")
		AIManager.send_action_error(error_message, failed_action)
		AILogger.action("ActionError 响应已发送")
	else:
		AILogger.error("AIManager 未初始化，无法发送错误响应")

# ===== 公共 API =====

func get_execution_status() -> Dictionary:
	return {
		"is_executing": _is_executing,
		"current_index": _current_action_index,
		"total_actions": _current_actions.size()
	}
