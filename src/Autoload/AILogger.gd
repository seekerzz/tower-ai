extends Node

## AI 日志系统 - 分级中文日志打印
## 全局自动加载单例

# ===== 日志开关配置 =====
const SHOW_NET: bool = true    # 网络底层连接与原始 JSON 收发
const SHOW_EVENT: bool = true  # 状态发送与游戏暂停事件
const SHOW_ACTION: bool = true # AI 动作解析与执行结果
const SHOW_ERROR: bool = true  # 动作执行拦截与报错信息
const SHOW_COMBAT: bool = true # 战斗日志：敌人出生、受击、阵亡等
const SHOW_TOTEM: bool = true  # 图腾触发日志
const SHOW_STATUS: bool = true # 状态效果日志
const SHOW_RESOURCE: bool = true # 资源变化日志（魂魄、充能、法力等）
const SHOW_BUFF: bool = true   # Buff施加和传播日志

# ===== 颜色配置 =====
const COLOR_NET: String = "[color=#3498db]"    # 蓝色 - 网络
const COLOR_EVENT: String = "[color=#2ecc71]"  # 绿色 - 事件
const COLOR_ACTION: String = "[color=#f39c12]" # 橙色 - 动作
const COLOR_ERROR: String = "[color=#e74c3c]"  # 红色 - 错误
const COLOR_COMBAT: String = "[color=#9b59b6]" # 紫色 - 战斗
const COLOR_TOTEM: String = "[color=#1abc9c]"  # 青色 - 图腾
const COLOR_STATUS: String = "[color=#e67e22]" # 深橙 - 状态
const COLOR_RESOURCE: String = "[color=#9b59b6]" # 紫色 - 资源
const COLOR_BUFF: String = "[color=#f1c40f]"   # 黄色 - Buff
const COLOR_RESET: String = "[/color]"

# ===== 日志级别 =====
enum LogLevel { NET, EVENT, ACTION, ERROR, COMBAT, TOTEM, STATUS }

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[AILogger] AI 日志系统已初始化")

## 获取带时间戳的前缀
func _timestamp() -> String:
	var time = Time.get_time_dict_from_system()
	var ms = (Time.get_ticks_msec() % 1000)
	return "[%02d:%02d:%02d.%03d]" % [time.hour, time.minute, time.second, ms]

## 网络日志 - 连接与 JSON 收发
func net(message: String):
	if SHOW_NET:
		print_rich("%s%s[网络] %s%s" % [_timestamp(), COLOR_NET, message, COLOR_RESET])

## 事件日志 - 状态发送与游戏暂停
func event(message: String):
	if SHOW_EVENT:
		print_rich("%s%s[事件] %s%s" % [_timestamp(), COLOR_EVENT, message, COLOR_RESET])

## 动作日志 - AI 动作解析与执行
func action(message: String):
	if SHOW_ACTION:
		print_rich("%s%s[动作] %s%s" % [_timestamp(), COLOR_ACTION, message, COLOR_RESET])

## 错误日志 - 动作执行拦截与报错
func error(message: String):
	if SHOW_ERROR:
		print_rich("%s%s[错误] %s%s" % [_timestamp(), COLOR_ERROR, message, COLOR_RESET])

## 原始 JSON 日志（网络层）
func net_json(direction: String, json_data: Variant):
	if SHOW_NET:
		var json_str = JSON.stringify(json_data)
		if json_str.length() > 200:
			json_str = json_str.substr(0, 200) + "..."
		print_rich("%s%s[网络][%s] %s%s" % [_timestamp(), COLOR_NET, direction, json_str, COLOR_RESET])

## 连接状态日志
func net_connection(status: String, details: String = ""):
	if SHOW_NET:
		var msg = "[连接] " + status
		if details != "":
			msg += " - " + details
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_NET, msg, COLOR_RESET])

# ===== 战斗日志 =====

## 敌人出生日志
func enemy_spawned(wave: int, enemy_type: String, hp: float, pos: Vector2):
	if SHOW_COMBAT:
		var msg = "[波次%d] 敌人 %s 出生，血量%.0f，位置(%.0f, %.0f)" % [wave, enemy_type, hp, pos.x, pos.y]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])

