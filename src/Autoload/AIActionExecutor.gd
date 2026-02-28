extends Node

## AI 动作执行器 - 解析并执行客户端发送的动作指令
## 包含严格的前置校验，防止运行时错误

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

# ===== 具体动作实现 =====

func _action_select_totem(action: Dictionary) -> Dictionary:
	var totem_id = action.get("totem_id", "")

	# 前置校验
	var valid_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]
	if totem_id not in valid_totems:
		return {"success": false, "error_message": "无效的图腾类型: %s (有效选项: %s)" % [totem_id, valid_totems]}

	# 检查是否已经在战斗中
	if GameManager.session_data and GameManager.session_data.is_wave_active:
		return {"success": false, "error_message": "战斗阶段无法更换图腾"}

	# 尝试调用当前场景的 select_totem_by_ai 方法（如果在 CoreSelection 场景中）
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("select_totem_by_ai"):
		var result = current_scene.select_totem_by_ai(totem_id)
		if result:
			AILogger.action("AI 选择了图腾: %s (通过CoreSelection)" % totem_id)
			# 注意：场景切换会在下一帧发生，所以不在这里发送状态
			# 状态会在场景加载完成后通过其他事件发送
			return {"success": true}
		else:
			return {"success": false, "error_message": "CoreSelection 拒绝选择图腾"}
	else:
		# 直接设置图腾类型（备用方案）
		GameManager.core_type = totem_id
		AILogger.action("AI 选择了图腾: %s (直接设置)" % totem_id)
		# 发送状态更新给AI
		if AIManager:
			AIManager._send_state_async("TotemSelected", {"totem_id": totem_id})
		return {"success": true}

func _action_buy_unit(action: Dictionary) -> Dictionary:
	var shop_index_raw = action.get("shop_index", -1)

	# 类型检查 - 确保 shop_index 是数字
	if not (shop_index_raw is int or shop_index_raw is float):
		return {"success": false, "error_message": "商店索引类型错误: 期望数字，得到 %s" % typeof(shop_index_raw)}

	var shop_index = _to_int_index(shop_index_raw)

	# 前置校验
	if shop_index < 0 or shop_index >= 4:
		return {"success": false, "error_message": "商店索引越界: %d (有效范围: 0-3)" % shop_index}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	if session.is_wave_active:
		return {"success": false, "error_message": "战斗阶段无法购买单位"}

	var unit_key = session.get_shop_unit(shop_index)
	if unit_key == null:
		return {"success": false, "error_message": "商店槽位 %d 为空" % shop_index}

	var proto = Constants.UNIT_TYPES.get(unit_key)
	if proto == null:
		return {"success": false, "error_message": "无效的单位类型: %s" % unit_key}

	var cost = proto.get("cost", 0)
	if not session.can_afford(cost):
		return {"success": false, "error_message": "金币不足: 需要 %d，拥有 %d" % [cost, session.gold]}

	# 检查备战区空间
	var empty_slot = _find_empty_bench_slot()
	if empty_slot == -1:
		return {"success": false, "error_message": "备战区已满"}

	# 执行购买
	var result = BoardController.buy_unit(shop_index)
	if not result:
		return {"success": false, "error_message": "BoardController.buy_unit 返回失败"}

	return {"success": true}

func _action_sell_unit(action: Dictionary) -> Dictionary:
	var zone = action.get("zone", "")
	var pos = action.get("pos", null)

	# 前置校验
	if zone != "bench" and zone != "grid":
		return {"success": false, "error_message": "无效的区域: %s (应为 'bench' 或 'grid')" % zone}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	if session.is_wave_active:
		return {"success": false, "error_message": "战斗阶段无法出售单位"}

	# 校验位置
	var unit_data = null
	if zone == "bench":
		var bench_index = _to_int_index(pos)
		if bench_index < 0 or bench_index >= Constants.BENCH_SIZE:
			return {"success": false, "error_message": "备战区索引越界: %d (有效范围: 0-%d)" % [bench_index, Constants.BENCH_SIZE - 1]}
		unit_data = session.get_bench_unit(bench_index)
	else:  # grid
		var grid_pos = _parse_position(pos)
		if grid_pos == null:
			return {"success": false, "error_message": "无效的网格位置: %s" % str(pos)}
		unit_data = session.get_grid_unit(grid_pos)

	if unit_data == null:
		return {"success": false, "error_message": "%s 位置 %s 没有单位" % [zone, str(pos)]}

	# 执行出售
	var result = BoardController.sell_unit(zone, pos)
	if not result:
		return {"success": false, "error_message": "BoardController.sell_unit 返回失败"}

	return {"success": true}

