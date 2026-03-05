extends "res://src/Scripts/Enemies/Behaviors/DefaultBehavior.gd"

# ===== Boss基础属性 =====
var stationary_timer: float = 0.0
var boss_skill: String = ""
var skill_cd_timer: float = 0.0
var is_stationary: bool = false
var is_dying_anim: bool = false

# ===== 技能CD管理系统 =====
var skill_cooldowns: Dictionary = {}  # 技能名 -> 当前CD
var skill_max_cooldowns: Dictionary = {}  # 技能名 -> 最大CD

# ===== Boss阶段系统 =====
var current_phase: int = 1
var max_phase: int = 3
var phase_hp_thresholds: Array = []  # 血量百分比阈值，如 [0.7, 0.4] 表示70%和40%切换阶段

# ===== Boss元数据 =====
var boss_name: String = "Boss"
var boss_title: String = ""  # 称号，如"春之守护者"

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	super.init(enemy_node, enemy_data)
	stationary_timer = data.get("stationary_time", 0.0)
	boss_skill = data.get("boss_skill", "")
	boss_name = data.get("boss_name", enemy.type_key if enemy else "Boss")
	boss_title = data.get("boss_title", "")

	# 初始化阶段系统
	max_phase = data.get("max_phase", 3)
	phase_hp_thresholds = data.get("phase_hp_thresholds", [0.7, 0.4])
	current_phase = 1

	# 初始化技能CD系统
	_init_skill_cooldowns(data.get("skills", {}))

	if stationary_timer > 0.0:
		is_stationary = true

	# Boss Stats overrides
	enemy.knockback_resistance = 10.0
	enemy.mass = 5.0

	# 记录Boss生成日志
	_log_boss_spawn()

## 初始化技能CD系统
func _init_skill_cooldowns(skills_data: Dictionary):
	for skill_name in skills_data.keys():
		var skill_info = skills_data[skill_name]
		var cooldown = skill_info.get("cooldown", 5.0)
		skill_max_cooldowns[skill_name] = cooldown
		skill_cooldowns[skill_name] = 0.0  # 初始CD为0，可以立即释放

## 注册技能（供子类在ready中调用）
func register_skill(skill_name: String, cooldown: float):
	skill_max_cooldowns[skill_name] = cooldown
	skill_cooldowns[skill_name] = 0.0

## 检查技能是否可用
func is_skill_ready(skill_name: String) -> bool:
	if skill_name in skill_cooldowns:
		return skill_cooldowns[skill_name] <= 0.0
	return false

## 设置技能CD
func set_skill_cooldown(skill_name: String, cooldown: float = -1.0):
	if skill_name in skill_max_cooldowns:
		var cd = cooldown if cooldown > 0 else skill_max_cooldowns[skill_name]
		skill_cooldowns[skill_name] = cd

## 获取技能CD百分比（用于UI显示）
func get_skill_cooldown_percent(skill_name: String) -> float:
	if skill_name in skill_cooldowns and skill_name in skill_max_cooldowns:
		var current = skill_cooldowns[skill_name]
		var max_cd = skill_max_cooldowns[skill_name]
		if max_cd > 0:
			return clamp(1.0 - (current / max_cd), 0.0, 1.0)
	return 1.0  # 默认返回满CD

func physics_process(delta: float) -> bool:
	if is_dying_anim: return true

	# 更新所有技能CD
	_update_skill_cooldowns(delta)

	# 检查阶段转换
	_check_phase_transition()

	if is_stationary:
		stationary_timer -= delta
		skill_cd_timer -= delta
		if stationary_timer <= 0:
			is_stationary = false
		else:
			if boss_skill != "" and skill_cd_timer <= 0:
				perform_boss_skill(boss_skill)
				skill_cd_timer = 2.0
			return true # Handled (don't move)

	return super.physics_process(delta)

## 更新所有技能CD
func _update_skill_cooldowns(delta: float):
	for skill_name in skill_cooldowns.keys():
		if skill_cooldowns[skill_name] > 0:
			skill_cooldowns[skill_name] -= delta

