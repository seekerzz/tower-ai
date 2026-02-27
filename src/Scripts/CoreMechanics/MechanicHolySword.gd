extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

func on_wave_started():
	if GameManager.inventory_manager:
		var item_data = { "item_id": "holy_sword", "count": 1 }
		if !GameManager.inventory_manager.add_item(item_data):
			GameManager.spawn_floating_text(Vector2.ZERO, "Inventory Full!", Color.RED)
