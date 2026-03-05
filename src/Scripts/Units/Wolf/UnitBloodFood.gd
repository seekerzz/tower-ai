class_name UnitBloodFood
extends Unit

# 血食 - 血魂充能与血祭技能
# Lv.1-3: 基于狼图腾魂魄数量提供全局伤害加成
# Lv.3: 血祭技能 - 自杀治疗核心并给狼族加攻击buff

# 血魂层数机制
var blood_soul_stacks: int = 0
var max_blood_soul_stacks: int = 10
var bonus_per_stack: float = 0.02  # 每层+2%

# 血祭技能
var can_sacrifice: bool = false  # Lv.3才能使用血祭

func _ready():
    super._ready()
    TotemManager.totem_resource_changed.connect(_on_totem_resource_changed)
    GameManager.enemy_died.connect(_on_enemy_died)
    _update_buff()

func _on_totem_resource_changed(totem_id: String, _current: int, _max_value: int):
    # 只响应狼图腾的魂魄变化
    if totem_id == "wolf":
        _update_buff()

func _on_enemy_died(enemy, killer_unit):
    # 检查是否是狼族单位击杀的敌人
    if not is_instance_valid(killer_unit):
        return
    if not killer_unit.has_method("get"):
        return

    # 检查killer是否是狼族单位
    var is_wolf_unit = false
    if killer_unit.get("type_key"):
        var wolf_units = ["wolf", "tiger", "dog", "hyena", "fox", "lion", "blood_meat"]
        if killer_unit.type_key in wolf_units:
            is_wolf_unit = true
    if killer_unit.get("unit_data") and killer_unit.unit_data.get("faction") == "wolf_totem":
        is_wolf_unit = true

    # 狼族击杀时获得血魂层数
    if is_wolf_unit and blood_soul_stacks < max_blood_soul_stacks:
        blood_soul_stacks = min(blood_soul_stacks + 1, max_blood_soul_stacks)
        _update_buff()

        # 日志输出
        if AILogger:
            AILogger.event("[RESOURCE] 血食 获得血魂层数 | 当前层数: %d/%d" % [blood_soul_stacks, max_blood_soul_stacks])

func _update_buff():
    # 基础魂魄加成
    var soul_bonus_per = 0.005 if level < 3 else 0.008
    var soul_bonus = TotemManager.get_resource("wolf") * soul_bonus_per

    # 血魂层数加成
    var blood_soul_bonus = blood_soul_stacks * bonus_per_stack

    var total_bonus = soul_bonus + blood_soul_bonus
    GameManager.apply_global_buff("damage_percent", total_bonus)

    # Lv.3解锁血祭技能
    can_sacrifice = (level >= 3)

# 血祭技能 - 主动技能
func activate_sacrifice():
    """
    血祭：自杀，治疗核心5%并给所有狼族+30%攻击持续5秒
    只能在Lv.3时使用
    """
    if level < 3:
        print("[BloodFood] 血祭技能需要Lv.3")
        return false

    if not is_instance_valid(self):
        return false

    # 治疗核心5%
    var heal_amount = GameManager.max_core_health * 0.05
    GameManager.heal_core(heal_amount)

    # 给所有狼族单位+30%攻击buff
    var wolf_units = get_tree().get_nodes_in_group("units")
    var buff_count = 0
    for unit in wolf_units:
        if not is_instance_valid(unit):
            continue
        var is_wolf = false
        if unit.get("unit_data") and unit.unit_data.get("faction") == "wolf_totem":
            is_wolf = true
        if unit.get("type_key"):
            var wolf_types = ["wolf", "tiger", "dog", "hyena", "fox", "lion", "blood_meat"]
            if unit.type_key in wolf_types:
                is_wolf = true

        if is_wolf:
            # 添加攻击力buff
            if unit.has_method("apply_temporary_buff"):
                unit.apply_temporary_buff("attack_percent", 0.30, 5.0)
                buff_count += 1
            elif unit.has_method("add_buff"):
                unit.add_buff("attack", 0.30, 5.0)
                buff_count += 1

    # 日志输出
    if AILogger:
        AILogger.event("[SKILL] 血食 触发血祭 | 治疗核心: %.0f | 狼族buff: %d个" % [heal_amount, buff_count])
    if AIManager:
        AIManager.broadcast_text("【血祭】血食牺牲自己，治疗核心%.0f HP，%d个狼族单位获得+30%%攻击（5秒）" % [heal_amount, buff_count])

    # 显示特效
    GameManager.spawn_floating_text(global_position, "血祭!", Color.RED)

    # 销毁自己
    die()

    return true

# HTTP API调用的血祭接口
func sacrifice_command() -> Dictionary:
    """供AI Player调用的血祭命令"""
    var result = activate_sacrifice()
    return {
        "success": result,
        "unit": type_key if type_key else "blood_meat",
        "level": level,
        "blood_soul_stacks": blood_soul_stacks
    }