func _action_move_unit(action: Dictionary) -> Dictionary:
	var from_zone = action.get("from_zone", "")
	var from_pos = action.get("from_pos", null)
	var to_zone = action.get("to_zone", "")
	var to_pos = action.get("to_pos", null)

	# 前置校验
	if from_zone != "bench" and from_zone != "grid":
		return {"success": false, "error_message": "无效的来源区域: %s" % from_zone}
	if to_zone != "bench" and to_zone != "grid":
		return {"success": false, "error_message": "无效的目标区域: %s" % to_zone}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	if session.is_wave_active:
		return {"success": false, "error_message": "战斗阶段无法移动单位"}

	# 校验来源位置
	var unit_data = null
	if from_zone == "bench":
		var bench_index = _to_int_index(from_pos)
		AILogger.action("[DEBUG] Validating bench: from_pos=" + str(from_pos) + ", bench_index=" + str(bench_index))
		if bench_index < 0 or bench_index >= Constants.BENCH_SIZE:
			return {"success": false, "error_message": "来源备战区索引越界: %d" % bench_index}
		unit_data = session.get_bench_unit(bench_index)
		AILogger.action("[DEBUG] unit_data at bench " + str(bench_index) + ": " + str(unit_data))
	else:
		var grid_pos = _parse_position(from_pos)
		if grid_pos == null:
			return {"success": false, "error_message": "无效的来源网格位置"}
		unit_data = session.get_grid_unit(grid_pos)

	if unit_data == null:
		return {"success": false, "error_message": "来源位置没有单位"}

	# 校验目标位置
	if to_zone == "bench":
		var bench_index = _to_int_index(to_pos)
		if bench_index < 0 or bench_index >= Constants.BENCH_SIZE:
			return {"success": false, "error_message": "目标备战区索引越界: %d (有效范围: 0-%d)" % [bench_index, Constants.BENCH_SIZE - 1]}
	else:
		var grid_pos = _parse_position(to_pos)
		if grid_pos == null:
			return {"success": false, "error_message": "无效的目标网格位置: %s (期望格式: {\"x\": int, \"y\": int} 或 [x, y])" % str(to_pos)}
		# 检查网格是否可放置
		var placement_check = _check_grid_placement(grid_pos)
		if not placement_check.can_place:
			return {"success": false, "error_message": "目标网格位置 (%d,%d) 不可放置: %s" % [grid_pos.x, grid_pos.y, placement_check.reason]}

	# 转换位置格式 (JSON字典转为Vector2i，float转为int)
	if from_zone == "grid":
		from_pos = _parse_position(from_pos)
	else:  # bench
		from_pos = _to_int_index(from_pos)
	if to_zone == "grid":
		to_pos = _parse_position(to_pos)
	else:  # bench
		to_pos = _to_int_index(to_pos)

	AILogger.action("[DEBUG] move_unit: from_zone=%s, from_pos=%s, to_zone=%s, to_pos=%s" % [from_zone, str(from_pos), to_zone, str(to_pos)])
	AILogger.action("[DEBUG] from_pos type: %d, to_pos type: %d" % [typeof(from_pos), typeof(to_pos)])

	# 执行移动
	var result = BoardController.try_move_unit(from_zone, from_pos, to_zone, to_pos)
	if not result:
		return {"success": false, "error_message": "BoardController.try_move_unit 返回失败"}

	return {"success": true}

func _action_refresh_shop(action: Dictionary) -> Dictionary:
	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	if session.is_wave_active:
		return {"success": false, "error_message": "战斗阶段无法刷新商店"}

	var cost = session.shop_refresh_cost
	if not session.can_afford(cost):
		return {"success": false, "error_message": "金币不足: 需要 %d，拥有 %d" % [cost, session.gold]}

	var result = BoardController.refresh_shop()
	if not result:
		return {"success": false, "error_message": "BoardController.refresh_shop 返回失败"}

	return {"success": true}

func _action_lock_shop_slot(action: Dictionary) -> Dictionary:
	var shop_index_raw = action.get("shop_index", -1)

	# 类型检查
	if not (shop_index_raw is int or shop_index_raw is float):
		return {"success": false, "error_message": "商店索引类型错误: 期望数字，得到 %s" % typeof(shop_index_raw)}

	var shop_index = _to_int_index(shop_index_raw)

	if shop_index < 0 or shop_index >= 4:
		return {"success": false, "error_message": "商店索引越界: %d" % shop_index}

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
		return {"success": false, "error_message": "商店索引越界: %d" % shop_index}

	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	session.set_shop_slot_locked(shop_index, false)
	AILogger.action("商店槽位 %d 已解锁" % shop_index)
	return {"success": true}

func _action_start_wave(action: Dictionary) -> Dictionary:
	var session = GameManager.session_data
	if not session:
		return {"success": false, "error_message": "SessionData 未初始化"}

	if session.is_wave_active:
		return {"success": false, "error_message": "波次已在进行中"}

	var result = BoardController.start_wave()
	if not result:
		return {"success": false, "error_message": "BoardController.start_wave 返回失败"}

	return {"success": true}

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
		if not _can_place_on_grid(grid_pos):
			return {"success": false, "error_message": "网格位置 %s 不可放置" % str(pos)}
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

	# 前置校验
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

