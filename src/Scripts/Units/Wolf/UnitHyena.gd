class_name UnitHyena
extends Unit

func _ready():
    super._ready()
    attack_performed.connect(_on_attack_hit)

func _on_attack_hit(enemy):
    if enemy and is_instance_valid(enemy):
        var enemy_hp_percent = enemy.hp / max(1.0, enemy.max_hp)

        if enemy_hp_percent < 0.25:
            var extra_hits = 1 if level < 3 else 2
            var damage_percent = 0.2 if level < 2 else 0.4
            for i in range(extra_hits):
                await get_tree().create_timer(0.1 * (i+1)).timeout
                if is_instance_valid(enemy):
                    enemy.take_damage(damage * damage_percent, self, "physical", self)
