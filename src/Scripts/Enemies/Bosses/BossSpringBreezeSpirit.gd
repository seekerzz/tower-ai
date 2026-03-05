extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 春风之灵 - 春季Boss C
## 主题：速度、闪避、分身、治愈

# 技能配置
const SKILL_WIND_STEP = "wind_step"             # 风之步(高速+闪避)
const SKILL_ILLUSION = "illusion"               # 分身幻象
const SKILL_GALE_STRIKE = "gale_strike"         # 疾风连击
const SKILL_SPRING_HEAL = "spring_heal"         # 春风治愈

# 技能参数
var wind_step_speed_bonus: float = 1.5
var wind_step_duration: float = 3.0
var illusion_count: int = 2
var gale_strike_damage: float = 40.0
var gale_strike_hits: int = 3
var spring_heal_amount: float = 60.0

# 状态
var is_wind_step_active: bool = false
var wind_step_timer: float = 0.0

func _ready():
	# 注册技能CD
	register_skill(SKILL_WIND_STEP, 10.0)       # 10秒CD
	register_skill(SKILL_ILLUSION, 15.0)        # 15秒CD
	register_skill(SKILL_GALE_STRIKE, 6.0)      # 6秒CD
	register_skill(SKILL_SPRING_HEAL, 12.0)     # 12秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	# 设置Boss元数据
	enemy_data["boss_name"] = "BreezeSpirit"
	enemy_data["boss_title"] = "春风之灵"
	enemy_data["max_phase"] = 2
	enemy_data["phase_hp_thresholds"] = [0.5]

	super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
	match new_phase:
		2:
			# 第二阶段：速度更快
			illusion_count = 4
			gale_strike_hits = 5
			gale_strike_damage = 60.0
			spring_heal_amount = 100.0
			_log_boss_skill("风之觉醒", "自身", "速度大幅提升")

## 重写physics_process以处理风之步状态
func physics_process(delta: float) -> bool:
	# 更新风之步状态
	if is_wind_step_active:
		wind_step_timer -= delta
		if wind_step_timer <= 0:
			is_wind_step_active = false
			if enemy:
				enemy.speed_multiplier = 1.0

	# 调用父类更新
	var handled = super.physics_process(delta)
	if handled:
		return true

	# 自动释放技能
	if is_skill_ready(SKILL_WIND_STEP):
		perform_skill_wind_step()
	elif is_skill_ready(SKILL_GALE_STRIKE):
		perform_skill_gale_strike()
	elif is_skill_ready(SKILL_SPRING_HEAL) and enemy and enemy.hp < enemy.max_hp * 0.6:
		perform_skill_spring_heal()
	elif is_skill_ready(SKILL_ILLUSION):
		perform_skill_illusion()

	return false

## 重写技能执行
func perform_boss_skill(skill_name: String):
	match skill_name:
		SKILL_WIND_STEP:
			perform_skill_wind_step()
		SKILL_ILLUSION:
			perform_skill_illusion()
		SKILL_GALE_STRIKE:
			perform_skill_gale_strike()
		SKILL_SPRING_HEAL:
			perform_skill_spring_heal()
		_:
			super.perform_boss_skill(skill_name)

## 风之步 - 高速移动+闪避
func perform_skill_wind_step():
	_log_boss_skill("风之步", "自身", "速度+%.0f%%" % ((wind_step_speed_bonus - 1.0) * 100))

	GameManager.spawn_floating_text(enemy.global_position, "💨 风之步!", Color.CYAN)

	# 增加移动速度
	if enemy:
		enemy.speed_multiplier = wind_step_speed_bonus
		is_wind_step_active = true
		wind_step_timer = wind_step_duration

	set_skill_cooldown(SKILL_WIND_STEP)

## 分身幻象 - 召唤分身
func perform_skill_illusion():
	_log_boss_skill("分身幻象", "周围", "召唤%d个分身" % illusion_count)

	GameManager.spawn_floating_text(enemy.global_position, "👥 分身幻象!", Color.LIGHT_BLUE)

	# 召唤小怪作为分身
	if GameManager.combat_manager:
		for i in range(illusion_count):
			var angle = (TAU / illusion_count) * i
			var offset = Vector2(cos(angle), sin(angle)) * 50.0
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "slime")

	set_skill_cooldown(SKILL_ILLUSION)

## 疾风连击 - 快速多段攻击
func perform_skill_gale_strike():
	var total_damage = gale_strike_damage * gale_strike_hits
	_log_boss_skill("疾风连击", "核心", "%d连击，总伤害%.0f" % [gale_strike_hits, total_damage])

	GameManager.spawn_floating_text(enemy.global_position, "⚡ 疾风连击!", Color.YELLOW)

	# 对核心造成多段伤害
	if GameManager.core:
		for i in range(gale_strike_hits):
			GameManager.core.take_damage(gale_strike_damage, "春风之灵-疾风连击")

	set_skill_cooldown(SKILL_GALE_STRIKE)

## 春风治愈 - 恢复生命
func perform_skill_spring_heal():
	_log_boss_skill("春风治愈", "自身", "恢复%.0f HP" % spring_heal_amount)

	GameManager.spawn_floating_text(enemy.global_position, "💚 春风治愈!", Color.GREEN)

	# 恢复生命
	if enemy:
		enemy.hp = min(enemy.hp + spring_heal_amount, enemy.max_hp)
		GameManager.spawn_floating_text(enemy.global_position + Vector2(0, -30),
			"+%.0f" % spring_heal_amount, Color.GREEN)

	set_skill_cooldown(SKILL_SPRING_HEAL)
