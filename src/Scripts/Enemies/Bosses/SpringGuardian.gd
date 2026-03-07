extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 春之守护者 - 第6波Boss
## 主题：生命、复苏、召唤

# 技能配置
const SKILL_SUMMON_SEEDLING = "summon_seedling"  # 召唤幼苗
const SKILL_REGENERATION = "regeneration"        # 生命恢复
const SKILL_THORN_WAVE = "thorn_wave"            # 荆棘波

# 技能参数
var seedling_count: int = 2
var regeneration_amount: float = 50.0
var thorn_damage: float = 30.0

# 被动技能：荆棘护甲 - 反弹30%近战伤害
const PASSIVE_THORN_ARMOR = "thorn_armor"
var thorn_armor_reflect_percent: float = 0.30

func _ready():
	# 注册技能CD
	register_skill(SKILL_SUMMON_SEEDLING, 8.0)   # 8秒CD
	register_skill(SKILL_REGENERATION, 12.0)     # 12秒CD
	register_skill(SKILL_THORN_WAVE, 10.0)       # 10秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	# 设置Boss元数据
	enemy_data["boss_name"] = "SpringGuardian"
	enemy_data["boss_title"] = "春之守护者"
	enemy_data["max_phase"] = 2
	enemy_data["phase_hp_thresholds"] = [0.5]  # 50%血量进入第二阶段

	super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
	match new_phase:
		2:
			# 第二阶段：增强召唤能力
			seedling_count = 4
			regeneration_amount = 80.0
			thorn_damage = 50.0
			# 立即触发一次技能
			perform_skill_summon_seedling()

## 重写技能执行
func perform_boss_skill(skill_name: String):
	match skill_name:
		SKILL_SUMMON_SEEDLING:
			perform_skill_summon_seedling()
		SKILL_REGENERATION:
			perform_skill_regeneration()
		SKILL_THORN_WAVE:
			perform_skill_thorn_wave()
		_:
			super.perform_boss_skill(skill_name)

## 召唤幼苗
func perform_skill_summon_seedling():
	_log_boss_skill("召唤幼苗", "周围区域", "召唤%d个小怪" % seedling_count)

	GameManager.spawn_floating_text(enemy.global_position, "🌱 生命绽放!", Color.GREEN)

	for i in range(seedling_count):
		var angle = (TAU / seedling_count) * i
		var offset = Vector2(cos(angle), sin(angle)) * 60.0
		if GameManager.combat_manager:
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "slime")

	set_skill_cooldown(SKILL_SUMMON_SEEDLING)

## 生命恢复
func perform_skill_regeneration():
	_log_boss_skill("生命复苏", "自身", "恢复%.0f HP" % regeneration_amount)

	GameManager.spawn_floating_text(enemy.global_position, "💚 生命复苏!", Color.GREEN)

	# 恢复自身生命
	if enemy:
		enemy.get_node("Stats").current_hp = min(enemy.get_node("Stats").current_hp + regeneration_amount, enemy.get_node("Stats").max_hp)
		# 显示治疗数字
		GameManager.spawn_floating_text(enemy.global_position + Vector2(0, -30),
			"+%.0f" % regeneration_amount, Color.GREEN)

	set_skill_cooldown(SKILL_REGENERATION)

## 荆棘波
func perform_skill_thorn_wave():
	_log_boss_skill("荆棘波", "全屏", "造成%.0f伤害" % thorn_damage)

	GameManager.spawn_floating_text(enemy.global_position, "🌿 荆棘蔓延!", Color.YELLOW_GREEN)

	# 对核心造成伤害
	if GameManager.core:
		GameManager.core.take_damage(thorn_damage, "春之守护者-荆棘波")

	set_skill_cooldown(SKILL_THORN_WAVE)

## 重写physics_process以自动释放技能
func physics_process(delta: float) -> bool:
	# 调用父类更新CD和阶段检查
	var handled = super.physics_process(delta)
	if handled:
		return true

	# 自动释放可用技能
	if is_skill_ready(SKILL_SUMMON_SEEDLING):
		perform_skill_summon_seedling()
	elif is_skill_ready(SKILL_REGENERATION) and enemy and enemy.get_node("Stats").current_hp < enemy.get_node("Stats").max_hp * 0.7:
		perform_skill_regeneration()
	elif is_skill_ready(SKILL_THORN_WAVE):
		perform_skill_thorn_wave()

	return false

## 重写on_hit以实现荆棘护甲被动
func on_hit(attacker, damage: float) -> float:
	# 调用父类处理
	var actual_damage = super.on_hit(attacker, damage)

	# 荆棘护甲：反弹30%近战伤害给攻击者
	if attacker and attacker.has_method("take_damage"):
		var reflect_damage = damage * thorn_armor_reflect_percent
		attacker.take_damage(reflect_damage, "春之守护者-荆棘护甲")
		_log_boss_skill("荆棘护甲", attacker.name if "name" in attacker else "攻击者", "反弹%.0f伤害" % reflect_damage)

	return actual_damage
