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

	# 使用 async 立即执行异步任务
	var t = get_tree().create_timer(0.001)
	t.timeout.connect(func():
		_async_execute_actions(actions)
	)

func _async_execute_actions(actions: Array):
	for action in actions:
		# 安全类型检查
		if not action is Dictionary:
			AILogger.error("动作格式错误: %s" % str(action))
			continue

		var result = await _execute_action(action)
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
		"skip_to_wave":
			return _action_skip_to_wave(action)
		"debug_skip_to_secondary_totem":
			return _action_debug_skip_to_secondary_totem(action)
		"select_secondary_totem":
			return _action_select_secondary_totem(action)
		"debug_skip_to_third_totem":
			return _action_debug_skip_to_third_totem(action)
		"select_third_totem":
			return _action_select_third_totem(action)
		"use_skill":
			return _action_use_skill(action)
		"reset_game":
			return _action_reset_game(action)
		"spawn_unit":
			return await _action_spawn_unit(action)
		"set_core_hp":
			return _action_set_core_hp(action)
		_:
			return {"success": false, "error_message": "未知动作类型: %s" % action_type}

# ===== 动作实现 =====

func _action_select_totem(action: Dictionary) -> Dictionary:
	var totem_id = action.get("totem_id", "")
	var valid_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]
	if totem_id not in valid_totems:
		return {"success": false, "error_message": "无效的图腾类型"}

	# FIX-VIPER-SHOP-004: 确保core_type被设置，并直接初始化游戏会话
	print("[ActionDispatcher] select_totem - setting core_type to: ", totem_id)
	GameManager.core_type = totem_id

	# 确保SessionData已初始化
	if not GameManager.session_data:
		var SessionDataScript = load("res://src/Scripts/Data/SessionData.gd")
		GameManager.session_data = SessionDataScript.new()
		print("[ActionDispatcher] select_totem - created SessionData")

	# 初始化BoardController
	if GameManager.session_data:
		BoardController.initialize(GameManager.session_data)
		print("[ActionDispatcher] select_totem - initialized BoardController")

	# 发射信号通知其他系统
	GameManager.totem_confirmed.emit(totem_id)

	# 直接刷新商店，确保使用正确的阵营过滤
	var result = BoardController.refresh_shop()
	print("[ActionDispatcher] select_totem - refresh_shop result: ", result)

	return {"success": true, "message": "已选择图腾: " + totem_id}

func _action_buy_unit(action: Dictionary) -> Dictionary:
	var shop_index = _to_int_index(action.get("shop_index", -1))
	var expected_unit_key = action.get("expected_unit_key", "")
	return BoardController.buy_unit(shop_index, expected_unit_key)

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

func _action_skip_to_wave(action: Dictionary) -> Dictionary:
	var wave = action.get("wave", 0)
	if wave <= 0:
		return {"success": false, "error_message": "无效的波次号: %d" % wave}
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.skip_to_wave(wave)
		return {"success": true, "message": "已跳转到波次 %d" % wave}
	return {"success": false, "error_message": "WaveSystemManager未初始化"}

func _action_debug_skip_to_secondary_totem(_action: Dictionary) -> Dictionary:
	"""调试功能：直接跳转到次级图腾选择阶段"""
	if not GameManager.session_data:
		return {"success": false, "error_message": "SessionData未初始化"}

	# 设置波次为6（第1个Boss波）
	GameManager.session_data.wave = 6
	# 重置次级图腾
	GameManager.session_data.secondary_totem = ""

	# 如果波次正在进行，强制结束
	if GameManager.session_data.is_wave_active:
		if GameManager.main_game and GameManager.main_game.has_method("skip_wave"):
			GameManager.main_game.skip_wave()

	# 触发次级图腾选择信号
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.secondary_totem_selection_requested.emit()

	if AIManager:
		AIManager.broadcast_text("【调试】已跳过到次级图腾选择阶段")

	return {"success": true, "message": "已跳过到次级图腾选择阶段"}

func _action_select_secondary_totem(action: Dictionary) -> Dictionary:
	"""选择次级图腾（AI使用）"""
	var totem_id = action.get("totem_id", "")
	var valid_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]

	if totem_id not in valid_totems:
		return {"success": false, "error_message": "无效的图腾类型: %s" % totem_id}

	if not GameManager.session_data:
		return {"success": false, "error_message": "SessionData未初始化"}

	# 检查是否与主图腾相同
	if totem_id == GameManager.core_type:
		return {"success": false, "error_message": "次级图腾不能与主图腾相同"}

	# 设置次级图腾
	GameManager.session_data.secondary_totem = totem_id

	# 初始化次级图腾机制
	GameManager._initialize_secondary_mechanic()

	if AIManager:
		var totem_name = totem_id.replace("_totem", "").capitalize()
		AIManager.broadcast_text("【次级图腾】AI选择了 %s 作为次级图腾！商店现在会刷新该阵营的单位。" % totem_name)

	return {"success": true, "message": "已选择次级图腾: %s" % totem_id}

