class_name UnitBloodFood
extends Unit

func _ready():
    super._ready()
    TotemManager.totem_resource_changed.connect(_on_totem_resource_changed)
    _update_buff()

func _on_totem_resource_changed(totem_id: String, _current: int, _max_value: int):
    # 只响应狼图腾的魂魄变化
    if totem_id == "wolf":
        _update_buff()

func _update_buff():
    var bonus_per_soul = 0.005 if level < 3 else 0.008
    var total_bonus = TotemManager.get_resource("wolf") * bonus_per_soul
    GameManager.apply_global_buff("damage_percent", total_bonus)
