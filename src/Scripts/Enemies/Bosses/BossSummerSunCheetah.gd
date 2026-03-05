extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 烈日猎豹 - 夏季Boss C
## 主题：速度、扑杀、火焰轨迹、狩猎本能

# 技能配置
const SKILL_SUN_SPRINT = "sun_sprint"           # 烈日疾行
const SKILL_POUNCE = "pounce"                   # 扑杀
const SKILL_FLAME_TRAIL = "flame_trail"         # 火焰轨迹
const SKILL_HUNTING_INSTINCT = "hunting_instinct" # 狩猎本能

# 技能参数
var sun_sprint_speed: float = 2.0               # 2倍速度
var sun_sprint_duration: float = 4.0
var pounce_damage: float = 70.0
var flame_trail_damage: float = 30.0
var hunting_instinct_crit_bonus: float = 0.3    # +30%暴击

# 状态
var is_sprinting: bool = false
var sprint_timer: float = 0.0
var is_hunting_active: bool = false

func _ready():
    # 注册技能CD
    register_skill(SKILL_SUN_SPRINT, 10.0)      # 10秒CD
    register_skill(SKILL_POUNCE, 8.0)           # 8秒CD
    register_skill(SKILL_FLAME_TRAIL, 12.0)     # 12秒CD
    register_skill(SKILL_HUNTING_INSTINCT, 15.0) # 15秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
    # 设置Boss元数据
    enemy_data["boss_name"] = "SunCheetah"
    enemy_data["boss_title"] = "烈日猎豹"
    enemy_data["max_phase"] = 2
    enemy_data["phase_hp_thresholds"] = [0.5]

    super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
    match new_phase:
        2:
            # 第二阶段：进入狩猎模式
            pounce_damage = 100.0
            flame_trail_damage = 50.0
            _activate_hunting_instinct()
            _log_boss_skill("狩猎觉醒", "自身", "暴击率大幅提升")

## 重写physics_process
func physics_process(delta: float) -> bool:
    # 更新疾行状态
    if is_sprinting:
        sprint_timer -= delta
        if sprint_timer <= 0:
            is_sprinting = false
            if enemy:
                enemy.speed_multiplier = 1.0

    var handled = super.physics_process(delta)
    if handled:
        return true

    # 自动释放技能
    if is_skill_ready(SKILL_SUN_SPRINT):
        perform_skill_sun_sprint()
    elif is_skill_ready(SKILL_POUNCE):
        perform_skill_pounce()
    elif is_skill_ready(SKILL_FLAME_TRAIL):
        perform_skill_flame_trail()
    elif is_skill_ready(SKILL_HUNTING_INSTINCT) and not is_hunting_active:
        perform_skill_hunting_instinct()

    return false

## 重写技能执行
func perform_boss_skill(skill_name: String):
    match skill_name:
        SKILL_SUN_SPRINT:
            perform_skill_sun_sprint()
        SKILL_POUNCE:
            perform_skill_pounce()
        SKILL_FLAME_TRAIL:
            perform_skill_flame_trail()
        SKILL_HUNTING_INSTINCT:
            perform_skill_hunting_instinct()
        _:
            super.perform_boss_skill(skill_name)

## 烈日疾行 - 高速移动
func perform_skill_sun_sprint():
    _log_boss_skill("烈日疾行", "自身", "速度+%.0f%%" % ((sun_sprint_speed - 1.0) * 100))
    GameManager.spawn_floating_text(enemy.global_position, "💨 烈日疾行!", Color.ORANGE)

    if enemy:
        enemy.speed_multiplier = sun_sprint_speed
        is_sprinting = true
        sprint_timer = sun_sprint_duration

    set_skill_cooldown(SKILL_SUN_SPRINT)

## 扑杀 - 跳跃攻击+流血效果
func perform_skill_pounce():
    var bleed_duration = 3.0  # 3秒流血
    var bleed_damage_per_tick = 20.0  # 每秒20伤害

    _log_boss_skill("扑杀", "核心", "造成%.0f伤害+流血%.0f秒" % [pounce_damage, bleed_duration])
    GameManager.spawn_floating_text(enemy.global_position, "🐆 扑杀!", Color.RED)

    if GameManager.core:
        # 扑杀造成暴击伤害
        var crit_multiplier = 1.5 if is_hunting_active else 1.0
        GameManager.core.take_damage(pounce_damage * crit_multiplier, "烈日猎豹-扑杀")

        # 添加流血效果
        _apply_bleed_effect(GameManager.core, bleed_duration, bleed_damage_per_tick)

    set_skill_cooldown(SKILL_POUNCE)

## 应用流血效果
func _apply_bleed_effect(target: Node, duration: float, damage_per_tick: float):
    # 创建流血效果
    var bleed_effect = preload("res://src/Scripts/Effects/BleedEffect.gd").new()
    bleed_effect.setup(target, self, {
        "duration": duration,
        "damage_per_tick": damage_per_tick,
        "tick_interval": 1.0
    })
    target.add_child(bleed_effect)

    GameManager.spawn_floating_text(target.global_position, "🩸 流血!", Color.RED)

## 火焰轨迹 - 留下火焰路径
func perform_skill_flame_trail():
    _log_boss_skill("火焰轨迹", "周围", "造成%.0f持续伤害" % flame_trail_damage)
    GameManager.spawn_floating_text(enemy.global_position, "🔥 火焰轨迹!", Color.ORANGE_RED)

    # 在周围放置火焰（通过召唤火怪模拟）
    if GameManager.combat_manager:
        for i in range(4):
            var angle = (TAU / 4) * i
            var offset = Vector2(cos(angle), sin(angle)) * 60.0
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "crab")

    # 对核心造成伤害
    if GameManager.core:
        GameManager.core.take_damage(flame_trail_damage, "烈日猎豹-火焰轨迹")

    set_skill_cooldown(SKILL_FLAME_TRAIL)

## 狩猎本能 - 暴击/追踪
func perform_skill_hunting_instinct():
    _activate_hunting_instinct()
    set_skill_cooldown(SKILL_HUNTING_INSTINCT)

func _activate_hunting_instinct():
    _log_boss_skill("狩猎本能", "自身", "暴击率+%.0f%%" % (hunting_instinct_crit_bonus * 100))
    GameManager.spawn_floating_text(enemy.global_position, "🎯 狩猎本能!", Color.YELLOW)
    is_hunting_active = true
