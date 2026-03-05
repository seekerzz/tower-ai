extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 凋零死神 - 秋季Boss B
## 主题：死亡、亡灵召唤、灵魂收割

# 技能配置
const SKILL_DEATH_SCYTHE = "death_scythe"       # 死亡镰刀
const SKILL_UNDEAD_SUMMON = "undead_summon"     # 亡灵召唤
const SKILL_SOUL_REAP = "soul_reap"             # 灵魂收割
const SKILL_DEATH_COIL = "death_coil"           # 死亡缠绕

# 技能参数
var death_scythe_damage: float = 80.0
var undead_summon_count: int = 3
var soul_reap_damage: float = 40.0
var soul_reap_heal_ratio: float = 0.5           # 50%伤害转化为治疗
var death_coil_damage: float = 50.0
var death_coil_slow: float = 0.3                # 30%减速

func _ready():
    # 注册技能CD
    register_skill(SKILL_DEATH_SCYTHE, 8.0)     # 8秒CD
    register_skill(SKILL_UNDEAD_SUMMON, 12.0)   # 12秒CD
    register_skill(SKILL_SOUL_REAP, 10.0)       # 10秒CD
    register_skill(SKILL_DEATH_COIL, 15.0)      # 15秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
    # 设置Boss元数据
    enemy_data["boss_name"] = "DeathReaper"
    enemy_data["boss_title"] = "凋零死神"
    enemy_data["max_phase"] = 2
    enemy_data["phase_hp_thresholds"] = [0.4]   # 40%血量进入第二阶段

    super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
    match new_phase:
        2:
            # 第二阶段：死亡之力增强
            death_scythe_damage = 120.0
            undead_summon_count = 5
            soul_reap_damage = 60.0
            _log_boss_skill("死亡觉醒", "自身", "召唤更多亡灵")

## 重写技能执行
func perform_boss_skill(skill_name: String):
    match skill_name:
        SKILL_DEATH_SCYTHE:
            perform_skill_death_scythe()
        SKILL_UNDEAD_SUMMON:
            perform_skill_undead_summon()
        SKILL_SOUL_REAP:
            perform_skill_soul_reap()
        SKILL_DEATH_COIL:
            perform_skill_death_coil()
        _:
            super.perform_boss_skill(skill_name)

## 死亡镰刀 - 近战高伤害
func perform_skill_death_scythe():
    _log_boss_skill("死亡镰刀", "核心", "造成%.0f伤害" % death_scythe_damage)
    GameManager.spawn_floating_text(enemy.global_position, "💀 死亡镰刀!", Color.PURPLE)

    if GameManager.core:
        GameManager.core.take_damage(death_scythe_damage, "凋零死神-死亡镰刀")

    set_skill_cooldown(SKILL_DEATH_SCYTHE)

## 亡灵召唤 - 召唤小怪
func perform_skill_undead_summon():
    _log_boss_skill("亡灵召唤", "周围", "召唤%d个亡灵" % undead_summon_count)
    GameManager.spawn_floating_text(enemy.global_position, "👻 亡灵召唤!", Color.DARK_VIOLET)

    if GameManager.combat_manager:
        for i in range(undead_summon_count):
            var angle = (TAU / undead_summon_count) * i
            var offset = Vector2(cos(angle), sin(angle)) * 50.0
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "mutant_slime")

    set_skill_cooldown(SKILL_UNDEAD_SUMMON)

## 灵魂收割 - 生命偷取
func perform_skill_soul_reap():
    var heal_amount = soul_reap_damage * soul_reap_heal_ratio
    _log_boss_skill("灵魂收割", "核心", "造成%.0f伤害，恢复%.0f HP" % [soul_reap_damage, heal_amount])
    GameManager.spawn_floating_text(enemy.global_position, "⚫ 灵魂收割!", Color.DARK_RED)

    if GameManager.core:
        GameManager.core.take_damage(soul_reap_damage, "凋零死神-灵魂收割")

    # 恢复生命
    if enemy:
        enemy.hp = min(enemy.hp + heal_amount, enemy.max_hp)
        GameManager.spawn_floating_text(enemy.global_position + Vector2(0, -30),
            "+%.0f" % heal_amount, Color.RED)

    set_skill_cooldown(SKILL_SOUL_REAP)

## 死亡缠绕 - 控制技能
func perform_skill_death_coil():
    _log_boss_skill("死亡缠绕", "核心", "造成%.0f伤害+减速" % death_coil_damage)
    GameManager.spawn_floating_text(enemy.global_position, "🌀 死亡缠绕!", Color.DARK_GREEN)

    if GameManager.core:
        GameManager.core.take_damage(death_coil_damage, "凋零死神-死亡缠绕")

    set_skill_cooldown(SKILL_DEATH_COIL)

## 重写physics_process
func physics_process(delta: float) -> bool:
    var handled = super.physics_process(delta)
    if handled:
        return true

    # 自动释放技能
    if is_skill_ready(SKILL_SOUL_REAP) and enemy and enemy.hp < enemy.max_hp * 0.6:
        perform_skill_soul_reap()
    elif is_skill_ready(SKILL_DEATH_SCYTHE):
        perform_skill_death_scythe()
    elif is_skill_ready(SKILL_UNDEAD_SUMMON):
        perform_skill_undead_summon()
    elif is_skill_ready(SKILL_DEATH_COIL):
        perform_skill_death_coil()

    return false
