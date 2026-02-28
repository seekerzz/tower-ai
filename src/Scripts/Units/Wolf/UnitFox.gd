class_name UnitFox
extends Unit

@export var charm_chance: float = 0.20  # Lv1: 从15%提升到20%
var charmed_enemies: Array[Enemy] = []
var max_charms: int = 1

func _ready():
    super._ready()
    max_charms = 1
    if level >= 2:
        charm_chance = 0.30  # Lv2: 从25%提升到30%
    if level >= 3:
        max_charms = 2

func take_damage(amount: float, source_enemy = null):
    if source_enemy and is_instance_valid(source_enemy) and source_enemy is Enemy:
        _on_attacked_by_enemy(source_enemy)

    super.take_damage(amount, source_enemy)

func _on_attacked_by_enemy(enemy: Enemy):
    if charmed_enemies.size() < max_charms and randf() < charm_chance:
        if enemy.get("faction") != "player":
            _charm_enemy(enemy)

func _charm_enemy(enemy: Enemy):
    if enemy.has_method("apply_charm"):
        var duration = 3.0
        if level >= 2:
            duration = 4.0
        enemy.apply_charm(self, duration)
        charmed_enemies.append(enemy)

        GameManager.spawn_floating_text(enemy.global_position, "魅惑!", Color.MAGENTA)

        var effect = load("res://src/Scripts/Effects/CharmEffect.gd").new()
        enemy.add_child(effect)

        # 连接死亡信号
        if not enemy.died.is_connected(_on_charmed_enemy_died):
            enemy.died.connect(_on_charmed_enemy_died.bind(enemy))

func _on_charmed_enemy_died(enemy: Enemy):
    if enemy in charmed_enemies:
        charmed_enemies.erase(enemy)