## 核心受击日志
func core_damaged(damage: float, source: String, remaining_hp: float):
	if SHOW_COMBAT:
		var msg = "[核心受击] 受到 %.0f 点伤害，来源: %s，剩余血量: %.0f" % [damage, source, remaining_hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])

## 单位攻击日志
func unit_attack(unit_name: String, target: String, damage: float):
	if SHOW_COMBAT:
		var msg = "[单位攻击] %s 攻击 %s，造成 %.0f 点伤害" % [unit_name, target, damage]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])

## 敌方阵亡日志
func enemy_died(enemy_type: String, killer: String):
	if SHOW_COMBAT:
		var msg = "[敌方阵亡] 敌人 %s 被 %s 击杀" % [enemy_type, killer]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])

## 敌人受击日志
func enemy_hit(enemy_type: String, damage: float, source: String, remaining_hp: float):
	if SHOW_COMBAT:
		var msg = "[敌人受击] %s 受到 %.0f 点伤害，来源: %s，剩余血量: %.0f" % [enemy_type, damage, source, remaining_hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])

# ===== 图腾日志 =====

## 图腾触发日志
func totem_triggered(totem_name: String, targets: String, effect: String):
	if SHOW_TOTEM:
		var msg = "[图腾触发] %s 触发，目标: %s，效果: %s" % [totem_name, targets, effect]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_TOTEM, msg, COLOR_RESET])

# ===== 状态效果日志 =====

## 状态施加日志
func status_applied(source: String, target: String, buff_name: String, duration: float):
	if SHOW_STATUS:
		var msg = "[状态施加] %s 对 %s 施加 %s，持续%.1f秒" % [source, target, buff_name, duration]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])

## 状态伤害日志
func status_damage(buff_name: String, target: String, damage: float):
	if SHOW_STATUS:
		var msg = "[状态伤害] %s 对 %s 造成 %.0f 点伤害" % [buff_name, target, damage]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])

## 状态结束日志
func status_ended(target: String, buff_name: String):
	if SHOW_STATUS:
		var msg = "[状态结束] %s 的 %s 效果结束" % [target, buff_name]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])

# ===== 资源变化日志 =====

## 图腾资源变化日志
func totem_resource(totem_name: String, resource_type: String, delta: int, current: int):
	if SHOW_RESOURCE:
		var change_str = "+%d" % delta if delta > 0 else "%d" % delta
		var msg = "[图腾资源] %s %s变化: %s, 当前%s: %d" % [totem_name, resource_type, change_str, resource_type, current]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_RESOURCE, msg, COLOR_RESET])

## 法力变化日志
func mana_changed(delta: float, current: float, max_mana: float, source: String = ""):
	if SHOW_RESOURCE:
		var change_str = "+%.0f" % delta if delta > 0 else "%.0f" % delta
		var source_str = " (%s)" % source if source else ""
		var msg = "[法力变化] %s%s, 当前: %.0f/%.0f" % [change_str, source_str, current, max_mana]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_RESOURCE, msg, COLOR_RESET])

## 核心治疗日志
func core_heal(amount: float, current_hp: float, max_hp: float, source: String = ""):
	if SHOW_COMBAT:
		var source_str = " (%s)" % source if source else ""
		var msg = "[核心治疗] 回复 %.0f HP%s, 当前: %.0f/%.0f" % [amount, source_str, current_hp, max_hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])

# ===== 蝴蝶图腾及相关单位机制日志 =====

## 1. 法球生成日志
func totem_orb_spawned(orb_count: int, unit_id: String):
	if AIManager:
		AIManager.broadcast_text("【法球生成】蝴蝶图腾生成环绕法球，数量: %d，环绕单位: %s" % [orb_count, unit_id])

## 2. 法球伤害日志
func totem_orb_damage(enemy_id: String, damage: float, pierce_count: int):
	if AIManager:
		AIManager.broadcast_text("【法球伤害】法球命中敌人 %s，伤害: %.0f，穿透: %d个目标" % [enemy_id, damage, pierce_count])

