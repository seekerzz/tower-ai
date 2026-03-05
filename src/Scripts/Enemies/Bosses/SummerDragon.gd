extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 炎阳巨龙 - 第12波Boss
## 主题：火焰、爆发、灼烧

# 技能配置
const SKILL_FIRE_BREATH = "fire_breath"      # 火焰吐息
const SKILL_METEOR_FALL = "meteor_fall"      # 陨石坠落
const SKILL_HEAT_WAVE = "heat_wave"          # 热浪

# 技能参数
var fire_breath_damage: float = 60.0
var meteor_count: int = 3
var heat_wave_damage: float = 40.0

# 被动技能：烈日炙烤 - 全场敌人攻速+20%
const PASSIVE_SCORCHING_SUN = "scorching_sun"
var scorching_sun_attack_speed_bonus: float = 0.20
var scorching_sun_timer: float = 0.0
var scorching_sun_interval: float = 5.0  # 每5秒检查一次

# 被动技能：涅槃重生 - HP首次归零时恢复30%生命，攻速+50%
const PASSIVE_REBIRTH = "rebirth"
var has_rebirth_triggered: bool = false
var rebirth_hp_percent: float = 0.30
var rebirth_attack_speed_bonus: float = 0.50

func _ready():
	# 注册技能CD
	register_skill(SKILL_FIRE_BREATH, 10.0)   # 10秒CD
	register_skill(SKILL_METEOR_FALL, 15.0)   # 15秒CD
	register_skill(SKILL_HEAT_WAVE, 12.0)     # 12秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	# 设置Boss元数据
	enemy_data["boss_name"] = "SummerDragon"
	enemy_data["boss_title"] = "炎阳巨龙"
	enemy_data["max_phase"] = 2
	enemy_data["phase_hp_thresholds"] = [0.5]  # 50%血量进入第二阶段

	super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
	match new_phase:
		2:
			# 第二阶段：增强火焰伤害
			fire_breath_damage = 100.0
			meteor_count = 5
			heat_wave_damage = 70.0
			# 立即触发热浪
			perform_skill_heat_wave()

## 重写技能执行
func perform_boss_skill(skill_name: String):
	match skill_name:
		SKILL_FIRE_BREATH:
			perform_skill_fire_breath()
		SKILL_METEOR_FALL:
			perform_skill_meteor_fall()
		SKILL_HEAT_WAVE:
			perform_skill_heat_wave()
		_:
			super.perform_boss_skill(skill_name)

## 火焰吐息 - 对核心造成高额伤害
func perform_skill_fire_breath():
	_log_boss_skill("火焰吐息", "核心", "造成%.0f伤害" % fire_breath_damage)

	GameManager.spawn_floating_text(enemy.global_position, "🔥 火焰吐息!", Color.ORANGE_RED)

	# 对核心造成伤害
	if GameManager.core:
		GameManager.core.take_damage(fire_breath_damage, "炎阳巨龙-火焰吐息")

	set_skill_cooldown(SKILL_FIRE_BREATH)

## 陨石坠落 - 召唤多个陨石
func perform_skill_meteor_fall():
	_log_boss_skill("陨石坠落", "随机位置", "召唤%d个陨石" % meteor_count)

	GameManager.spawn_floating_text(enemy.global_position, "☄️ 陨石坠落!", Color.RED)

	# 在核心周围随机位置召唤敌人（模拟陨石）
	if GameManager.core:
		for i in range(meteor_count):
			var random_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
			var spawn_pos = GameManager.core.global_position + random_offset
			if GameManager.combat_manager:
				GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
					spawn_pos, "crab")

	set_skill_cooldown(SKILL_METEOR_FALL)

## 热浪 - 持续伤害
func perform_skill_heat_wave():
	_log_boss_skill("热浪", "全屏", "造成%.0f伤害" % heat_wave_damage)

	GameManager.spawn_floating_text(enemy.global_position, "🌊 热浪来袭!", Color.DARK_ORANGE)

	# 对核心造成伤害
	if GameManager.core:
		GameManager.core.take_damage(heat_wave_damage, "炎阳巨龙-热浪")

	set_skill_cooldown(SKILL_HEAT_WAVE)

## 重写physics_process以自动释放技能和处理被动
func physics_process(delta: float) -> bool:
	# 调用父类更新CD和阶段检查
	var handled = super.physics_process(delta)
	if handled:
		return true

	# 自动释放可用技能（优先顺序）
	if is_skill_ready(SKILL_FIRE_BREATH):
		perform_skill_fire_breath()
	elif is_skill_ready(SKILL_METEOR_FALL):
		perform_skill_meteor_fall()
	elif is_skill_ready(SKILL_HEAT_WAVE):
		perform_skill_heat_wave()

	# 被动：烈日炙烤 - 定期给全场敌人增加攻速
	scorching_sun_timer += delta
	if scorching_sun_timer >= scorching_sun_interval:
		scorching_sun_timer = 0.0
		_apply_scorching_sun()

	return false

## 被动：烈日炙烤 - 全场敌人攻速+20%
func _apply_scorching_sun():
	# 这里应该给所有敌人增加攻速buff
	# 简化实现：记录日志表示效果触发
	_log_boss_skill("烈日炙烤", "全场敌人", "攻速+%.0f%%" % (scorching_sun_attack_speed_bonus * 100))

## 重写on_hit以实现涅槃重生被动
func on_hit(attacker, damage: float) -> float:
	var actual_damage = super.on_hit(attacker, damage)

	# 被动：涅槃重生 - HP首次归零时恢复30%生命，攻速+50%
	if not has_rebirth_triggered and enemy and enemy.hp <= 0:
		has_rebirth_triggered = true
		var heal_amount = enemy.max_hp * rebirth_hp_percent
		enemy.hp = heal_amount
		_log_boss_skill("涅槃重生", "自身", "恢复%.0f HP，攻速+%.0f%%" % [heal_amount, rebirth_attack_speed_bonus * 100])
		GameManager.spawn_floating_text(enemy.global_position, "🔥 涅槃重生!", Color.ORANGE_RED)
		# 增加攻速（这里简化处理，实际应该修改enemy的攻击速度）
		return 0.0  # 阻止这次死亡

	return actual_damage
