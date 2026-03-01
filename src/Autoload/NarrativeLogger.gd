extends Node

## Narrative Logger
## Generates natural language narratives and structured JSON arrays out of raw game signals

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_game_signals()

func _connect_game_signals():
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.enemy_died.connect(_on_enemy_died)

	GameManager.unit_devoured.connect(_on_unit_devoured)

	if get_tree().root.has_node("BoardController"):
		pass # Note: AutoLoads might not be in root, check if BoardController is global AutoLoad

	if BoardController:
		BoardController.shop_refreshed.connect(_on_shop_refreshed)
		BoardController.unit_purchased.connect(_on_unit_purchased)
		BoardController.unit_moved.connect(_on_unit_moved)
		BoardController.unit_sold.connect(_on_unit_sold)

func _on_wave_started():
	var wave = GameManager.wave
	var narrative = "【波次事件】第 %d 波战斗正式开始！" % wave
	_build_and_broadcast("WaveStarted", narrative, {"wave": wave})

func _on_wave_ended():
	var wave = GameManager.wave
	var narrative = "【波次事件】第 %d 波战斗结束，进入备战阶段。" % wave
	_build_and_broadcast("WaveEnded", narrative, {"wave": wave})

func _on_damage_dealt(unit, amount: float):
	if unit == null and amount > 0:
		var narrative = "【核心受击】图腾核心受到了 %.1f 点伤害！" % amount
		var core_health = GameManager.core_health
		var max_health = GameManager.max_core_health
		_build_and_broadcast("CoreDamaged", narrative, {
			"damage": amount,
			"health": core_health,
			"max_health": max_health
		})

func _on_enemy_died(enemy, _killer):
	if is_instance_valid(enemy):
		var type_key = enemy.type_key if "type_key" in enemy else "unknown"
		var hp = enemy.max_hp if "max_hp" in enemy else 0
		var narrative = "【敌方阵亡】敌人 %s 被消灭了。" % type_key
		_build_and_broadcast("EnemyDied", narrative, {
			"enemy_type": type_key,
			"max_hp": hp
		})

func _on_shop_refreshed(shop_units: Array):
	var shop_desc = ""
	for i in range(shop_units.size()):
		var unit_key = shop_units[i]
		if unit_key:
			var cost = 0
			if Constants.UNIT_TYPES.has(unit_key) and Constants.UNIT_TYPES[unit_key].has("cost"):
				cost = Constants.UNIT_TYPES[unit_key]["cost"]
			elif Constants.UNIT_TYPES.has(unit_key) and Constants.UNIT_TYPES[unit_key].has("levels") and Constants.UNIT_TYPES[unit_key]["levels"].has("1") and Constants.UNIT_TYPES[unit_key]["levels"]["1"].has("cost"):
				cost = Constants.UNIT_TYPES[unit_key]["levels"]["1"]["cost"]
			shop_desc += "%s(%d金币)，" % [unit_key, cost]

	if shop_desc == "":
		shop_desc = "商店为空。"
	else:
		shop_desc = shop_desc.trim_suffix("，") + "。"

	var narrative = "【商店刷新】当前商店提供: %s" % shop_desc
	_build_and_broadcast("ShopRefreshed", narrative, {"shop_units": shop_units})

func _on_unit_purchased(unit_key: String, target_zone: String, target_pos: Variant):
	var pos_str = str(target_pos)
	if target_zone == "grid" and target_pos is Vector2i:
		pos_str = "(%d, %d)" % [target_pos.x, target_pos.y]
	var narrative = "【单位购买】购买了 %s，放入了 %s 坐标 %s" % [unit_key, target_zone, pos_str]
	_build_and_broadcast("UnitPurchased", narrative, {"unit_key": unit_key, "zone": target_zone, "pos": target_pos})

func _on_unit_moved(from_zone: String, from_pos: Variant, to_zone: String, to_pos: Variant, unit_data: Dictionary):
	var type_key = unit_data.get("key", "未知")
	var to_pos_str = str(to_pos)
	if to_zone == "grid" and to_pos is Vector2i:
		to_pos_str = "(%d, %d)" % [to_pos.x, to_pos.y]

	if from_zone == "shop":
		# Likely handled by unit_purchased
		pass
	elif from_zone == "bench" and to_zone == "grid":
		var narrative = "【单位部署】%s 被放置在了坐标 %s" % [type_key, to_pos_str]
		_build_and_broadcast("UnitDeployed", narrative, {"unit_key": type_key, "pos": to_pos_str})
	elif from_zone == "grid" and to_zone == "grid":
		var narrative = "【单位移动】%s 被移动到了坐标 %s" % [type_key, to_pos_str]
		_build_and_broadcast("UnitMoved", narrative, {"unit_key": type_key, "pos": to_pos_str})
	else:
		var narrative = "【单位转移】%s 从 %s 转移到了 %s" % [type_key, from_zone, to_zone]
		_build_and_broadcast("UnitTransferred", narrative, {"unit_key": type_key, "from": from_zone, "to": to_zone})

func _on_unit_sold(zone: String, pos: Variant, gold_refund: int):
	var pos_str = str(pos)
	if zone == "grid" and pos is Vector2i:
		pos_str = "(%d, %d)" % [pos.x, pos.y]
	var narrative = "【单位出售】位于 %s %s 的单位被出售，获得 %d 金币" % [zone, pos_str, gold_refund]
	_build_and_broadcast("UnitSold", narrative, {"zone": zone, "pos": pos, "gold_refund": gold_refund})

func _on_unit_devoured(eater_unit, eaten_unit, _inherited_stats):
	var eater_name = "未知"
	var eaten_name = "未知"
	if is_instance_valid(eater_unit) and "type_key" in eater_unit:
		eater_name = eater_unit.type_key
	if is_instance_valid(eaten_unit) and "type_key" in eaten_unit:
		eaten_name = eaten_unit.type_key

	var narrative = "【单位吞噬】%s 吞噬了 %s" % [eater_name, eaten_name]
	_build_and_broadcast("UnitDevoured", narrative, {"eater": eater_name, "eaten": eaten_name})

func _build_and_broadcast(event_type: String, narrative: String, data: Dictionary):
	print("[Narrative] " + narrative)

	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text(narrative)
