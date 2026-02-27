extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var moonwell_pool: float = 0.0

func on_damage_dealt_by_unit(_unit, amount: float):
	moonwell_pool += amount * 0.1

func on_wave_started():
	if GameManager.inventory_manager:
		var item_data = { "item_id": "moon_water", "count": 1 }
		if !GameManager.inventory_manager.add_item(item_data):
			GameManager.spawn_floating_text(Vector2.ZERO, "Inventory Full!", Color.RED)

func consume_pool() -> float:
	var val = moonwell_pool
	moonwell_pool = 0.0
	return val
