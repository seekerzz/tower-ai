extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 石像鬼 (Gargoyle) - 蝙蝠图腾流派攻击单位
# LV.1: 石化 - 核心 HP<30% 时进入石像形态，停止主动攻击，反弹敌人 20% 伤害；>60% HP 时变回正常形态
# LV.2: 反弹敌人 20% 伤害，反弹 2 次
# LV.3: 反弹敌人 20% 伤害，反弹 3 次

enum State { NORMAL, PETRIFIED }
var current_state: State = State.NORMAL
var reflect_count: int = 0
var reflect_damage_percent: float = 0.2  # 20% 反弹伤害

# 石化/恢复的阈值
var petrify_threshold: float = 0.30  # HP < 30% 时石化
var recover_threshold: float = 0.60  # HP > 60% 时恢复

func on_setup():
	_update_mechanics()
	# Connect to SessionData signal if available
	if GameManager.session_data and GameManager.session_data.has_signal("core_health_changed"):
		GameManager.session_data.core_health_changed.connect(_check_petrify_state)
	# Initial check
	if GameManager.max_core_health > 0:
		_check_petrify_state(GameManager.core_health, GameManager.max_core_health)

func on_stats_updated():
	_update_mechanics()

func _update_mechanics():
	"""根据等级更新反弹次数"""
	var level_data = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = level_data.get("mechanics", {})

	# 从配置中读取反弹次数，如果未配置则按等级默认
	if mechanics.has("reflect_count"):
		reflect_count = mechanics["reflect_count"]
	else:
		# 默认：LV.1=1 次，LV.2=2 次，LV.3=3 次
		reflect_count = unit.level

	# 从配置中读取反弹伤害比例
	if mechanics.has("reflect_damage_percent"):
		reflect_damage_percent = mechanics["reflect_damage_percent"]
	else:
		reflect_damage_percent = 0.2  # 默认 20%

func _check_petrify_state(current_hp, max_hp):
	if max_hp <= 0: return

	var health_percent = current_hp / max_hp

	# 石化状态下的检查逻辑
	if current_state == State.NORMAL:
		if health_percent < petrify_threshold:
			_enter_petrified_state()
	elif current_state == State.PETRIFIED:
		if health_percent > recover_threshold:
			_exit_petrified_state()

func _enter_petrified_state():
	current_state = State.PETRIFIED

	# Visual effect - 变成灰色石像
	unit.modulate = Color(0.5, 0.5, 0.5)
	GameManager.spawn_floating_text(unit.global_position, "石化!", Color.GRAY)

	# 记录日志
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "石像鬼"
		AILogger.event("[SKILL] %s 进入石化形态 | 核心 HP 低于 %.0f%% | 反弹次数：%d" % [unit_name, petrify_threshold * 100, reflect_count])
		if AIManager:
			AIManager.broadcast_text("[SKILL] %s 进入石化形态 | 反弹次数：%d" % [unit_name, reflect_count])

func _exit_petrified_state():
	current_state = State.NORMAL

	# Visual effect - 恢复正常
	unit.modulate = Color.WHITE
	GameManager.spawn_floating_text(unit.global_position, "恢复!", Color.WHITE)

	# 记录日志
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "石像鬼"
		AILogger.event("[SKILL] %s 退出石化形态 | 核心 HP 高于 %.0f%%" % [unit_name, recover_threshold * 100])
		if AIManager:
			AIManager.broadcast_text("[SKILL] %s 退出石化形态" % unit_name)

func on_combat_tick(delta: float) -> bool:
	if current_state == State.PETRIFIED:
		return true  # 石化状态下停止主动攻击
	return false

func on_damage_taken(amount: float, source: Node2D) -> float:
	if current_state == State.PETRIFIED and reflect_count > 0:
		if source and is_instance_valid(source):
			var reflect_damage = amount * reflect_damage_percent
			if source.has_method("take_damage"):
				source.take_damage(reflect_damage, unit, "physical")
				reflect_count -= 1
				GameManager.spawn_floating_text(unit.global_position, "反弹!", Color.WHITE)

				# 记录反弹日志
				if AILogger:
					var unit_name = unit.type_key if unit and "type_key" in unit else "石像鬼"
					AILogger.event("[SKILL] %s 反弹伤害 | 原始伤害：%.0f | 反弹伤害：%.0f | 剩余反弹次数：%d" % [unit_name, amount, reflect_damage, reflect_count])
	return amount

func on_cleanup():
	if GameManager.session_data and GameManager.session_data.has_signal("core_health_changed"):
		if GameManager.session_data.core_health_changed.is_connected(_check_petrify_state):
			GameManager.session_data.core_health_changed.disconnect(_check_petrify_state)
