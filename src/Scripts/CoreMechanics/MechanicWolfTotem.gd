class_name MechanicWolfTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var base_damage: int = 15

const TOTEM_ID: String = "wolf"

func _ready():
	var timer = Timer.new()
	timer.wait_time = attack_interval
	timer.timeout.connect(_on_totem_attack)
	add_child(timer)

	# 延迟启动定时器，确保波次开始后敌人已完全初始化
	# 修复CRASH-002: 避免在敌人尚未生成时触发攻击
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(_on_wave_started.bind(timer))

	# 连接信号以获取魂魄
	GameManager.enemy_died.connect(_on_enemy_died)
	GameManager.unit_upgraded.connect(_on_unit_upgraded)

func _on_wave_started(_wave_number: int, _wave_type: String, _difficulty: float, timer: Timer):
	# 波次开始0.15秒后启动攻击定时器，确保敌人已完全初始化
	await get_tree().create_timer(0.15).timeout
	if timer and is_instance_valid(timer):
		timer.start()

func _on_enemy_died(enemy, killer_unit):
	"""击杀敌人时增加魂魄"""
	TotemManager.add_resource(TOTEM_ID, 1)
	# 记录狼图腾魂魄获取日志
	if AILogger:
		var current_souls = TotemManager.get_resource(TOTEM_ID)
		var enemy_name = enemy.type_key if enemy and "type_key" in enemy else "敌人"
		var killer_name = killer_unit.type_key if killer_unit and "type_key" in killer_unit else "未知"
		AILogger.totem_resource("狼图腾", "魂魄", 1, current_souls)
		AILogger.action("[狼图腾] %s 被 %s 击杀，获得魂魄+1 (当前: %d)" % [enemy_name, killer_name, current_souls])
		# 记录[RESOURCE]魂魄收集日志
		AILogger.event("[RESOURCE] 狼图腾 魂魄收集 | 来源: %s被%s击杀 | 获得: +1 | 当前魂魄: %d" % [enemy_name, killer_name, current_souls])
		if AIManager:
			AIManager.broadcast_text("[RESOURCE] 狼图腾 魂魄收集 | 来源: %s被%s击杀 | 获得: +1 | 当前魂魄: %d" % [enemy_name, killer_name, current_souls])

func _on_unit_upgraded(unit, old_level, new_level):
	"""单位合成/升级时增加魂魄"""
	TotemManager.add_resource(TOTEM_ID, 10)
	# 记录狼图腾升级魂魄获取日志
	if AILogger:
		var current_souls = TotemManager.get_resource(TOTEM_ID)
		var unit_name = unit.type_key if unit and "type_key" in unit else "单位"
		AILogger.totem_resource("狼图腾", "魂魄", 10, current_souls)
		AILogger.action("[狼图腾] %s 升级 Lv%d→Lv%d，获得魂魄+10 (当前: %d)" % [unit_name, old_level, new_level, current_souls])

func _on_totem_attack():
	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	if !is_wave_active: return
	var targets = get_nearest_enemies(3)
	var soul_bonus = TotemManager.get_resource(TOTEM_ID)

	# 记录狼图腾攻击触发日志
	if AILogger and targets.size() > 0:
		var target_names = []
		var target_ids = []
		for t in targets:
			if is_instance_valid(t):
				if "type_key" in t:
					target_names.append(t.type_key)
				if t.has_method("get_instance_id"):
					target_ids.append(str(t.get_instance_id()))
		AILogger.totem_triggered("狼图腾", str(target_names), "魂魄攻击 基础%d+魂魄%d=总伤害%d" % [base_damage, soul_bonus, base_damage + soul_bonus])
		# 记录[TOTEM_DAMAGE]图腾伤害日志
		AILogger.event("[TOTEM_DAMAGE] 狼图腾 对 %d个敌人 造成 %d 伤害 (基础%d+魂魄%d)" % [targets.size(), base_damage + soul_bonus, base_damage, soul_bonus])
		if AIManager:
			AIManager.broadcast_text("[TOTEM_DAMAGE] 狼图腾 对 %d个敌人 造成 %d 伤害 (基础%d+魂魄%d)" % [targets.size(), base_damage + soul_bonus, base_damage, soul_bonus])

	for enemy in targets:
		if is_instance_valid(enemy):
			var damage = base_damage + soul_bonus
			deal_damage(enemy, damage)
