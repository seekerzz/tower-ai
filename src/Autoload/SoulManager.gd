extends Node

signal soul_count_changed(new_count: int, delta: int)

var current_souls: int = 0
var max_souls: int = 500

func add_souls_from_enemy_death(enemy_data: Dictionary) -> void:
    current_souls = min(current_souls + 1, max_souls)
    soul_count_changed.emit(current_souls, 1)
    print("[SoulManager] Enemy died, souls: ", current_souls, " (+1)")

func add_souls_from_unit_merge(unit_data: Dictionary) -> void:
    current_souls = min(current_souls + 10, max_souls)
    soul_count_changed.emit(current_souls, 10)
    print("[SoulManager] Unit merged, souls: ", current_souls, " (+10)")

func add_souls(amount: int, _source: String = "") -> void:
    current_souls = min(current_souls + amount, max_souls)
    soul_count_changed.emit(current_souls, amount)

func get_soul_damage_bonus() -> int:
    return current_souls
