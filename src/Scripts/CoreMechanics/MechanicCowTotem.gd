extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var timer: Timer
const TOTEM_ID: String = "cow"

func _ready():
	timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = false
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

	# 延迟启动定时器，确保波次开始后敌人已完全初始化
	# 修复CRASH-002: 避免在敌人尚未生成时触发攻击
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(_on_wave_started)

func _on_wave_started(_wave_number: int, _wave_type: String, _difficulty: float):
	# 波次开始0.15秒后启动攻击定时器，确保敌人已完全初始化
	await get_tree().create_timer(0.15).timeout
	if timer and is_instance_valid(timer):
		timer.start()

func on_core_damaged(amount: float):
	"""核心受击时增加层数"""
	TotemManager.add_resource(TOTEM_ID, int(amount))
	# 记录牛图腾受伤充能日志（包含波次信息）
	if AILogger:
		var current_charge = TotemManager.get_resource(TOTEM_ID)
		var wave_info = GameManager.session_data.wave if GameManager.session_data else 1
		AILogger.totem_resource("牛图腾", "充能", int(amount), current_charge)
		# 额外记录详细充能信息
		AILogger.event("[牛图腾充能] 波次%d | 受到伤害: %.0f | 充能+%d | 当前充能: %d" % [
			wave_info, amount, int(amount), current_charge
		])
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text("[牛图腾充能] 波次%d | 受到伤害: %.0f | 充能+%d | 当前充能: %d" % [
				wave_info, amount, int(amount), current_charge
			])

func _on_timer_timeout():
	var hit_count = TotemManager.get_resource(TOTEM_ID)
	var damage = hit_count * 5.0
	var wave_info = GameManager.session_data.wave if GameManager.session_data else 1

	# 记录牛图腾全屏反击触发日志（包含波次信息）
	if AILogger and damage > 0:
		AILogger.totem_triggered("牛图腾", "全屏敌人", "全屏反击伤害 %.0f" % damage)
		# 额外记录详细触发信息
		AILogger.event("[牛图腾触发] 波次%d | 充能层数: %d | 反击伤害: %.0f" % [
			wave_info, hit_count, damage
		])
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text("[牛图腾触发] 波次%d | 充能层数: %d | 反击伤害: %.0f" % [
				wave_info, hit_count, damage
			])

	# 清零层数（必须在计算伤害后）
	TotemManager.clear_resource(TOTEM_ID)
	if AILogger:
		AILogger.totem_resource("牛图腾", "充能", 0, 0)

	if damage > 0:
		if GameManager.combat_manager:
			var enemies = GameManager.combat_manager.get_tree().get_nodes_in_group("enemies")
			var hit_count_actual = 0
			var kill_count = 0
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.is_node_ready():
					hit_count_actual += 1
					var old_hp = enemy.hp if "hp" in enemy else 0
					enemy.take_damage(damage, GameManager, "magic")
					if enemy.hp <= 0 and old_hp > 0:
						kill_count += 1

			# 记录[TOTEM_DAMAGE]图腾伤害日志
			if AILogger:
				AILogger.event("[TOTEM_DAMAGE] 牛图腾 对 %d个敌人 造成 %.0f 伤害，击杀 %d个" % [hit_count_actual, damage, kill_count])
				if AIManager:
					AIManager.broadcast_text("[TOTEM_DAMAGE] 牛图腾 对 %d个敌人 造成 %.0f 伤害，击杀 %d个" % [hit_count_actual, damage, kill_count])

		# Visual feedback
		GameManager.trigger_impact(Vector2.ZERO, 1.0)
		GameManager.spawn_floating_text(Vector2.ZERO, "Cow Totem: %d" % damage, Color.RED)
