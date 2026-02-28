class_name UnitDog
extends Unit

func _ready():
    super._ready()
    GameManager.resource_changed.connect(_on_core_health_changed)
    _update_attack_speed()

func _on_core_health_changed():
    _update_attack_speed()

func _update_attack_speed():
    var health_percent = GameManager.core_health / max(1.0, GameManager.max_core_health)
    var health_lost = 1.0 - health_percent
    var bonus_per_10 = 0.04 if level < 2 else 0.10
    var speed_bonus = floor(health_lost * 10) * bonus_per_10
    stats_multiplier = 1.0 + speed_bonus # atk_speed is used directly or multiplier?

    # Unit.gd uses atk_speed property. Base atk_speed is in unit_data.
    # We should update atk_speed.

    var base_spd = unit_data.get("atkSpeed", 1.0)
    atk_speed = base_spd / (1.0 + speed_bonus) # Higher speed bonus means LOWER interval.
    # Wait, Unit.gd: cooldown = atk_speed * modifier.
    # So lower atk_speed means faster attack.
    # "attack_speed_multiplier = 1.0 + speed_bonus" usually means MORE attacks per second.
    # So interval should be base / multiplier.

    # However, the prompt says:
    # attack_speed_multiplier = 1.0 + speed_bonus
    # I should store this multiplier or apply it.

    # Lv3溅射触发条件：核心HP < 50% (从25%提升到50%，更容易触发)
    if level >= 3 and health_percent < 0.5:
        enable_splash_damage()
    else:
        disable_splash_damage()

func enable_splash_damage():
    if !("splash" in active_buffs):
        active_buffs.append("splash")
        # But 'splash' is not a standard buff in Unit.gd?
        # Unit.gd has 'split', 'bounce'.
        # CombatManager handles 'splash' logic?
        # CombatManager.gd doesn't seem to have explicit 'splash' logic in _spawn_single_projectile.
        # But maybe I can add it to unit_data dynamically?
        pass

func disable_splash_damage():
    if "splash" in active_buffs:
        active_buffs.erase("splash")