## 3. 法力回复日志
func totem_mana_recovery(mana_recovered: float, current_mana: float, max_mana: float):
	if AIManager:
		AIManager.broadcast_text("【法力回复】法球命中回复法力: %.0f，当前法力: %.0f/%.0f" % [mana_recovered, current_mana, max_mana])

## 4. 蝴蝶增伤日志
func butterfly_damage_bonus(unit_id: String, mana_cost: float, bonus_percent: float):
	if AIManager:
		AIManager.broadcast_text("【蝴蝶增伤】单位 %s 消耗法力: %.0f，附加伤害: %.0f%%" % [unit_id, mana_cost, bonus_percent])

## 5. 冻结效果日志
func ice_butterfly_freeze(enemy_id: String, duration: float):
	if AIManager:
		AIManager.broadcast_text("【冻结效果】冰晶蝶攻击触发冻结，敌人 %s 冻结%.1f秒" % [enemy_id, duration])

## 6. 传送触发日志
func fairy_dragon_teleport(unit_id: String, prob_percent: float, target_x: float, target_y: float):
	if AIManager:
		AIManager.broadcast_text("【传送触发】仙女龙 %s 触发传送，概率: %.0f%%，目标位置: (%.0f,%.0f)" % [unit_id, prob_percent, target_x, target_y])

## 7. 相位崩塌日志
func fairy_dragon_phase_collapse(damage: float):
	if AIManager:
		AIManager.broadcast_text("【相位崩塌】仙女龙传送后触发相位崩塌，范围伤害: %.0f" % damage)

## 8. 火雨召唤日志
func phoenix_fire_rain(unit_id: String, range_tiles: float, duration: float, total_damage: float):
	if AIManager:
		AIManager.broadcast_text("【火雨召唤】凤凰 %s 召唤火雨，范围: %.1f格，持续: %.1f秒，总伤害: %.0f" % [unit_id, range_tiles, duration, total_damage])

## 9. 闪电链日志
func eel_lightning_chain(unit_id: String, jumps: int, total_damage: float):
	if AIManager:
		AIManager.broadcast_text("【闪电链】电鳗 %s 触发闪电链，跳跃: %d次，总伤害: %.0f" % [unit_id, jumps, total_damage])

## 10. 黑洞生成日志
func dragon_black_hole(unit_id: String, radius_tiles: float, duration: float):
	if AIManager:
		AIManager.broadcast_text("【黑洞生成】龙 %s 生成黑洞，吸引范围: %.1f格，持续: %.1f秒" % [unit_id, radius_tiles, duration])


# ===== Buff日志 =====

## Buff施加日志
func buff_applied(target: String, buff_type: String, source: String, amount: float = 0.0):
	if SHOW_BUFF:
		var amount_str = " %.0f%%" % (amount * 100) if amount > 0 else ""
		var msg = "[Buff施加] %s 获得 %s%s (来源: %s)" % [target, buff_type, amount_str, source]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BUFF, msg, COLOR_RESET])

## Buff叠加日志
func buff_stacked(target: String, buff_type: String, stacks: int, max_stacks: int = 0):
	if SHOW_BUFF:
		var max_str = "/%d" % max_stacks if max_stacks > 0 else ""
		var msg = "[Buff叠加] %s %s层数: %d%s" % [target, buff_type, stacks, max_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BUFF, msg, COLOR_RESET])

## 流血效果日志
func bleed_effect(target: String, damage: float, stacks: int, source: String = ""):
	if SHOW_STATUS:
		var source_str = " (%s)" % source if source else ""
		var msg = "[流血效果] %s受到 %.0f 伤害, 层数: %d%s" % [target, damage, stacks, source_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])

## 中毒效果日志
func poison_effect(target: String, damage: float, stacks: int, source: String = ""):
	if SHOW_STATUS:
		var source_str = " (%s)" % source if source else ""
		var msg = "[中毒效果] %s受到 %.0f 伤害, 层数: %d%s" % [target, damage, stacks, source_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])
