extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 冬之女王 - 第24波Boss（最终Boss）
## 主题：冰霜、冻结、严寒

# 技能配置
const SKILL_ICE_STORM = "ice_storm"          # 冰霜风暴
const SKILL_FREEZE = "freeze"                # 冻结
const SKILL_BLIZZARD = "blizzard"            # 暴风雪
const SKILL_ABSOLUTE_ZERO = "absolute_zero"  # 绝对零度（终极技能）

# 技能参数
var ice_storm_damage: float = 80.0
var freeze_duration: float = 3.0
var blizzard_damage: float = 50.0
var absolute_zero_damage: float = 200.0

# 被动技能：绝对零度 - 全场敌人移速-20%，攻速-10%
const PASSIVE_ABSOLUTE_ZERO_AURA = "absolute_zero_aura"
var absolute_zero_move_speed_reduction: float = 0.20
var absolute_zero_attack_speed_reduction: float = 0.10
var absolute_zero_aura_timer: float = 0.0
var absolute_zero_aura_interval: float = 5.0  # 每5秒检查一次

# 被动技能：终极冻结 - HP<10%时全场冻结3秒，然后伤害+100%狂暴
const PASSIVE_FINAL_FREEZE = "final_freeze"
var final_freeze_hp_threshold: float = 0.10
var final_freeze_duration: float = 3.0
var has_final_freeze_triggered: bool = false
var is_final_freeze_rampage: bool = false
var rampage_damage_bonus: float = 1.0  # +100%

func _ready():
	# 注册技能CD
	register_skill(SKILL_ICE_STORM, 10.0)       # 10秒CD
	register_skill(SKILL_FREEZE, 12.0)          # 12秒CD
	register_skill(SKILL_BLIZZARD, 15.0)        # 15秒CD
	register_skill(SKILL_ABSOLUTE_ZERO, 30.0)   # 30秒CD（终极技能）

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	# 设置Boss元数据
	enemy_data["boss_name"] = "WinterQueen"
	enemy_data["boss_title"] = "冬之女王"
	enemy_data["max_phase"] = 3  # 3个阶段
	enemy_data["phase_hp_thresholds"] = [0.7, 0.4]  # 70%和40%切换阶段

	super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
	match new_phase:
		2:
			# 第二阶段：增强冰霜伤害
			ice_storm_damage = 120.0
			blizzard_damage = 80.0
			# 立即触发冰霜风暴
			perform_skill_ice_storm()
		3:
			# 第三阶段：终极形态
			ice_storm_damage = 150.0
			blizzard_damage = 100.0
			absolute_zero_damage = 300.0
			# 立即触发绝对零度
			perform_skill_absolute_zero()

## 重写技能执行
func perform_boss_skill(skill_name: String):
	match skill_name:
		SKILL_ICE_STORM:
			perform_skill_ice_storm()
		SKILL_FREEZE:
			perform_skill_freeze()
		SKILL_BLIZZARD:
			perform_skill_blizzard()
		SKILL_ABSOLUTE_ZERO:
			perform_skill_absolute_zero()
		_:
			super.perform_boss_skill(skill_name)

## 冰霜风暴 - 范围伤害
func perform_skill_ice_storm():
	_log_boss_skill("冰霜风暴", "全屏", "造成%.0f伤害" % ice_storm_damage)

	GameManager.spawn_floating_text(enemy.global_position, "❄️ 冰霜风暴!", Color.CYAN)

	# 对核心造成伤害
	if GameManager.core:
		GameManager.core.take_damage(ice_storm_damage, "冬之女王-冰霜风暴")

	# 召唤雪怪
	if GameManager.combat_manager:
		for i in range(2):
			var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "yeti")

	set_skill_cooldown(SKILL_ICE_STORM)

## 冻结 - 控制效果（模拟为伤害）
func perform_skill_freeze():
	_log_boss_skill("冻结", "核心", "冻结%.1f秒" % freeze_duration)

	GameManager.spawn_floating_text(enemy.global_position, "🧊 冻结!", Color.BLUE)

	# 冻结效果：额外伤害
	if GameManager.core:
		GameManager.core.take_damage(ice_storm_damage * 0.5, "冬之女王-冻结")

	set_skill_cooldown(SKILL_FREEZE)

