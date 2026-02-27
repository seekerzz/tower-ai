class_name MechanicWolfTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var base_damage: int = 15

func _ready():
    var timer = Timer.new()
    timer.wait_time = attack_interval
    timer.timeout.connect(_on_totem_attack)
    add_child(timer)
    timer.start()

func _on_totem_attack():
    var targets = get_nearest_enemies(3)
    for enemy in targets:
        var damage = base_damage + SoulManager.get_soul_damage_bonus()
        deal_damage(enemy, damage)
