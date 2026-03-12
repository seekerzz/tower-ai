extends Node

## AIEventsTracker
## 收集 GameManager 和 CombatManager 的战斗及机制信号，封装为 JSON 推送给 AI Client

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 等待一帧确保其他 Singleton 初始化完成
	await get_tree().process_frame
	_connect_game_signals()

func _connect_game_signals():
	if not GameManager:
		AILogger.error("AIEventsTracker: GameManager not found!")
		return

	# 基本战斗事件
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.enemy_hit.connect(_on_enemy_hit)
	GameManager.skill_activated.connect(_on_skill_activated)
	GameManager.skill_used.connect(_on_skill_used)

	# Buff / Debuff / 护盾等机制事件
	GameManager.debuff_applied.connect(_on_debuff_applied)
	GameManager.buff_applied.connect(_on_buff_applied)
	GameManager.shield_generated.connect(_on_shield_generated)
	GameManager.shield_absorbed.connect(_on_shield_absorbed)

	# 核心治疗/受击事件
	GameManager.core_healed.connect(_on_core_healed)

	AILogger.event("AIEventsTracker: 战斗机制信号已连接")

# ===== 核心机制回调函数 =====

func _on_damage_dealt(unit, amount: float):
	# 如果 unit 是 null，说明是核心受损；如果是实体，说明是某个单位造成的伤害
	var unit_id = _get_unit_identifier(unit)
	_broadcast("DamageDealt", {
		"source_unit": unit_id,
		"amount": amount
	})

func _on_enemy_hit(enemy, source_unit, amount: float):
	_broadcast("EnemyHit", {
		"target_enemy": _get_unit_identifier(enemy),
		"source_unit": _get_unit_identifier(source_unit),
		"amount": amount
	})

func _on_skill_activated(unit):
	_broadcast("SkillActivated", {
		"unit": _get_unit_identifier(unit)
	})

func _on_skill_used(unit, skill_id: String, target_pos: Vector2i):
	_broadcast("SkillUsed", {
		"unit": _get_unit_identifier(unit),
		"skill_id": skill_id,
		"target_pos": {"x": target_pos.x, "y": target_pos.y} if target_pos else null
	})

func _on_debuff_applied(enemy, debuff_type: String, stacks: int):
	_broadcast("DebuffApplied", {
		"target_enemy": _get_unit_identifier(enemy),
		"debuff_type": debuff_type,
		"stacks": stacks
	})

func _on_buff_applied(target_unit, buff_type: String, source_unit, amount: float):
	_broadcast("BuffApplied", {
		"target_unit": _get_unit_identifier(target_unit),
		"source_unit": _get_unit_identifier(source_unit),
		"buff_type": buff_type,
		"amount": amount
	})

func _on_shield_generated(target_unit, shield_amount: float, source_unit):
	_broadcast("ShieldGenerated", {
		"target_unit": _get_unit_identifier(target_unit),
		"source_unit": _get_unit_identifier(source_unit),
		"amount": shield_amount
	})

func _on_shield_absorbed(target_unit, damage_absorbed: float, remaining_shield: float, source_unit):
	_broadcast("ShieldAbsorbed", {
		"target_unit": _get_unit_identifier(target_unit),
		"source_unit": _get_unit_identifier(source_unit),
		"damage_absorbed": damage_absorbed,
		"remaining_shield": remaining_shield
	})

func _on_core_healed(amount: float, overheal: float):
	_broadcast("CoreHealed", {
		"amount": amount,
		"overheal": overheal,
		"current_health": GameManager.core_health,
		"max_health": GameManager.max_core_health
	})

# ===== 辅助函数 =====

func _broadcast(event_name: String, data: Dictionary):
	# 委托给 AIManager 进行 JSON 组装和 WebSocket 发送
	if AIManager and AIManager.has_method("broadcast_event"):
		AIManager.broadcast_event(event_name, data)

func _get_unit_identifier(unit) -> Dictionary:
	"""将游戏内单位对象转换为易于 JSON 序列化的标识"""
	if not is_instance_valid(unit):
		return {"type": "unknown", "id": "null"}

	var info = {
		"type": "unknown",
		"id": str(unit.get_instance_id()) if unit.has_method("get_instance_id") else "unknown"
	}

	if unit.has_method("get") and unit.get("type_key"):
		info["type"] = unit.get("type_key")
	elif unit.has_method("get") and unit.get("enemy_data"):
		info["type"] = unit.get("enemy_data").get("key", "unknown_enemy")

	if unit.has_method("get_global_position") or (unit is Node2D):
		var pos = unit.global_position
		info["position"] = {"x": pos.x, "y": pos.y}

	# 如果单位在网格上，尝试获取网格坐标
	if unit.get("grid_pos") != null and unit.grid_pos is Vector2i:
		info["grid_pos"] = {"x": unit.grid_pos.x, "y": unit.grid_pos.y}

	return info