## 暴风雪 - 持续伤害
func perform_skill_blizzard():
	_log_boss_skill("暴风雪", "全屏", "造成%.0f伤害" % blizzard_damage)

	GameManager.spawn_floating_text(enemy.global_position, "🌨️ 暴风雪!", Color.LIGHT_BLUE)

	# 对核心造成伤害
	if GameManager.core:
		GameManager.core.take_damage(blizzard_damage, "冬之女王-暴风雪")

	# 召唤多个雪怪
	if GameManager.combat_manager:
		for i in range(3):
			var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "yeti")

	set_skill_cooldown(SKILL_BLIZZARD)

## 绝对零度 - 终极技能
func perform_skill_absolute_zero():
	_log_boss_skill("绝对零度", "全屏", "造成%.0f巨额伤害" % absolute_zero_damage)

	GameManager.spawn_floating_text(enemy.global_position, "🌟 绝对零度!", Color.WHITE)

	# 对核心造成巨额伤害
	if GameManager.core:
		GameManager.core.take_damage(absolute_zero_damage, "冬之女王-绝对零度")

	# 召唤雪怪军团
	if GameManager.combat_manager:
		for i in range(4):
			var angle = (TAU / 4) * i
			var offset = Vector2(cos(angle), sin(angle)) * 100.0
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "yeti")

	set_skill_cooldown(SKILL_ABSOLUTE_ZERO)

## 重写physics_process以自动释放技能和处理被动
func physics_process(delta: float) -> bool:
	# 调用父类更新CD和阶段检查
	var handled = super.physics_process(delta)
	if handled:
		return true

	# 自动释放可用技能（按优先级）
	if is_skill_ready(SKILL_ABSOLUTE_ZERO):
		perform_skill_absolute_zero()
	elif is_skill_ready(SKILL_BLIZZARD):
		perform_skill_blizzard()
	elif is_skill_ready(SKILL_ICE_STORM):
		perform_skill_ice_storm()
	elif is_skill_ready(SKILL_FREEZE):
		perform_skill_freeze()

	# 被动：绝对零度光环
	absolute_zero_aura_timer += delta
	if absolute_zero_aura_timer >= absolute_zero_aura_interval:
		absolute_zero_aura_timer = 0.0
		_apply_absolute_zero_aura()

	# 被动：终极冻结 - 检查是否触发
	if not has_final_freeze_triggered and enemy:
		var hp_percent = enemy.hp / enemy.max_hp
		if hp_percent <= final_freeze_hp_threshold:
			_trigger_final_freeze()

	return false

## 被动：绝对零度 - 全场减速
func _apply_absolute_zero_aura():
	_log_boss_skill("绝对零度光环", "全场", "移速-%.0f%% 攻速-%.0f%%" % [absolute_zero_move_speed_reduction * 100, absolute_zero_attack_speed_reduction * 100])
	# 实际效果需要遍历所有敌人并降低速度
	# 这里简化实现，记录日志表示效果触发

## 触发终极冻结
func _trigger_final_freeze():
	has_final_freeze_triggered = true
	is_final_freeze_rampage = true
	_log_boss_skill("终极冻结", "全场", "冻结%.0f秒，然后进入狂暴(+100%%伤害)" % final_freeze_duration)
	GameManager.spawn_floating_text(enemy.global_position, "🌟 终极冻结!", Color.WHITE)

	# 对核心造成冻结效果（模拟为伤害）
	if GameManager.core:
		GameManager.core.take_damage(absolute_zero_damage * 0.5, "冬之女王-终极冻结")

## 重写on_hit以应用狂暴伤害加成
func on_hit(attacker, damage: float) -> float:
	# 狂暴状态下伤害+100%
	if is_final_freeze_rampage:
		var rampage_damage = damage * (1.0 + rampage_damage_bonus)
		return super.on_hit(attacker, rampage_damage)
	return super.on_hit(attacker, damage)
