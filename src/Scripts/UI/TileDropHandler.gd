extends Control

var tile_ref # Reference to Tile (Node2D)

func setup(tile):
	tile_ref = tile
	# Size is 60x60
	size = Vector2(60, 60)
	position = Vector2(-30, -30) # Centered
	mouse_filter = MOUSE_FILTER_PASS

func _can_drop_data(at_position, data):
	if !data or !data.has("source"): return false

	if data.source == "inventory":
		if data.item:
			var item_id = data.item.get("item_id", "")
			if "trap" in item_id or item_id in ["poison_trap", "fang_trap"]:
				var grid_pos = Vector2i(tile_ref.x, tile_ref.y)
				GameManager.grid_manager.update_placement_preview(grid_pos, tile_ref.global_position, item_id)
				return GameManager.grid_manager.can_place_item_at(grid_pos, item_id)

		return true

	if GameManager.is_wave_active: return false

	if data.source == "grid" or data.source == "bench":
		return true
	return false

func _drop_data(at_position, data):
	if !tile_ref: return

	if data.source == "inventory":
		_handle_inventory_drop(data)
	elif data.source == "bench":
		# Call GridManager to place from bench
		GameManager.grid_manager.handle_bench_drop_at(tile_ref, data)
	elif data.source == "grid":
		# Call GridManager to move unit
		GameManager.grid_manager.handle_grid_move_at(tile_ref, data)

func _handle_inventory_drop(data):
	var item_data = data.item
	var item_id = item_data.get("item_id", "")

	# Trap Logic
	if "trap" in item_id or Constants.BARRICADE_TYPES.has(item_id) or item_id in ["poison_trap", "fang_trap"]:
		var grid_pos = Vector2i(tile_ref.x, tile_ref.y)
		# Use shared validation logic
		if GameManager.grid_manager.can_place_item_at(grid_pos, item_id):
			# Determine trap type mapping
			var trap_type = ""

			# 1. Direct match in BARRICADE_TYPES
			if Constants.BARRICADE_TYPES.has(item_id):
				trap_type = item_id
			# 2. Legacy Mapping for poison/fang which use _trap suffix in items but short keys in barricades
			elif item_id == "poison_trap":
				trap_type = "poison"
			elif item_id == "fang_trap":
				trap_type = "fang"
			# 3. Fallback: default to poison if likely intended but unknown?
			# Or better: check for specific substring matches if not found
			elif "poison" in item_id:
				trap_type = "poison"
			elif "fang" in item_id:
				trap_type = "fang"

			if trap_type != "":
				GameManager.grid_manager.spawn_trap_custom(grid_pos, trap_type)
				GameManager.inventory_manager.remove_item(data.slot_index)
			else:
				print("TileDropHandler: Unknown trap type for item_id: ", item_id)