func _can_place_on_grid(grid_pos: Vector2i) -> bool:
	var result = _check_grid_placement(grid_pos)
	return result.can_place

func _check_grid_placement(grid_pos: Vector2i) -> Dictionary:
	"""检查网格位置是否可以放置单位，返回详细结果"""
	var result = {
		"can_place": false,
		"reason": ""
	}

	var grid_manager = GameManager.grid_manager
	if not grid_manager:
		result.reason = "GridManager not initialized"
		return result

	var key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if not grid_manager.tiles.has(key):
		result.reason = "tile does not exist at (%d,%d)" % [grid_pos.x, grid_pos.y]
		return result

	var tile = grid_manager.tiles[key]

	if tile.state != "unlocked":
		result.reason = "tile state is '%s' (expected 'unlocked')" % tile.state
		return result

	if tile.type == "core":
		result.reason = "tile is the core (cannot place on core)"
		return result

	if tile.unit != null:
		result.reason = "tile already has a unit"
		return result

	result.can_place = true
	result.reason = "valid"
	return result

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

	# Add context information to help debug
	var context = _build_error_context(failed_action)

	if AIManager:
		AILogger.action("正在发送 ActionError 响应...")
		# Include both error message and context
		var full_error = error_message
		if not context.is_empty():
			full_error += " | Context: %s" % JSON.stringify(context)
		AIManager.send_action_error(full_error, failed_action)
		AILogger.action("ActionError 响应已发送")
	else:
		AILogger.error("AIManager 未初始化，无法发送错误响应")

func _build_error_context(failed_action: Dictionary) -> Dictionary:
	"""构建错误上下文信息，帮助AI理解当前游戏状态"""
	var context = {}
	var action_type = failed_action.get("type", "")

	match action_type:
		"buy_unit":
			var session = GameManager.session_data
			if session:
				context["available_gold"] = session.gold
				context["shop_contents"] = _get_shop_contents()
				context["bench_full"] = _find_empty_bench_slot() == -1

		"move_unit":
			var session = GameManager.session_data
			if session:
				var to_pos = failed_action.get("to_pos")
				var to_zone = failed_action.get("to_zone", "")
				if to_zone == "grid" and to_pos != null:
					var grid_pos = _parse_position(to_pos)
					if grid_pos != null:
						context["target_grid_valid"] = _can_place_on_grid(grid_pos)
						context["target_position"] = {"x": grid_pos.x, "y": grid_pos.y}
						# Check why grid position is invalid
						context["grid_check"] = _get_grid_placement_info(grid_pos)
						# Suggest valid positions
						context["suggested_positions"] = _get_valid_grid_positions()

		"sell_unit":
			var zone = failed_action.get("zone", "")
			var pos = failed_action.get("pos")
			context["zone"] = zone
			context["position"] = pos

		"start_wave":
			var session = GameManager.session_data
			if session:
				context["is_wave_active"] = session.is_wave_active
				context["wave"] = session.wave
				context["units_on_grid"] = _get_grid_unit_count()

	return context

func _get_shop_contents() -> Array:
	var contents = []
	var session = GameManager.session_data
	if not session:
		return contents
	for i in range(4):
		var unit_key = session.get_shop_unit(i)
		contents.append(unit_key if unit_key else null)
	return contents

func _get_grid_unit_count() -> int:
	var session = GameManager.session_data
	if not session:
		return 0
	return session.grid_units.size()

func _get_grid_placement_info(grid_pos: Vector2i) -> Dictionary:
	"""获取网格位置放置检查的详细信息"""
	var info = {
		"exists": false,
		"state": "unknown",
		"type": "unknown",
		"has_unit": false,
		"can_place": false
	}

	var grid_manager = GameManager.grid_manager
	if not grid_manager:
		return info

	var key = "%d,%d" % [grid_pos.x, grid_pos.y]
	info["exists"] = grid_manager.tiles.has(key)

	if not info["exists"]:
		return info

	var tile = grid_manager.tiles[key]
	info["state"] = tile.state if tile.get("state") else "unknown"
	info["type"] = tile.type if tile.get("type") else "unknown"
	info["has_unit"] = tile.unit != null if tile.get("unit") else false
	info["can_place"] = _can_place_on_grid(grid_pos)

	return info

func _get_valid_grid_positions(max_positions: int = 5) -> Array:
	"""获取当前可用的网格位置列表"""
	var positions = []
	var grid_manager = GameManager.grid_manager
	if not grid_manager:
		return positions

	for key in grid_manager.tiles:
		if positions.size() >= max_positions:
			break
		var tile = grid_manager.tiles[key]
		if tile.state == "unlocked" and tile.type != "core" and tile.unit == null:
			positions.append({"x": tile.x, "y": tile.y})

	return positions

# ===== 公共 API =====

func get_execution_status() -> Dictionary:
	return {
		"is_executing": _is_executing,
		"current_index": _current_action_index,
		"total_actions": _current_actions.size()
	}
