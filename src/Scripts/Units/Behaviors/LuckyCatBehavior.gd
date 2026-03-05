extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 金蟾/招财猫 - 每波产金
# 设计文档: 产金：每波获得15金币

var gold_per_wave: int = 15
var wave_counter: int = 0

func _ready():
	super._ready()
	# 连接波次结束信号
	if GameManager.has_signal("wave_ended"):
		GameManager.wave_ended.connect(_on_wave_ended)

func _on_wave_ended(_wave_number: int, _wave_type: String, _result: Dictionary):
	# 每波结束获得金币
	var gold_amount = gold_per_wave * unit.level  # Lv.1=15, Lv.2=30, Lv.3=45
	GameManager.add_gold(gold_amount)
	wave_counter += 1

	# 显示提示
	GameManager.spawn_floating_text(unit.global_position, "+%d💰" % gold_amount, Color.GOLD)

	# 日志
	if AILogger:
		AILogger.event("[RESOURCE] 金蟾 产金 | 波次: %d | 获得金币: %d | 总计波次: %d" % [_wave_number, gold_amount, wave_counter])
	if AIManager:
		AIManager.broadcast_text("【产金】金蟾产出 %d 金币（Lv.%d）" % [gold_amount, unit.level])

func on_cleanup():
	# 断开信号
	if GameManager.has_signal("wave_ended"):
		if GameManager.wave_ended.is_connected(_on_wave_ended):
			GameManager.wave_ended.disconnect(_on_wave_ended)
	super.on_cleanup()

# 获取状态
func get_status() -> Dictionary:
	return {
		"gold_per_wave": gold_per_wave * unit.level,
		"total_waves": wave_counter,
		"total_gold_earned": gold_per_wave * wave_counter * unit.level
	}
