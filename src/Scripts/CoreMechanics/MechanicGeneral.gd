extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

func on_wave_started():
	# Handle generic data-driven core types
	if GameManager.data_manager and GameManager.data_manager.data.has("CORE_TYPES") and GameManager.data_manager.data["CORE_TYPES"].has(GameManager.core_type):
		var core_data = GameManager.data_manager.data["CORE_TYPES"][GameManager.core_type]
		var item_id = core_data.get("wave_item", "")

		if item_id != "" and GameManager.inventory_manager:
			var item_data = { "item_id": item_id, "count": 1 }
			if !GameManager.inventory_manager.add_item(item_data):
				GameManager.spawn_floating_text(Vector2.ZERO, "Inventory Full!", Color.RED)
