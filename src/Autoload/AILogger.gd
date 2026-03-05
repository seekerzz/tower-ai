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
const SHOW_BOSS: bool = true   # Boss战斗日志

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
const COLOR_BOSS: String = "[color=#e74c3c]"   # 红色 - Boss
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
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)
	# 确保敌人出生日志被记录到事件系统，以便测试脚本能检测到
	event("[ENEMY_SPAWN] 波次%d 敌人 %s 出生" % [wave, enemy_type])

## 核心受击日志
func core_damaged(damage: float, source: String, remaining_hp: float):
	if SHOW_COMBAT:
		var msg = "[核心受击] 受到 %.0f 点伤害，来源: %s，剩余血量: %.0f" % [damage, source, remaining_hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text("[核心受击] 受到 %.0f 点伤害，来源: %s，剩余血量: %.0f" % [damage, source, remaining_hp])

## 单位攻击日志
func unit_attack(unit_name: String, target: String, damage: float):
	if SHOW_COMBAT:
		var msg = "[单位攻击] %s 攻击 %s，造成 %.0f 点伤害" % [unit_name, target, damage]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text("[单位攻击] %s 攻击 %s，造成 %.0f 点伤害" % [unit_name, target, damage])

## 敌方阵亡日志
func enemy_died(enemy_type: String, killer: String):
	if SHOW_COMBAT:
		var msg = "[敌方阵亡] 敌人 %s 被 %s 击杀" % [enemy_type, killer]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 敌人受击日志
func enemy_hit(enemy_type: String, damage: float, source: String, remaining_hp: float):
	if SHOW_COMBAT:
		var msg = "[敌人受击] %s 受到 %.0f 点伤害，来源: %s，剩余血量: %.0f" % [enemy_type, damage, source, remaining_hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

# ===== 图腾日志 =====

## 图腾触发日志
func totem_triggered(totem_name: String, targets: String, effect: String):
	if SHOW_TOTEM:
		var msg = "[TOTEM] %s 触发攻击，目标: %s，效果: %s" % [totem_name, targets, effect]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_TOTEM, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

# ===== 状态效果日志 =====

## 状态施加日志
func status_applied(source: String, target: String, buff_name: String, duration: float):
	if SHOW_STATUS:
		var msg = "[状态施加] %s 对 %s 施加 %s，持续%.1f秒" % [source, target, buff_name, duration]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 状态伤害日志
func status_damage(buff_name: String, target: String, damage: float):
	if SHOW_STATUS:
		var msg = "[状态伤害] %s 对 %s 造成 %.2f 点伤害" % [buff_name, target, damage]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 状态结束日志
func status_ended(target: String, buff_name: String):
	if SHOW_STATUS:
		var msg = "[状态结束] %s 的 %s 效果结束" % [target, buff_name]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

# ===== 资源变化日志 =====

## 图腾资源变化日志
func totem_resource(totem_name: String, resource_type: String, delta: int, current: int):
	if SHOW_RESOURCE:
		var change_str = "+%d" % delta if delta > 0 else "%d" % delta
		var msg = "[RESOURCE] %s %s变化: %s，当前: %d" % [totem_name, resource_type, change_str, current]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_RESOURCE, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 法力变化日志
func mana_changed(delta: float, current: float, max_mana: float, source: String = ""):
	if SHOW_RESOURCE:
		var change_str = "+%.0f" % delta if delta > 0 else "%.0f" % delta
		var source_str = "，原因: %s" % source if source else ""
		var msg = "[RESOURCE] 法力回复: %s，当前法力: %.0f/%.0f%s" % [change_str, current, max_mana, source_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_RESOURCE, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 核心治疗日志
func core_heal(amount: float, current_hp: float, max_hp: float, source: String = ""):
	if SHOW_COMBAT:
		var source_str = "，来源: %s" % source if source else ""
		var msg = "[CORE_HEAL] 核心回复 %.0f HP%s，当前HP: %.0f/%.0f" % [amount, source_str, current_hp, max_hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_COMBAT, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

# ===== Buff日志 =====

## Buff施加日志
func buff_applied(target: String, buff_type: String, source: String, amount: float = 0.0):
	if SHOW_BUFF:
		var amount_str = " %.0f%%" % (amount * 100) if amount > 0 else ""
		var msg = "[BUFF] %s 对 %s 施加 %s%s" % [source, target, buff_type, amount_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BUFF, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## Buff叠加日志
func buff_stacked(target: String, buff_type: String, stacks: int, max_stacks: int = 0):
	if SHOW_BUFF:
		var max_str = "/%d" % max_stacks if max_stacks > 0 else ""
		var msg = "[BUFF_STACK] %s 的 %s 层数: %d%s" % [target, buff_type, stacks, max_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BUFF, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 流血效果日志
func bleed_effect(target: String, damage: float, stacks: int, source: String = ""):
	if SHOW_STATUS:
		var source_str = "，来源: %s" % source if source else ""
		var msg = "[DEBUFF] %s 获得流血debuff，层数: %d%s" % [target, stacks, source_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

## 中毒效果日志
func poison_effect(target: String, damage: float, stacks: int, source: String = ""):
	if SHOW_STATUS:
		var source_str = "，来源: %s" % source if source else ""
		var msg = "[DEBUFF] %s 获得中毒debuff，层数: %d%s" % [target, stacks, source_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_STATUS, msg, COLOR_RESET])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text(msg)

# ===== 机制验证专用日志 (通过 AIManager 广播给黑盒测试) =====

## 通用机制日志
func mechanic_log(msg: String):
	if SHOW_TOTEM:
		print_rich("%s%s[机制] %s%s" % [_timestamp(), COLOR_TOTEM, msg, COLOR_RESET])
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text(msg)

# ---- 蝙蝠图腾机制日志 ----

func mechanic_bleed_applied(enemy_id: String, stacks: int, duration: float):
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("【流血施加】敌人 %s 获得流血debuff，层数: %d，持续时间: %.1fs" % [enemy_id, stacks, duration])

func mechanic_bleed_damage(enemy_id: String, damage: float, remaining_stacks: int):
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("【流血伤害】敌人 %s 受到流血伤害: %.2f，剩余层数: %d" % [enemy_id, damage, remaining_stacks])

func mechanic_lifesteal_overflow(unit_id: String, overflow: int):
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("【鲜血溢出】单位 %s 吸血溢出，转化为护盾: %d" % [unit_id, overflow])

func mechanic_blood_pool_dot(enemy_id: String, damage: int, source: String):
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("【血池DOT】敌人 %s 受到血池伤害: %d，来源: %s" % [enemy_id, damage, source])

func mechanic_life_chain_drain(unit_id: String, enemy_id: String, drain_amount: int):
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("【生命链条】单位 %s 与 %s 建立生命连接，偷取生命: %d" % [unit_id, enemy_id, drain_amount])

func mechanic_vampire_lifesteal(unit_id: String, heal_amt: int, current_hp: int, max_hp: int):
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("【吸血效果】单位 %s 攻击流血敌人，吸血: %d，当前生命: %d/%d" % [unit_id, heal_amt, current_hp, max_hp])

# ---- 毒蛇图腾机制日志 ----

func mechanic_viper_attack(target_ids: Array):
	if AIManager:
		AIManager.broadcast_text("【毒液攻击】毒蛇图腾触发攻击，目标: [%s]，施加中毒" % ", ".join(target_ids))

func mechanic_poison_applied(enemy_id: String, stacks: int, damage_per_sec: float):
	if AIManager:
		AIManager.broadcast_text("【中毒施加】敌人 %s 获得中毒debuff，层数: %d，伤害/秒: %s" % [enemy_id, stacks, str(damage_per_sec)])

func mechanic_poison_stacked(enemy_id: String, current_stacks: int, max_stacks: int):
	if AIManager:
		AIManager.broadcast_text("【中毒叠加】敌人 %s 中毒层数增加，当前: %d层，最大: %d层" % [enemy_id, current_stacks, max_stacks])

func mechanic_poison_damage(enemy_id: String, damage: float, remaining_stacks: int):
	if AIManager:
		AIManager.broadcast_text("【中毒伤害】敌人 %s 受到中毒伤害: %.2f，剩余层数: %d" % [enemy_id, damage, remaining_stacks])

func mechanic_execute_trigger(enemy_id: String, stacks: int):
	if AIManager:
		AIManager.broadcast_text("【斩杀触发】敌人 %s 生命值低于15%%，触发斩杀，层数: %d" % [enemy_id, stacks])

func mechanic_plague_spread(enemy_id: String, affect_count: int):
	if AIManager:
		AIManager.broadcast_text("【瘟疫传播】中毒敌人 %s 死亡，传播中毒给周围敌人，范围: 3格，影响: %d个敌人" % [enemy_id, affect_count])

func mechanic_petrify_gaze(unit_id: String, enemy_id: String, duration: float):
	if AIManager:
		AIManager.broadcast_text("【石化凝视】美杜莎 %s 触发石化凝视，敌人 %s 石化%d秒" % [unit_id, enemy_id, int(duration)])

func mechanic_petrified_shatter(enemy_id: String, damage: float):
	if AIManager:
		AIManager.broadcast_text("【石块破碎】石化敌人 %s 破碎，造成范围伤害: %d" % [enemy_id, int(damage)])

# ---- 蝴蝶图腾机制日志 ----

func totem_orb_spawned(orb_count: int, unit_id: String):
	if AIManager:
		AIManager.broadcast_text("【法球生成】蝴蝶图腾生成环绕法球，数量: %d，环绕单位: %s" % [orb_count, unit_id])

func totem_orb_damage(enemy_id: String, damage: float, pierce_count: int):
	if AIManager:
		AIManager.broadcast_text("【法球伤害】法球命中敌人 %s，伤害: %.0f，穿透: %d个目标" % [enemy_id, damage, pierce_count])

func totem_mana_recovery(mana_recovered: float, current_mana: float, max_mana: float):
	if AIManager:
		AIManager.broadcast_text("【法力回复】法球命中回复法力: %.0f，当前法力: %.0f/%.0f" % [mana_recovered, current_mana, max_mana])

func butterfly_damage_bonus(unit_id: String, mana_cost: float, bonus_percent: float):
	if AIManager:
		AIManager.broadcast_text("【蝴蝶增伤】单位 %s 消耗法力: %.0f，附加伤害: %.0f%%" % [unit_id, mana_cost, bonus_percent])

func ice_butterfly_freeze(enemy_id: String, duration: float):
	if AIManager:
		AIManager.broadcast_text("【冻结效果】冰晶蝶攻击触发冻结，敌人 %s 冻结%.1f秒" % [enemy_id, duration])

func fairy_dragon_teleport(unit_id: String, prob_percent: float, target_x: float, target_y: float):
	if AIManager:
		AIManager.broadcast_text("【传送触发】仙女龙 %s 触发传送，概率: %.0f%%，目标位置: (%.0f,%.0f)" % [unit_id, prob_percent, target_x, target_y])

func fairy_dragon_phase_collapse(damage: float):
	if AIManager:
		AIManager.broadcast_text("【相位崩塌】仙女龙传送后触发相位崩塌，范围伤害: %.0f" % damage)

func phoenix_fire_rain(unit_id: String, range_tiles: float, duration: float, total_damage: float):
	if AIManager:
		AIManager.broadcast_text("【火雨召唤】凤凰 %s 召唤火雨，范围: %.1f格，持续: %.1f秒，总伤害: %.0f" % [unit_id, range_tiles, duration, total_damage])

func eel_lightning_chain(unit_id: String, jumps: int, total_damage: float):
	if AIManager:
		AIManager.broadcast_text("【闪电链】电鳗 %s 触发闪电链，跳跃: %d次，总伤害: %.0f" % [unit_id, jumps, total_damage])

func dragon_black_hole(unit_id: String, radius_tiles: float, duration: float):
	if AIManager:
		AIManager.broadcast_text("【黑洞生成】龙 %s 生成黑洞，吸引范围: %.1f格，持续: %.1f秒" % [unit_id, radius_tiles, duration])

# ---- 鹰图腾机制日志 ----

func mechanic_crit_triggered(unit_id: String, damage: float, crit_rate: float):
	if AIManager:
		AIManager.broadcast_text("【暴击触发】单位 %s 触发暴击，伤害: %.0f，暴击率: %.0f%%" % [unit_id, damage, crit_rate * 100])

func mechanic_crit_echo(unit_name: String, target_name: String, echo_damage: float):
	if AIManager:
		AIManager.broadcast_text("【暴击回响】单位 %s 暴击触发回响，目标: %s，回响伤害: %.0f" % [unit_name, target_name, echo_damage])

func mechanic_triple_claw(unit_name: String, target_name: String, total_damage: float):
	if AIManager:
		AIManager.broadcast_text("【三连爪击】角雕 %s 触发三连爪击，目标: %s，总伤害: %.0f" % [unit_name, target_name, total_damage])

func mechanic_dive_attack(unit_name: String, enemy_name: String, damage_bonus: int):
	if AIManager:
		AIManager.broadcast_text("【俯冲攻击】单位 %s 触发俯冲，伤害加成: %d%%，目标: %s" % [unit_name, damage_bonus, enemy_name])

func mechanic_crit_buff(unit_name: String, neighbor_name: String, bonus_percent: float, duration: float):
	if AIManager:
		AIManager.broadcast_text("【暴击率加成】猫头鹰 %s 为 %s 增加暴击率: +%.0f%%，持续: %.0f秒" % [unit_name, neighbor_name, bonus_percent * 100, duration])

func mechanic_thunder_storm(unit_name: String, range_tiles: int, duration: float, total_damage: float):
	if AIManager:
		AIManager.broadcast_text("【雷暴召唤】风暴鹰 %s 召唤雷暴，范围: %d格，持续: %.1f秒，总伤害: %.0f" % [unit_name, range_tiles, duration, total_damage])

# ---- 狼图腾机制日志 ----

func mechanic_wolf_soul(unit_id: String, soul_count: int, damage_bonus: float):
	if AIManager:
		AIManager.broadcast_text("【狼魂积攒】狼 %s 积攒魂魄，当前魂魄: %d，伤害加成: %.0f%%" % [unit_id, soul_count, damage_bonus * 100])

func mechanic_wolf_devour(unit_id: String, target_id: String, damage: float, heal: float):
	if AIManager:
		AIManager.broadcast_text("【吞噬触发】狼 %s 吞噬 %s，造成伤害: %.0f，回复生命: %.0f" % [unit_id, target_id, damage, heal])

func mechanic_sheep_clone(unit_id: String, clone_count: int):
	if AIManager:
		AIManager.broadcast_text("【羊灵克隆】羊灵 %s 触发克隆，当前克隆数: %d" % [unit_id, clone_count])

func mechanic_lion_shockwave(unit_id: String, damage: float, range_tiles: float):
	if AIManager:
		AIManager.broadcast_text("【狮子冲击波】狮子 %s 触发冲击波，伤害: %.0f，范围: %.1f格" % [unit_id, damage, range_tiles])

# ===== Boss日志 =====

## Boss登场日志
func boss_spawned(boss_name: String, phase: int, hp: float):
	if SHOW_BOSS:
		var msg = "[BOSS登场] %s 降临战场 | 阶段: %d | HP: %.0f" % [boss_name, phase, hp]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BOSS, msg, COLOR_RESET])
		if AIManager:
			AIManager.broadcast_text("【Boss登场】%s 降临战场！" % boss_name)

## Boss技能日志
func boss_skill(boss_name: String, skill_name: String, target: String = "", effect: String = ""):
	if SHOW_BOSS:
		var target_str = " | 目标: %s" % target if target else ""
		var effect_str = " | 效果: %s" % effect if effect else ""
		var msg = "[BOSS技能] %s 触发 %s%s%s" % [boss_name, skill_name, target_str, effect_str]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BOSS, msg, COLOR_RESET])
		if AIManager:
			AIManager.broadcast_text("【Boss技能】%s 触发 %s" % [boss_name, skill_name])

## Boss阶段转换日志
func boss_phase_changed(boss_name: String, old_phase: int, new_phase: int):
	if SHOW_BOSS:
		var msg = "[BOSS阶段] %s 从阶段%d 进入 阶段%d" % [boss_name, old_phase, new_phase]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BOSS, msg, COLOR_RESET])
		if AIManager:
			AIManager.broadcast_text("【Boss阶段】%s 进入第%d阶段！" % [boss_name, new_phase])

