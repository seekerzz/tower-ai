extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 枯萎先知 - 秋季Boss C
## 主题：诅咒、吸血、虚弱、末日预言

# 技能配置
const SKILL_WITHER_CURSE = "wither_curse"       # 枯萎诅咒
const SKILL_LIFE_DRAIN = "life_drain"           # 生命吸取
const SKILL_WEAKNESS_AURA = "weakness_aura"     # 虚弱光环
const SKILL_DOOM_PROPHECY = "doom_prophecy"     # 末日预言

# 技能参数
var wither_curse_damage: float = 30.0
var wither_curse_duration: float = 5.0
var life_drain_damage: float = 50.0
var life_drain_heal_ratio: float = 1.0          # 100%伤害转化为治疗
var weakness_aura_range: float = 200.0
var weakness_aura_effect: float = 0.2           # 20%减益
var doom_prophecy_damage: float = 100.0

# 状态
var is_weakness_aura_active: bool = false

func _ready():
    # 注册技能CD
    register_skill(SKILL_WITHER_CURSE, 8.0)     # 8秒CD
    register_skill(SKILL_LIFE_DRAIN, 10.0)      # 10秒CD
    register_skill(SKILL_WEAKNESS_AURA, 15.0)   # 15秒CD
    register_skill(SKILL_DOOM_PROPHECY, 20.0)   # 20秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
    # 设置Boss元数据
    enemy_data["boss_name"] = "WitheredProphet"
    enemy_data["boss_title"] = "枯萎先知"
    enemy_data["max_phase"] = 2
    enemy_data["phase_hp_thresholds"] = [0.5]

    super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
    match new_phase:
        2:
            # 第二阶段：末日降临
            wither_curse_damage = 50.0
            doom_prophecy_damage = 150.0
            _log_boss_skill("末日觉醒", "全屏", "诅咒强化")

## 重写技能执行
func perform_boss_skill(skill_name: String):
    match skill_name:
        SKILL_WITHER_CURSE:
            perform_skill_wither_curse()
        SKILL_LIFE_DRAIN:
            perform_skill_life_drain()
        SKILL_WEAKNESS_AURA:
            perform_skill_weakness_aura()
        SKILL_DOOM_PROPHECY:
            perform_skill_doom_prophecy()
        _:
            super.perform_boss_skill(skill_name)

## 枯萎诅咒 - Debuff
func perform_skill_wither_curse():
    _log_boss_skill("枯萎诅咒", "核心", "造成%.0f持续伤害" % wither_curse_damage)
    GameManager.spawn_floating_text(enemy.global_position, "☠️ 枯萎诅咒!", Color.DARK_GREEN)

    if GameManager.core:
        GameManager.core.take_damage(wither_curse_damage, "枯萎先知-枯萎诅咒")

    set_skill_cooldown(SKILL_WITHER_CURSE)

## 生命吸取 - 吸血
func perform_skill_life_drain():
    var heal_amount = life_drain_damage * life_drain_heal_ratio
    _log_boss_skill("生命吸取", "核心", "吸取%.0f生命" % life_drain_damage)
    GameManager.spawn_floating_text(enemy.global_position, "🩸 生命吸取!", Color.DARK_RED)

    if GameManager.core:
        GameManager.core.take_damage(life_drain_damage, "枯萎先知-生命吸取")

    # 恢复生命
    if enemy:
        enemy.get_node("Stats").current_hp = min(enemy.get_node("Stats").current_hp + heal_amount, enemy.get_node("Stats").max_hp)
        GameManager.spawn_floating_text(enemy.global_position + Vector2(0, -30),
            "+%.0f" % heal_amount, Color.RED)

    set_skill_cooldown(SKILL_LIFE_DRAIN)

## 虚弱光环 - 范围减益
func perform_skill_weakness_aura():
    _log_boss_skill("虚弱光环", "周围", "范围减益%.0f%%" % (weakness_aura_effect * 100))
    GameManager.spawn_floating_text(enemy.global_position, "💨 虚弱光环!", Color.GRAY)

    is_weakness_aura_active = true

    # 对核心造成伤害
    if GameManager.core:
        GameManager.core.take_damage(weakness_aura_effect * 100, "枯萎先知-虚弱光环")

    set_skill_cooldown(SKILL_WEAKNESS_AURA)

## 末日预言 - 强力技能
func perform_skill_doom_prophecy():
    _log_boss_skill("末日预言", "全屏", "造成%.0f巨额伤害" % doom_prophecy_damage)
    GameManager.spawn_floating_text(enemy.global_position, "🔮 末日预言!", Color.DARK_VIOLET)

    if GameManager.core:
        GameManager.core.take_damage(doom_prophecy_damage, "枯萎先知-末日预言")

    # 召唤诅咒生物
    if GameManager.combat_manager:
        for i in range(3):
            var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "poison")

    set_skill_cooldown(SKILL_DOOM_PROPHECY)

## 重写physics_process
func physics_process(delta: float) -> bool:
    var handled = super.physics_process(delta)
    if handled:
        return true

    # 自动释放技能
    if is_skill_ready(SKILL_DOOM_PROPHECY):
        perform_skill_doom_prophecy()
    elif is_skill_ready(SKILL_LIFE_DRAIN) and enemy and enemy.get_node("Stats").current_hp < enemy.get_node("Stats").max_hp * 0.7:
        perform_skill_life_drain()
    elif is_skill_ready(SKILL_WITHER_CURSE):
        perform_skill_wither_curse()
    elif is_skill_ready(SKILL_WEAKNESS_AURA):
        perform_skill_weakness_aura()

    return false
