extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 冰霜巨魔 - 冬季Boss B
## 主题：冰霜护甲、狂暴、寒冰、毁灭

# 技能配置
const SKILL_FROST_ARMOR = "frost_armor"         # 冰霜护甲
const SKILL_RAMPAGE_CHARGE = "rampage_charge"   # 狂暴冲撞
const SKILL_ICE_BREATH = "ice_breath"           # 寒冰吐息
const SKILL_DESTRUCTION_STRIKE = "destruction_strike" # 毁灭之击

# 技能参数
var frost_armor_defense: float = 0.5            # 50%减伤
var frost_armor_thorns: float = 15.0            # 反伤
var rampage_charge_damage: float = 60.0
var ice_breath_damage: float = 40.0
var ice_breath_slow: float = 0.4                # 40%减速
var destruction_strike_damage: float = 120.0

# 状态
var is_frost_armor_active: bool = false
var is_rampaging: bool = false

func _ready():
    # 注册技能CD
    register_skill(SKILL_FROST_ARMOR, 15.0)     # 15秒CD
    register_skill(SKILL_RAMPAGE_CHARGE, 10.0)  # 10秒CD
    register_skill(SKILL_ICE_BREATH, 8.0)       # 8秒CD
    register_skill(SKILL_DESTRUCTION_STRIKE, 12.0) # 12秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
    # 设置Boss元数据
    enemy_data["boss_name"] = "FrostTroll"
    enemy_data["boss_title"] = "冰霜巨魔"
    enemy_data["max_phase"] = 2
    enemy_data["phase_hp_thresholds"] = [0.5]

    super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
    match new_phase:
        2:
            # 第二阶段：进入狂暴状态
            is_rampaging = true
            destruction_strike_damage = 180.0
            rampage_charge_damage = 90.0
            _log_boss_skill("狂暴觉醒", "自身", "攻击力大幅提升")

## 重写技能执行
func perform_boss_skill(skill_name: String):
    match skill_name:
        SKILL_FROST_ARMOR:
            perform_skill_frost_armor()
        SKILL_RAMPAGE_CHARGE:
            perform_skill_rampage_charge()
        SKILL_ICE_BREATH:
            perform_skill_ice_breath()
        SKILL_DESTRUCTION_STRIKE:
            perform_skill_destruction_strike()
        _:
            super.perform_boss_skill(skill_name)

## 冰霜护甲 - 防御+反伤
func perform_skill_frost_armor():
    _log_boss_skill("冰霜护甲", "自身", "减伤%.0f%%+反伤%.0f" % [frost_armor_defense * 100, frost_armor_thorns])
    GameManager.spawn_floating_text(enemy.global_position, "❄️ 冰霜护甲!", Color.CYAN)

    is_frost_armor_active = true
    set_skill_cooldown(SKILL_FROST_ARMOR)

## 狂暴冲撞 - 冲锋技能
func perform_skill_rampage_charge():
    var damage = rampage_charge_damage * 1.5 if is_rampaging else rampage_charge_damage
    _log_boss_skill("狂暴冲撞", "核心", "造成%.0f伤害" % damage)
    GameManager.spawn_floating_text(enemy.global_position, "🐃 狂暴冲撞!", Color.BLUE)

    if GameManager.core:
        GameManager.core.take_damage(damage, "冰霜巨魔-狂暴冲撞")

    set_skill_cooldown(SKILL_RAMPAGE_CHARGE)

## 寒冰吐息 - 范围冰冻
func perform_skill_ice_breath():
    _log_boss_skill("寒冰吐息", "全屏", "造成%.0f伤害+减速" % ice_breath_damage)
    GameManager.spawn_floating_text(enemy.global_position, "🌬️ 寒冰吐息!", Color.LIGHT_BLUE)

    if GameManager.core:
        GameManager.core.take_damage(ice_breath_damage, "冰霜巨魔-寒冰吐息")

    # 召唤冰怪
    if GameManager.combat_manager:
        for i in range(2):
            var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "yeti")

    set_skill_cooldown(SKILL_ICE_BREATH)

## 毁灭之击 - 重击+眩晕
func perform_skill_destruction_strike():
    var damage = destruction_strike_damage * 1.3 if is_rampaging else destruction_strike_damage
    var stun_duration = 2.0  # 眩晕2秒

    _log_boss_skill("毁灭之击", "核心", "造成%.0f重击+眩晕%.0f秒" % [damage, stun_duration])
    GameManager.spawn_floating_text(enemy.global_position, "💥 毁灭之击!", Color.DARK_BLUE)

    if GameManager.core:
        GameManager.core.take_damage(damage, "冰霜巨魔-毁灭之击")

    # 眩晕随机防御塔2秒
    _stun_random_towers(1, stun_duration)

    set_skill_cooldown(SKILL_DESTRUCTION_STRIKE)

## 眩晕随机防御塔
func _stun_random_towers(count: int, duration: float):
    if not GameManager.grid_manager:
        return

    # 获取所有部署的防御塔
    var deployed_units = []
    for pos in GameManager.grid_manager.units.keys():
        var unit = GameManager.grid_manager.units[pos]
        if is_instance_valid(unit) and not unit.get_meta("is_stunned", false):
            deployed_units.append(unit)

    # 随机选择指定数量的防御塔进行眩晕
    deployed_units.shuffle()
    var stun_count = min(count, deployed_units.size())

    for i in range(stun_count):
        var target_unit = deployed_units[i]
        _apply_stun_effect(target_unit, duration)

    if stun_count > 0:
        _log_boss_skill("毁灭之击", "防御塔", "眩晕%d个防御塔%.1f秒" % [stun_count, duration])

## 应用眩晕效果
func _apply_stun_effect(target_unit: Node, duration: float):
    var stun_effect = preload("res://src/Scripts/Effects/StunEffect.gd").new(duration)
    stun_effect.setup(target_unit, self, {"duration": duration})
    target_unit.add_child(stun_effect)

    GameManager.spawn_floating_text(target_unit.global_position, "💫 眩晕!", Color.YELLOW)

## 重写physics_process
func physics_process(delta: float) -> bool:
    var handled = super.physics_process(delta)
    if handled:
        return true

    # 自动释放技能
    if is_skill_ready(SKILL_DESTRUCTION_STRIKE):
        perform_skill_destruction_strike()
    elif is_skill_ready(SKILL_RAMPAGE_CHARGE):
        perform_skill_rampage_charge()
    elif is_skill_ready(SKILL_ICE_BREATH):
        perform_skill_ice_breath()
    elif is_skill_ready(SKILL_FROST_ARMOR) and not is_frost_armor_active:
        perform_skill_frost_armor()

    return false
