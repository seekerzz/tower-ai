extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

func on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	if GameManager.inventory_manager:
		var item_data = { "item_id": "rice_ear", "count": 1 }
		if !GameManager.inventory_manager.add_item(item_data):
			GameManager.spawn_floating_text(Vector2.ZERO, "Inventory Full!", Color.RED)
