extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 雪原指挥官 - 冬季Boss C
## 主题：军团召唤、战术指挥、冰霜护盾、集结

# 技能配置
const SKILL_LEGION_SUMMON = "legion_summon"     # 军团召唤
const SKILL_TACTICAL_COMMAND = "tactical_command" # 战术指挥
const SKILL_FROST_SHIELD = "frost_shield"       # 冰霜护盾
const SKILL_RALLY_HORN = "rally_horn"           # 集结号角

# 技能参数
var legion_summon_count: int = 4
var tactical_command_buff: float = 0.25         # 25%增益
var frost_shield_absorb: float = 100.0
var rally_horn_duration: float = 5.0

# 状态
var is_frost_shield_active: bool = false
var frost_shield_amount: float = 0.0
var summoned_minions: Array = []

# 被动技能：军团集结 - 每12秒召唤2个冰霜骑士
const PASSIVE_LEGION_ASSEMBLE = "legion_assemble"
var legion_assemble_interval: float = 12.0
var legion_assemble_count: int = 2
var legion_assemble_timer: float = 0.0

# 被动技能：最后的命令 - HP归零时友军狂暴(+50%伤害攻速，每秒-5%HP)
const PASSIVE_FINAL_COMMAND = "final_command"
var final_command_damage_bonus: float = 0.50
var final_command_attack_speed_bonus: float = 0.50
var final_command_hp_drain: float = 0.05
var has_final_command_triggered: bool = false

func _ready():
    # 注册技能CD
    register_skill(SKILL_LEGION_SUMMON, 15.0)   # 15秒CD
    register_skill(SKILL_TACTICAL_COMMAND, 12.0) # 12秒CD
    register_skill(SKILL_FROST_SHIELD, 15.0)    # 15秒CD
    register_skill(SKILL_RALLY_HORN, 20.0)      # 20秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
    # 设置Boss元数据
    enemy_data["boss_name"] = "SnowCommander"
    enemy_data["boss_title"] = "雪原指挥官"
    enemy_data["max_phase"] = 2
    enemy_data["phase_hp_thresholds"] = [0.5]

    super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
    match new_phase:
        2:
            # 第二阶段：军团强化
            legion_summon_count = 6
            tactical_command_buff = 0.4
            frost_shield_absorb = 150.0
            _log_boss_skill("指挥官觉醒", "军团", "召唤更多士兵")
            # 立即召唤增援
            perform_skill_legion_summon()

## 重写技能执行
func perform_boss_skill(skill_name: String):
    match skill_name:
        SKILL_LEGION_SUMMON:
            perform_skill_legion_summon()
        SKILL_TACTICAL_COMMAND:
            perform_skill_tactical_command()
        SKILL_FROST_SHIELD:
            perform_skill_frost_shield()
        SKILL_RALLY_HORN:
            perform_skill_rally_horn()
        _:
            super.perform_boss_skill(skill_name)

## 军团召唤 - 召唤多个小怪
func perform_skill_legion_summon():
    _log_boss_skill("军团召唤", "周围", "召唤%d个士兵" % legion_summon_count)
    GameManager.spawn_floating_text(enemy.global_position, "📯 军团召唤!", Color.LIGHT_BLUE)

    if GameManager.combat_manager:
        for i in range(legion_summon_count):
            var angle = (TAU / legion_summon_count) * i
            var offset = Vector2(cos(angle), sin(angle)) * 60.0
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "yeti")

    set_skill_cooldown(SKILL_LEGION_SUMMON)

## 战术指挥 - Buff友军
func perform_skill_tactical_command():
    _log_boss_skill("战术指挥", "友军", "攻击力+%.0f%%" % (tactical_command_buff * 100))
    GameManager.spawn_floating_text(enemy.global_position, "📢 战术指挥!", Color.CYAN)

    # 对核心造成伤害（模拟指挥攻击）
    if GameManager.core:
        GameManager.core.take_damage(tactical_command_buff * 100, "雪原指挥官-战术指挥")

    set_skill_cooldown(SKILL_TACTICAL_COMMAND)

## 冰霜护盾 - 防御技能
func perform_skill_frost_shield():
    _log_boss_skill("冰霜护盾", "自身", "吸收%.0f伤害" % frost_shield_absorb)
    GameManager.spawn_floating_text(enemy.global_position, "🛡️ 冰霜护盾!", Color.BLUE)

    is_frost_shield_active = true
    frost_shield_amount = frost_shield_absorb

    set_skill_cooldown(SKILL_FROST_SHIELD)

## 集结号角 - 强化召唤物
func perform_skill_rally_horn():
    _log_boss_skill("集结号角", "全军团", "全体强化")
    GameManager.spawn_floating_text(enemy.global_position, "🎺 集结号角!", Color.WHITE)

    # 对核心造成大量伤害（模拟军团攻击）
    if GameManager.core:
        GameManager.core.take_damage(80.0, "雪原指挥官-集结号角")

    # 召唤额外增援
    if GameManager.combat_manager:
        for i in range(3):
            var offset = Vector2(randf_range(-70, 70), randf_range(-70, 70))
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "golem")

    set_skill_cooldown(SKILL_RALLY_HORN)

## 重写physics_process以自动释放技能和处理被动
func physics_process(delta: float) -> bool:
    var handled = super.physics_process(delta)
    if handled:
        return true

    # 自动释放技能
    if is_skill_ready(SKILL_RALLY_HORN):
        perform_skill_rally_horn()
    elif is_skill_ready(SKILL_LEGION_SUMMON):
        perform_skill_legion_summon()
    elif is_skill_ready(SKILL_TACTICAL_COMMAND):
        perform_skill_tactical_command()
    elif is_skill_ready(SKILL_FROST_SHIELD) and not is_frost_shield_active:
        perform_skill_frost_shield()

    # 被动：军团集结 - 定期召唤士兵
    legion_assemble_timer += delta
    if legion_assemble_timer >= legion_assemble_interval:
        legion_assemble_timer = 0.0
        _apply_legion_assemble()

    return false

## 被动：军团集结 - 每12秒召唤2个冰霜骑士
func _apply_legion_assemble():
    _log_boss_skill("军团集结", "周围", "召唤%d个冰霜骑士" % legion_assemble_count)
    GameManager.spawn_floating_text(enemy.global_position, "⚔️ 军团集结!", Color.LIGHT_BLUE)

    if GameManager.combat_manager:
        for i in range(legion_assemble_count):
            var angle = (TAU / legion_assemble_count) * i
            var offset = Vector2(cos(angle), sin(angle)) * 80.0
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "yeti")

## 重写on_death以实现最后的命令被动
func on_death(killer_unit) -> bool:
    # 被动：最后的命令 - 死亡时触发友军狂暴
    if not has_final_command_triggered:
        has_final_command_triggered = true
        _trigger_final_command()

    return super.on_death(killer_unit)

## 触发最后的命令
func _trigger_final_command():
    _log_boss_skill("最后的命令", "全军团", "狂暴!伤害+%.0f%% 攻速+%.0f%%" % [final_command_damage_bonus * 100, final_command_attack_speed_bonus * 100])
    GameManager.spawn_floating_text(enemy.global_position, "⚡ 最后的命令!", Color.RED)

    # 对场上所有友军施加狂暴效果（简化实现：召唤额外强力单位）
    if GameManager.combat_manager:
        for i in range(4):
            var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "golem")
