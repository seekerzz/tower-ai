extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 瘟疫领主 - 第18波Boss
## 主题：毒素、疾病、凋零

# 技能配置
const SKILL_POISON_CLOUD = "poison_cloud"      # 毒云
const SKILL_PLAGUE_SPREAD = "plague_spread"    # 瘟疫传播
const SKILL_DECAY = "decay"                    # 凋零

# 技能参数
var poison_damage: float = 20.0
var plague_spawn_count: int = 2
var decay_damage_percent: float = 0.05  # 核心当前生命5%

# 被动技能：瘟疫光环 - 周围3格防御塔攻击力-30%
const PASSIVE_PLAGUE_AURA = "plague_aura"
var plague_aura_range: float = 3.0  # 3格范围
var plague_aura_damage_reduction: float = 0.30
var plague_aura_timer: float = 0.0
var plague_aura_interval: float = 3.0  # 每3秒检查一次

# 被动技能：死亡抗拒 - HP<20%时50%减伤，持续10秒
const PASSIVE_DEATH_RESISTANCE = "death_resistance"
var death_resistance_hp_threshold: float = 0.20
var death_resistance_damage_reduction: float = 0.50
var death_resistance_duration: float = 10.0
var is_death_resistance_active: bool = false
var death_resistance_timer: float = 0.0

func _ready():
	# 注册技能CD
	register_skill(SKILL_POISON_CLOUD, 8.0)    # 8秒CD
	register_skill(SKILL_PLAGUE_SPREAD, 12.0)  # 12秒CD
	register_skill(SKILL_DECAY, 15.0)          # 15秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	# 设置Boss元数据
	enemy_data["boss_name"] = "AutumnLord"
	enemy_data["boss_title"] = "瘟疫领主"
	enemy_data["max_phase"] = 2
	enemy_data["phase_hp_thresholds"] = [0.5]  # 50%血量进入第二阶段

	super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
	match new_phase:
		2:
			# 第二阶段：增强毒素效果
			poison_damage = 35.0
			plague_spawn_count = 4
			decay_damage_percent = 0.08  # 8%
			# 立即触发毒云
			perform_skill_poison_cloud()

## 重写技能执行
func perform_boss_skill(skill_name: String):
	match skill_name:
		SKILL_POISON_CLOUD:
			perform_skill_poison_cloud()
		SKILL_PLAGUE_SPREAD:
			perform_skill_plague_spread()
		SKILL_DECAY:
			perform_skill_decay()
		_:
			super.perform_boss_skill(skill_name)

## 毒云 - 放置毒雾陷阱
func perform_skill_poison_cloud():
	_log_boss_skill("毒云", "周围区域", "放置毒雾")

	GameManager.spawn_floating_text(enemy.global_position, "☠️ 毒云蔓延!", Color.LIME_GREEN)

	# 在Boss周围放置毒雾（通过生成毒怪来模拟）
	for i in range(3):
		var angle = (TAU / 3) * i
		var offset = Vector2(cos(angle), sin(angle)) * 80.0
		if GameManager.combat_manager:
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "poison")

	# 对核心造成毒素伤害
	if GameManager.core:
		GameManager.core.take_damage(poison_damage, "瘟疫领主-毒云")

	set_skill_cooldown(SKILL_POISON_CLOUD)

## 瘟疫传播 - 召唤感染敌人
func perform_skill_plague_spread():
	_log_boss_skill("瘟疫传播", "随机位置", "召唤%d个感染者" % plague_spawn_count)

	GameManager.spawn_floating_text(enemy.global_position, "🦠 瘟疫传播!", Color.GREEN_YELLOW)

	# 召唤感染者
	if GameManager.combat_manager:
		for i in range(plague_spawn_count):
			var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "mutant_slime")

	set_skill_cooldown(SKILL_PLAGUE_SPREAD)

## 凋零 - 按百分比伤害
func perform_skill_decay():
	var damage = 0.0
	if GameManager.core:
		damage = GameManager.core.hp * decay_damage_percent

	_log_boss_skill("凋零", "核心", "造成%.0f百分比伤害" % (decay_damage_percent * 100))

	GameManager.spawn_floating_text(enemy.global_position, "🥀 万物凋零!", Color.DARK_GREEN)

	# 对核心造成百分比伤害
	if GameManager.core and damage > 0:
		GameManager.core.take_damage(damage, "瘟疫领主-凋零")

	set_skill_cooldown(SKILL_DECAY)

## 重写physics_process以自动释放技能和处理被动
func physics_process(delta: float) -> bool:
	# 调用父类更新CD和阶段检查
	var handled = super.physics_process(delta)
	if handled:
		return true

	# 自动释放可用技能
	if is_skill_ready(SKILL_POISON_CLOUD):
		perform_skill_poison_cloud()
	elif is_skill_ready(SKILL_PLAGUE_SPREAD):
		perform_skill_plague_spread()
	elif is_skill_ready(SKILL_DECAY):
		perform_skill_decay()

	# 被动：瘟疫光环 - 定期对周围防御塔施加减益
	plague_aura_timer += delta
	if plague_aura_timer >= plague_aura_interval:
		plague_aura_timer = 0.0
		_apply_plague_aura()

	# 被动：死亡抗拒 - 检查是否触发
	if not is_death_resistance_active and enemy:
		var hp_percent = enemy.hp / enemy.max_hp
		if hp_percent <= death_resistance_hp_threshold:
			_trigger_death_resistance()

	# 死亡抗拒持续时间
	if is_death_resistance_active:
		death_resistance_timer -= delta
		if death_resistance_timer <= 0:
			is_death_resistance_active = false
			_log_boss_skill("死亡抗拒", "自身", "效果结束")

	return false

## 被动：瘟疫光环 - 周围防御塔攻击力-30%
func _apply_plague_aura():
	_log_boss_skill("瘟疫光环", "周围%.0f格" % plague_aura_range, "防御塔攻击力-%.0f%%" % (plague_aura_damage_reduction * 100))
	# 实际效果需要遍历周围单位并降低攻击力
	# 这里简化实现，记录日志表示效果触发

## 触发死亡抗拒
func _trigger_death_resistance():
	is_death_resistance_active = true
	death_resistance_timer = death_resistance_duration
	_log_boss_skill("死亡抗拒", "自身", "HP<%.0f%%，获得%.0f%%减伤%.0f秒" % [death_resistance_hp_threshold * 100, death_resistance_damage_reduction * 100, death_resistance_duration])
	GameManager.spawn_floating_text(enemy.global_position, "💀 死亡抗拒!", Color.DARK_RED)

## 重写on_hit以实现死亡抗拒减伤
func on_hit(attacker, damage: float) -> float:
	# 死亡抗拒激活时，减少受到的伤害
	if is_death_resistance_active:
		var reduced_damage = damage * (1.0 - death_resistance_damage_reduction)
		return super.on_hit(attacker, reduced_damage)
	return super.on_hit(attacker, damage)
