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
	timer.start()

	# 连接信号以获取魂魄
	GameManager.enemy_died.connect(_on_enemy_died)
	GameManager.unit_upgraded.connect(_on_unit_upgraded)

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
		for t in targets:
			if is_instance_valid(t) and "type_key" in t:
				target_names.append(t.type_key)
		AILogger.totem_triggered("狼图腾", str(target_names), "魂魄攻击 基础%d+魂魄%d=总伤害%d" % [base_damage, soul_bonus, base_damage + soul_bonus])

	for enemy in targets:
		if is_instance_valid(enemy):
			var damage = base_damage + soul_bonus
			deal_damage(enemy, damage)
