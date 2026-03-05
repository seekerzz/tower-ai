extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 熔岩巨人 - 夏季Boss B
## 主题：熔岩、防御、亡语爆发

# 技能配置
const SKILL_MAGMA_ARMOR = "magma_armor"         # 熔岩护甲
const SKILL_MAGMA_JET = "magma_jet"             # 岩浆喷射
const SKILL_EARTH_SHATTER = "earth_shatter"     # 大地碎裂
const SKILL_MAGMA_BURST = "magma_burst"         # 熔岩爆发(亡语)

# 技能参数
var magma_armor_defense: float = 0.4            # 40%减伤
var magma_armor_damage: float = 20.0            # 反伤
var magma_jet_damage: float = 50.0
var earth_shatter_damage: float = 80.0
var magma_burst_damage: float = 150.0

# 状态
var is_magma_armor_active: bool = false

func _ready():
    # 注册技能CD
    register_skill(SKILL_MAGMA_ARMOR, 15.0)     # 15秒CD
    register_skill(SKILL_MAGMA_JET, 8.0)        # 8秒CD
    register_skill(SKILL_EARTH_SHATTER, 12.0)   # 12秒CD
    # 亡语技能不需要CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
    # 设置Boss元数据
    enemy_data["boss_name"] = "MagmaColossus"
    enemy_data["boss_title"] = "熔岩巨人"
    enemy_data["max_phase"] = 2
    enemy_data["phase_hp_thresholds"] = [0.4]   # 40%血量进入第二阶段

    super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
    match new_phase:
        2:
            # 第二阶段：激活熔岩护甲
            _activate_magma_armor()
            earth_shatter_damage = 120.0
            _log_boss_skill("熔岩觉醒", "自身", "护甲强化")

## 重写技能执行
func perform_boss_skill(skill_name: String):
    match skill_name:
        SKILL_MAGMA_ARMOR:
            perform_skill_magma_armor()
        SKILL_MAGMA_JET:
            perform_skill_magma_jet()
        SKILL_EARTH_SHATTER:
            perform_skill_earth_shatter()
        _:
            super.perform_boss_skill(skill_name)

## 熔岩护甲 - 防御+反伤
func perform_skill_magma_armor():
    _activate_magma_armor()
    set_skill_cooldown(SKILL_MAGMA_ARMOR)

func _activate_magma_armor():
    _log_boss_skill("熔岩护甲", "自身", "减伤%.0f%%+反伤" % (magma_armor_defense * 100))
    GameManager.spawn_floating_text(enemy.global_position, "🔥 熔岩护甲!", Color.ORANGE_RED)
    is_magma_armor_active = true

## 岩浆喷射 - 远程攻击
func perform_skill_magma_jet():
    _log_boss_skill("岩浆喷射", "核心", "造成%.0f伤害" % magma_jet_damage)
    GameManager.spawn_floating_text(enemy.global_position, "🌋 岩浆喷射!", Color.RED)

    if GameManager.core:
        GameManager.core.take_damage(magma_jet_damage, "熔岩巨人-岩浆喷射")

    set_skill_cooldown(SKILL_MAGMA_JET)

## 大地碎裂 - AOE伤害+眩晕
func perform_skill_earth_shatter():
    _log_boss_skill("大地碎裂", "全屏", "造成%.0f伤害+眩晕2秒" % earth_shatter_damage)
    GameManager.spawn_floating_text(enemy.global_position, "💥 大地碎裂!", Color.DARK_ORANGE)

    if GameManager.core:
        GameManager.core.take_damage(earth_shatter_damage, "熔岩巨人-大地碎裂")

    # 眩晕所有防御塔2秒
    _stun_all_towers(2.0)

    # 召唤岩浆小怪
    if GameManager.combat_manager:
        for i in range(2):
            var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "crab")

    set_skill_cooldown(SKILL_EARTH_SHATTER)

## 眩晕所有防御塔
func _stun_all_towers(duration: float):
    if not GameManager.grid_manager:
        return

    var stun_count = 0
    for pos in GameManager.grid_manager.units.keys():
        var unit = GameManager.grid_manager.units[pos]
        if is_instance_valid(unit) and not unit.get_meta("is_stunned", false):
            _apply_stun_effect(unit, duration)
            stun_count += 1

    if stun_count > 0:
        _log_boss_skill("大地碎裂", "防御塔", "眩晕%d个防御塔%.1f秒" % [stun_count, duration])

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
    if is_skill_ready(SKILL_EARTH_SHATTER):
        perform_skill_earth_shatter()
    elif is_skill_ready(SKILL_MAGMA_JET):
        perform_skill_magma_jet()
    elif is_skill_ready(SKILL_MAGMA_ARMOR) and not is_magma_armor_active:
        perform_skill_magma_armor()

    return false

## 重写on_death实现亡语效果
func on_death(killer_unit) -> bool:
    # 熔岩爆发亡语
    _log_boss_skill("熔岩爆发", "全屏", "亡语造成%.0f伤害" % magma_burst_damage)
    GameManager.spawn_floating_text(enemy.global_position, "💥 熔岩爆发!", Color.RED)

    if GameManager.core:
        GameManager.core.take_damage(magma_burst_damage, "熔岩巨人-熔岩爆发")

    # 召唤最后的岩浆怪
    if GameManager.combat_manager:
        for i in range(3):
            var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
            GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
                enemy.global_position + offset, "crab")

    # 调用父类死亡处理
    return super.on_death(killer_unit)
