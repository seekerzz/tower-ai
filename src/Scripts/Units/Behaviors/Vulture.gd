extends "res://src/Scripts/Units/Behaviors/FlyingMeleeBehavior.gd"

# Vulture - 秃鹫
# 优先攻击生命值最低敌人
# Lv1-3: 周围有敌人死亡时，获得攻击力加成buff持续5秒
#   Lv1: 攻击+5%
#   Lv2: 攻击+10%
#   Lv3: 攻击+10% + 吸血+20%

var buff_active: bool = false
var buff_timer: float = 0.0
var buff_duration: float = 5.0

# 从配置读取的数值
var damage_bonus_percent: float = 0.0
var lifesteal_percent: float = 0.0
var detection_range: float = 300.0

func _init(target_unit: Node2D):
	super._init(target_unit)
	# 连接敌人死亡信号
	if GameManager.has_signal("enemy_died"):
		GameManager.enemy_died.connect(_on_enemy_died)
	_load_mechanics()

func _load_mechanics():
	# 从unit_data读取mechanics配置
	if unit and unit.unit_data and unit.unit_data.has("levels"):
		var level_key = str(unit.level)
		if unit.unit_data.levels.has(level_key):
			var level_data = unit.unit_data.levels[level_key]
			if level_data.has("mechanics"):
				var mechanics = level_data.mechanics
				damage_bonus_percent = mechanics.get("damage_bonus_percent", 0.0)
				lifesteal_percent = mechanics.get("lifesteal_percent", 0.0)
				detection_range = mechanics.get("detection_range", 300.0)

func _on_enemy_died(enemy, killer_unit):
	# 检查死亡的敌人是否在检测范围内
	if not is_instance_valid(unit):
		return
	if not is_instance_valid(enemy):
		return

	var dist = unit.global_position.distance_to(enemy.global_position)
	if dist <= detection_range:
		# 触发腐食增益
		_trigger_scavenger_buff()

func _trigger_scavenger_buff():
	buff_active = true
	buff_timer = buff_duration

	# 显示buff获得提示
	var buff_text = "腐食+" + str(int(damage_bonus_percent * 100)) + "%"
	if unit.level >= 3 and lifesteal_percent > 0:
		buff_text += " 吸血+" + str(int(lifesteal_percent * 100)) + "%"
	GameManager.spawn_floating_text(unit.global_position, buff_text, Color.ORANGE)

func on_combat_tick(delta: float) -> bool:
	# 更新buff计时器
	if buff_active:
		buff_timer -= delta
		if buff_timer <= 0:
			buff_active = false
			buff_timer = 0.0

	return super.on_combat_tick(delta)

func _get_target() -> Node2D:
	# Lowest HP
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var min_hp = 9999999.0

	for enemy in enemies:
		if !is_instance_valid(enemy): continue
		var dist = unit.global_position.distance_to(enemy.global_position)
		if dist <= unit.range_val:
			if enemy.hp < min_hp:
				min_hp = enemy.hp
				best_target = enemy
	return best_target

func _calculate_damage(target: Node2D) -> float:
	var dmg = unit.damage

	# 应用腐食增益的攻击力加成
	if buff_active:
		dmg *= (1.0 + damage_bonus_percent)

	return dmg

func _enter_claw_impact(t_impact, t_return, t_landing):
	# Override to apply lifesteal if buff is active (Lv3)
	state = State.IMPACT
	if is_instance_valid(current_target):
		var dmg = _calculate_damage(current_target)

		current_target.take_damage(dmg, unit, "physical")

		# 应用吸血 (Lv3且buff激活时)
		if buff_active and unit.level >= 3 and lifesteal_percent > 0:
			var heal_amount = dmg * lifesteal_percent
			if unit.has_method("heal"):
				unit.heal(heal_amount)
			else:
				unit.hp = min(unit.hp + heal_amount, unit.max_hp)
			GameManager.spawn_floating_text(unit.global_position, "+" + str(int(heal_amount)), Color.GREEN)

		if GameManager.has_method("trigger_impact"):
			GameManager.trigger_impact((current_target.global_position - unit.global_position).normalized(), 0.3)

	# Animation
	if unit.visual_holder:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		var target_scale = Vector2(0.5, 1.5 * _current_y_scale_sign)
		var recovery_scale = Vector2(1.0, 1.0 * _current_y_scale_sign)
		_combat_tween.tween_property(unit.visual_holder, "scale", target_scale, t_impact * 0.5)\
			.set_trans(Tween.TRANS_BOUNCE)
		_combat_tween.tween_property(unit.visual_holder, "scale", recovery_scale, t_impact * 0.5)
		_combat_tween.tween_callback(func(): _enter_return(t_return, t_landing))
	else:
		if _combat_tween: _combat_tween.kill()
		_combat_tween = unit.create_tween()
		_combat_tween.tween_interval(t_impact)
		_combat_tween.tween_callback(func(): _enter_return(t_return, t_landing))

func on_level_up():
	# 等级提升时重新加载机制数值
	_load_mechanics()

func on_cleanup():
	# 断开信号连接
	if GameManager.has_signal("enemy_died"):
		if GameManager.enemy_died.is_connected(_on_enemy_died):
			GameManager.enemy_died.disconnect(_on_enemy_died)
	super.on_cleanup()
