extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

func on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	# Handle generic data-driven core types
	if Constants.CORE_TYPES.has(GameManager.core_type):
		var core_data = Constants.CORE_TYPES[GameManager.core_type]
		var item_id = core_data.get("wave_item", "")

		if item_id != "" and GameManager.inventory_manager:
			var item_data = { "item_id": item_id, "count": 1 }
			if !GameManager.inventory_manager.add_item(item_data):
				GameManager.spawn_floating_text(Vector2.ZERO, "Inventory Full!", Color.RED)
