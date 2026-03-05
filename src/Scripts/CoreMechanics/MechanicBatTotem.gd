class_name MechanicBatTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var target_count: int = 3
@export var bleed_stacks_per_hit: int = 1

func _ready():
	var timer = Timer.new()
	timer.wait_time = attack_interval
	timer.autostart = false
	timer.timeout.connect(_on_totem_attack)
	add_child(timer)

	# 延迟启动定时器，确保波次开始后敌人已完全初始化
	# 修复CRASH-002: 避免在敌人尚未生成时触发攻击
	if GameManager.wave_system_manager:
		GameManager.wave_system_manager.wave_started.connect(_on_wave_started.bind(timer))

func _on_wave_started(_wave_number: int, _wave_type: String, _difficulty: float, timer: Timer):
	# 波次开始0.15秒后启动攻击定时器，确保敌人已完全初始化
	await get_tree().create_timer(0.15).timeout
	if timer and is_instance_valid(timer):
		timer.start()

func _on_totem_attack():
	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	if !is_wave_active: return

	var targets = get_nearest_enemies(target_count)

	# 记录蝙蝠图腾攻击触发日志
	if targets.size() > 0:
		var target_names = []
		var target_ids = []
		for t in targets:
			if is_instance_valid(t):
				if "type_key" in t:
					target_names.append(t.type_key)
				if t.has_method("get_instance_id"):
					target_ids.append(str(t.get_instance_id()))
		if AILogger:
			AILogger.totem_triggered("蝙蝠图腾", str(target_names), "流血攻击+%d层" % bleed_stacks_per_hit)
			# 记录[TOTEM_EFFECT]图腾特效日志
			AILogger.event("[TOTEM_EFFECT] 蝙蝠图腾 触发流血攻击 | 目标: [%s] | 施加层数: %d" % [", ".join(target_ids), bleed_stacks_per_hit])
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text("【图腾攻击】蝙蝠图腾 触发流血攻击，目标: [%s]，伤害: 25" % [", ".join(target_ids)])

	for enemy in targets:
		if is_instance_valid(enemy) and enemy.has_method("add_bleed_stacks"):
			enemy.add_bleed_stacks(bleed_stacks_per_hit, self)
			# 记录[DEBUFF]流血debuff施加日志 - 现在由Enemy.add_bleed_stacks通过AILogger.mechanic_bleed_applied统一记录
			if AILogger:
				var enemy_id = enemy.type_key if "type_key" in enemy else str(enemy.get_instance_id())
				AILogger.bleed_effect(enemy_id, 0, bleed_stacks_per_hit, "蝙蝠图腾")
			_play_bat_attack_effect(enemy)

func _play_bat_attack_effect(enemy):
	# Visual effect for bleed application
	GameManager.spawn_floating_text(enemy.global_position, "Bleed!", Color.RED, Vector2.UP)