## Boss阵亡日志
func boss_died(boss_name: String, killer: String):
	if SHOW_BOSS:
		var msg = "[BOSS阵亡] %s 被 %s 击败" % [boss_name, killer]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BOSS, msg, COLOR_RESET])
		if AIManager:
			AIManager.broadcast_text("【Boss阵亡】%s 被击败！" % boss_name)

## Boss选择日志
## 格式: 【季节系统】随机选择Boss | 季节: xxx | 候选: [a, b, c] | 选中: xxx
func boss_selected(boss_name: String, season: String, boss_type: String, pool: Array = []):
	if SHOW_BOSS:
		var pool_str = "候选: %s | " % str(pool) if pool.size() > 0 else ""
		var msg = "[BOSS选择] %s季节:%s | 选中:%s (%s)" % [pool_str, season, boss_name, boss_type]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_BOSS, msg, COLOR_RESET])
		if AIManager:
			AIManager.broadcast_text("【季节系统】%sBoss: %s" % [season, boss_name])

# ===== 系统日志 =====

## 通用系统日志 - 用于季节系统、Boss生成等重要事件
func system_log(system_name: String, event_type: String, details: String):
	if SHOW_EVENT:
		var msg = "[%s] %s | %s" % [system_name, event_type, details]
		print_rich("%s%s%s%s" % [_timestamp(), COLOR_EVENT, msg, COLOR_RESET])
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text("【%s】%s | %s" % [system_name, event_type, details])
