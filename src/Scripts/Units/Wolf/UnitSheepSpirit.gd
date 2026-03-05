class_name UnitSheepSpirit
extends Unit

func _ready():
    super._ready()
    # Need to connect `enemy_died` signal.
    GameManager.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy, _killer: Node):
    if !is_instance_valid(enemy): return
    if global_position.distance_to(enemy.global_position) > range_val:
        return

    # 根据等级确定克隆数量和属性继承比例
    # Lv.1: 1个克隆，50%属性
    # Lv.2: 1个克隆，75%属性
    # Lv.3: 2个克隆，75%属性
    var num_clones = 1 if level < 3 else 2
    var inherit = 0.5 if level < 2 else 0.75

    for i in range(num_clones):
        var offset = Vector2(randf() * 100 - 50, randf() * 100 - 50)

        # 记录羊灵克隆触发日志
        if AILogger:
            var enemy_name = enemy.type_key if "type_key" in enemy else "敌人"
            AILogger.totem_triggered("羊灵克隆", enemy_name, "生成克隆，继承%.0f%%属性" % (inherit * 100))
            AILogger.mechanic_sheep_clone(str(get_instance_id()), num_clones)
            # 记录[SKILL]单位技能日志
            AILogger.event("[SKILL] 羊灵 %s 触发 克隆技能 | 克隆目标: %s | 继承属性: %.0f%% | 持续时间: 10s" % [str(get_instance_id()), enemy_name, inherit * 100])
            if AIManager:
                AIManager.broadcast_text("[SKILL] 羊灵 %s 触发 克隆技能 | 克隆目标: %s | 继承属性: %.0f%% | 持续时间: 10s" % [str(get_instance_id()), enemy_name, inherit * 100])

        if GameManager.summon_manager:
            GameManager.summon_manager.create_summon({
                "unit_id": "enemy_clone",
                "position": enemy.global_position + offset,
                "source": self,
                "is_clone": true,
                "inherit_ratio": inherit,
                "lifetime": 10.0, # Not specified in prompt but good practice
                "faction": "player"
            })