func _action_debug_skip_to_third_totem(_action: Dictionary) -> Dictionary:
	"""调试功能：直接跳转到第三图腾选择阶段"""
	if not GameManager.session_data:
		return {"success": false, "error_message": "SessionData未初始化"}

	# 设置波次为12（第2个Boss波）
	GameManager.session_data.wave = 12
	# 确保有次级图腾
	if GameManager.session_data.secondary_totem == "":
		# 自动设置一个次级图腾（如果不是狼图腾则设为狼，否则设为牛）
		if GameManager.core_type == "wolf_totem":
			GameManager.session_data.secondary_totem = "cow_totem"
		else:
			GameManager.session_data.secondary_totem = "wolf_totem"
	# 重置第三图腾
	GameManager.session_data.third_totem = ""

	# 如果波次正在进行，强制结束
	if GameManager.session_data.is_wave_active:
		if GameManager.main_game and GameManager.main_game.has_method("skip_wave"):
			GameManager.main_game.skip_wave()

	# 触发第三图腾选择信号
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.third_totem_selection_requested.emit()

	if AIManager:
		AIManager.broadcast_text("【调试】已跳过到第三图腾选择阶段")

	return {"success": true, "message": "已跳过到第三图腾选择阶段"}

func _action_select_third_totem(action: Dictionary) -> Dictionary:
	"""选择第三图腾（AI使用）"""
	var totem_id = action.get("totem_id", "")
	var valid_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]

	if totem_id not in valid_totems:
		return {"success": false, "error_message": "无效的图腾类型: %s" % totem_id}

	if not GameManager.session_data:
		return {"success": false, "error_message": "SessionData未初始化"}

	# 检查是否与主图腾相同
	if totem_id == GameManager.core_type:
		return {"success": false, "error_message": "第三图腾不能与主图腾相同"}

	# 检查是否与次级图腾相同
	if totem_id == GameManager.session_data.secondary_totem:
		return {"success": false, "error_message": "第三图腾不能与次级图腾相同"}

	# 设置第三图腾
	GameManager.session_data.third_totem = totem_id

	if AIManager:
		var totem_name = totem_id.replace("_totem", "").capitalize()
		AIManager.broadcast_text("【第三图腾】AI选择了 %s 作为第三图腾！商店现在会刷新三阵营混合单位。" % totem_name)

	if AILogger:
		AILogger.event("[第三图腾] 玩家选择: %s" % totem_id)

	return {"success": true, "message": "已选择第三图腾: %s" % totem_id}

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

func _action_reset_game(_action: Dictionary) -> Dictionary:
	"""重置游戏到初始状态（作弊API）"""
	if GameManager.has_method("reset_game"):
		var result = GameManager.reset_game()
		if result:
			if AIManager:
				AIManager.broadcast_text("【作弊】游戏已重置到初始状态")
			return {"success": true, "message": "游戏已重置"}
		else:
			return {"success": false, "error_message": "游戏重置失败"}
	return {"success": false, "error_message": "reset_game方法不可用"}

func _action_spawn_unit(action: Dictionary) -> Dictionary:
	"""生成指定单位（作弊API）"""
	var unit_id = action.get("unit_id", "")
	if unit_id == "":
		return {"success": false, "error_message": "未指定unit_id"}

	var grid_pos = _parse_position(action.get("grid_pos", null))
	var unit_level = action.get("level", 1)

	print("[ActionDispatcher] spawn_unit called: unit_id=", unit_id, ", grid_pos=", grid_pos, ", level=", unit_level)

	if GameManager.has_method("spawn_unit"):
		var result
		if grid_pos != null:
			print("[ActionDispatcher] Calling GameManager.spawn_unit with grid_pos")
			result = await GameManager.spawn_unit(unit_id, grid_pos, unit_level)
		else:
			print("[ActionDispatcher] Calling GameManager.spawn_unit with auto-position")
			result = await GameManager.spawn_unit(unit_id, Vector2i(-1, -1), unit_level)

		print("[ActionDispatcher] GameManager.spawn_unit returned: ", result)

		if result:
			return {"success": true, "message": "单位 %s (Lv.%d) 已生成" % [unit_id, unit_level]}
		else:
			return {"success": false, "error_message": "生成单位 %s 失败" % unit_id}

	print("[ActionDispatcher] Error: spawn_unit method not available")
	return {"success": false, "error_message": "spawn_unit方法不可用"}

func _action_set_core_hp(action: Dictionary) -> Dictionary:
	"""设置核心血量（作弊API）"""
	var hp = action.get("hp", -1)
	if hp < 0:
		return {"success": false, "error_message": "无效的血量值: %d" % hp}

	if GameManager.session_data:
		var old_hp = GameManager.session_data.core_health
		GameManager.session_data.core_health = float(hp)
		# 同时启用上帝模式，防止核心受到伤害
		GameManager.cheat_god_mode = true
		GameManager.session_data.cheat_god_mode = true
		if AIManager:
			AIManager.broadcast_text("【作弊】核心血量已设置: %.0f → %.0f，上帝模式已启用" % [old_hp, float(hp)])
		return {"success": true, "message": "核心血量已设置为 %.0f，上帝模式已启用" % float(hp)}

	return {"success": false, "error_message": "SessionData未初始化"}

# ===== Helpers =====

func _parse_position(pos) -> Variant:
	# 安全类型检查
	if pos is Vector2i: return pos
	if pos is Dictionary: return Vector2i(pos.get("x", 0), pos.get("y", 0))
	if pos is Array and pos.size() == 2: return Vector2i(pos[0], pos[1])
	return null

func _to_int_index(value) -> int:
	# 安全类型检查
	if value is int: return value
	if value is float: return int(value)
	return -1
