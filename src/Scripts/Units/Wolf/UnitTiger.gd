class_name UnitTiger
extends Unit

var soul_stacks: int = 0
var max_soul_stacks: int = 8

func _ready():
    super._ready()
    GameManager.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy, killer: Node):
    if killer == self:
        soul_stacks = min(soul_stacks + 1, max_soul_stacks)
        _update_crit()

func _update_crit():
    var crit_bonus = soul_stacks * 0.025
    # Unit.gd has crit_rate
    crit_rate = unit_data.get("crit_rate", 0.0) + crit_bonus

func _on_skill_activated():
    _cast_meteor_shower()

func _cast_meteor_shower():
    var meteor_count = 8 if level < 2 else 10
    # Use CombatManager meteor logic but it targets screen center usually
    # Or just spawn projectiles.
    # The prompt says:
    # for i in range(meteor_count):
    #     await get_tree().create_timer(i * 0.2).timeout
    #     _spawn_meteor()

    for i in range(meteor_count):
        await get_tree().create_timer(0.2).timeout
        _spawn_meteor()

func _spawn_meteor():
    # Random position around unit? Or screen?
    # Usually meteor shower targets enemies.
    # UnitLion uses CombatManager logic? No, UnitLion uses circular shockwave.
    # Tiger uses meteor shower.
    # I'll target random enemies.

    if !GameManager.combat_manager: return

    var target = GameManager.combat_manager.find_nearest_enemy(global_position, 9999.0)
    var target_pos = Vector2.ZERO
    if target:
        target_pos = target.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
    else:
        target_pos = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))

    var start_pos = target_pos + Vector2(0, -600)

    var stats = {
        "damage": damage * 2.0, # Meteor damage? Not specified, assume decent dmg
        "proj_override": "meteor", # Assuming meteor projectile exists or fallback
        "speed": 600.0,
        "is_meteor": true
    }

    GameManager.combat_manager.spawn_projectile(self, start_pos, null, {
        "target_pos": target_pos,
        "damage": damage * 1.5,
        "proj_override": "fireball", # Fallback if meteor not available
        "speed": 500.0,
        "damageType": "fire"
    })
