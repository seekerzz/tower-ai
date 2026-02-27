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

    var num_clones = 1 if level < 3 else 2
    var inherit = 0.4 if level < 2 else 0.6

    for i in range(num_clones):
        var offset = Vector2(randf() * 100 - 50, randf() * 100 - 50)

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
