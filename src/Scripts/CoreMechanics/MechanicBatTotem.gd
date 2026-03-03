class_name MechanicBatTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var target_count: int = 3
@export var bleed_stacks_per_hit: int = 1

func _ready():
	var timer = Timer.new()
	timer.wait_time = attack_interval
	timer.autostart = true
	timer.timeout.connect(_on_totem_attack)
	add_child(timer)

func _on_totem_attack():
	var is_wave_active = GameManager.session_data.is_wave_active if GameManager.session_data else false
	if !is_wave_active: return

	var targets = get_nearest_enemies(target_count)

	# 记录蝙蝠图腾攻击触发日志
	if AILogger and targets.size() > 0:
		var target_names = []
		var target_ids = []
		for t in targets:
			if is_instance_valid(t):
				if "type_key" in t:
					target_names.append(t.type_key)
				if t.has_method("get_instance_id"):
					target_ids.append(str(t.get_instance_id()))
		AILogger.totem_triggered("蝙蝠图腾", str(target_names), "流血攻击+%d层" % bleed_stacks_per_hit)
		if AIManager and AIManager.has_method("broadcast_text"):
			AIManager.broadcast_text("【图腾攻击】蝙蝠图腾 触发流血攻击，目标: [%s]，伤害: 25" % [", ".join(target_ids)])

	for enemy in targets:
		if is_instance_valid(enemy) and enemy.has_method("add_bleed_stacks"):
			enemy.add_bleed_stacks(bleed_stacks_per_hit, self)
			# 记录流血施加日志
			if AILogger and "type_key" in enemy:
				AILogger.bleed_effect(enemy.type_key, 0, enemy.bleed_stacks if "bleed_stacks" in enemy else 1, "蝙蝠图腾")
			_play_bat_attack_effect(enemy)

func _play_bat_attack_effect(enemy):
	# Visual effect for bleed application
	GameManager.spawn_floating_text(enemy.global_position, "Bleed!", Color.RED, Vector2.UP)