## 检查阶段转换
func _check_phase_transition():
	if current_phase >= max_phase or phase_hp_thresholds.is_empty():
		return

	var hp_percent = enemy.hp / enemy.max_hp if enemy and enemy.max_hp > 0 else 1.0
	var next_threshold_index = current_phase - 1

	if next_threshold_index < phase_hp_thresholds.size():
		var threshold = phase_hp_thresholds[next_threshold_index]
		if hp_percent <= threshold:
			transition_to_phase(current_phase + 1)

## 阶段转换（子类可重写）
func transition_to_phase(new_phase: int):
	if new_phase <= current_phase:
		return

	var old_phase = current_phase
	current_phase = new_phase

	_log_phase_transition(old_phase, new_phase)

	# 子类可在此添加阶段转换特效
	on_phase_changed(old_phase, new_phase)

## 阶段变化回调（供子类重写）
func on_phase_changed(old_phase: int, new_phase: int):
	pass

## 执行Boss技能（子类应重写此方法）
func perform_boss_skill(skill_name: String):
	_log_boss_skill(skill_name)

	# 设置技能CD
	set_skill_cooldown(skill_name)

	# 基础技能实现（子类应重写）
	if skill_name == "summon":
		_perform_summon()
	elif skill_name == "shoot_enemy":
		_perform_shoot_enemy()

## 召唤小怪
func _perform_summon():
	GameManager.spawn_floating_text(enemy.global_position, "Summon!", Color.PURPLE)
	for i in range(3):
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		if GameManager.combat_manager:
			# 使用call_deferred避免物理状态冲突
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos", enemy.global_position + offset, "minion")

## 发射敌人
func _perform_shoot_enemy():
	GameManager.spawn_floating_text(enemy.global_position, "Fire!", Color.ORANGE)
	if GameManager.combat_manager:
		GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos", enemy.global_position, "bullet_entity")

## Boss日志接口
func _log_boss_spawn():
	var display_name = boss_title if boss_title else boss_name
	if AILogger:
		AILogger.boss_spawned(display_name, current_phase, enemy.hp if enemy else 0)
	if AIManager:
		AIManager.broadcast_text("【Boss登场】%s 降临战场！" % display_name)

func _log_boss_skill(skill_name: String, target: String = "", effect: String = ""):
	var display_name = boss_title if boss_title else boss_name
	if AILogger:
		AILogger.boss_skill(display_name, skill_name, target, effect)

func _log_phase_transition(old_phase: int, new_phase: int):
	var display_name = boss_title if boss_title else boss_name
	if AILogger:
		AILogger.boss_phase_changed(display_name, old_phase, new_phase)
	if AIManager:
		AIManager.broadcast_text("【Boss阶段】%s 进入第%d阶段！" % [display_name, new_phase])

func on_death(killer_unit) -> bool:
	var display_name = boss_title if boss_title else boss_name
	if AILogger:
		AILogger.boss_died(display_name, killer_unit.name if killer_unit else "未知")
	if AIManager:
		AIManager.broadcast_text("【Boss阵亡】%s 被击败！" % display_name)

	if enemy.visual_controller:
		# 使用call_deferred处理物理状态变更
		call_deferred("_disable_collision_and_die")
		return true # We handle the death (delayed)
	return false

func _disable_collision_and_die():
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.is_dying = true # Set flag on enemy so physics stops
	is_dying_anim = true

	var death_tween = enemy.visual_controller.play_death_implosion()

	# FIX-TWEEN-001: 检查tween有效性，避免"started with no Tweeners"错误
	if death_tween and death_tween is Tween:
		death_tween.finished.connect(func():
			if is_instance_valid(enemy):
				enemy.queue_free()
		)
	else:
		# 如果没有有效tween，直接清理
		await enemy.get_tree().create_timer(0.5).timeout
		if is_instance_valid(enemy):
			enemy.queue_free()
