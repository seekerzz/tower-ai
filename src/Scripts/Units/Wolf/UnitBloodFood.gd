class_name UnitBloodFood
extends Unit

func _ready():
    super._ready()
    SoulManager.soul_count_changed.connect(_on_soul_changed)
    _update_buff()

func _on_soul_changed(_new_count: int, _delta: int):
    _update_buff()

func _update_buff():
    var bonus_per_soul = 0.005 if level < 3 else 0.008
    var total_bonus = SoulManager.current_souls * bonus_per_soul
    GameManager.apply_global_buff("damage_percent", total_bonus)
