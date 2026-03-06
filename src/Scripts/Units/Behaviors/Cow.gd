extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var heal_interval: float = 5.0
var heal_timer: float = 0.0

func on_setup():
	# Level 1: 5 seconds, Level 2+: 4 seconds (per GameDesign.md)
	heal_interval = 5.0
	if unit.level >= 2:
		heal_interval = 4.0
	heal_timer = heal_interval

func on_tick(delta: float):
	heal_timer -= delta
	if heal_timer <= 0:
		heal_timer = heal_interval
		_heal_core()

func _heal_core():
	var base_heal = GameManager.max_core_health * 0.015

	if unit.level >= 3:
		var health_lost_percent = 1.0 - (GameManager.core_health / GameManager.max_core_health)
		var bonus_multiplier = 1.0 + health_lost_percent
		base_heal *= bonus_multiplier

	GameManager.heal_core(base_heal)
	unit.spawn_buff_effect("🥛")

	# 记录[COW_HEAL]奶牛动态治疗日志 - 使用测试脚本可检测的格式
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "奶牛"
		var health_lost = 1.0 - (GameManager.core_health / GameManager.max_core_health)
		var bonus_text = " (含加成)" if unit.level >= 3 and health_lost > 0 else ""
		pass
		AILogger.broadcast_log("事件", "[COW_HEAL] 奶牛动态治疗 | 回复核心: %.0f HP%s | 当前HP: %.0f/%.0f | 等级: %d" % [base_heal, bonus_text, GameManager.core_health, GameManager.max_core_health, unit.level])
		# 同时保留[HEAL]格式日志用于兼容性
		AILogger.broadcast_log("事件", "[HEAL] 奶牛动态治疗 | 回复核心: %.0f HP | 当前HP: %.0f/%.0f" % [base_heal, GameManager.core_health, GameManager.max_core_health])
		if AIManager:
			AIManager.broadcast_text("[COW_HEAL] 奶牛动态治疗 | 回复核心: %.0f HP%s" % [base_heal, bonus_text])
