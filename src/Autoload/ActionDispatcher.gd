extends Node

# ===== 信号 =====
signal action_dispatched(action_type: String, data: Dictionary)
signal unit_purchased(unit_key: String, target_zone: String, target_pos: Variant)
signal shop_refreshed(shop_units: Array)
signal operation_failed(operation: String, reason: String)
signal unit_moved(from_zone: String, from_pos: Variant, to_zone: String, to_pos: Variant, unit_data: Dictionary)
signal unit_sold(zone: String, pos: Variant, gold_refund: int)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Listen to underlying BoardController signals and re-emit them to standardize the bus
	if BoardController:
		if not BoardController.unit_purchased.is_connected(_on_board_unit_purchased):
			BoardController.unit_purchased.connect(_on_board_unit_purchased)
		if not BoardController.shop_refreshed.is_connected(_on_board_shop_refreshed):
			BoardController.shop_refreshed.connect(_on_board_shop_refreshed)
		if not BoardController.operation_failed.is_connected(_on_board_operation_failed):
			BoardController.operation_failed.connect(_on_board_operation_failed)
		if not BoardController.unit_moved.is_connected(_on_board_unit_moved):
			BoardController.unit_moved.connect(_on_board_unit_moved)
		if not BoardController.unit_sold.is_connected(_on_board_unit_sold):
			BoardController.unit_sold.connect(_on_board_unit_sold)

# ===== 重新发送底层信号 =====
func _on_board_unit_purchased(unit_key: String, target_zone: String, target_pos: Variant):
	unit_purchased.emit(unit_key, target_zone, target_pos)

func _on_board_shop_refreshed(shop_units: Array):
	shop_refreshed.emit(shop_units)

func _on_board_operation_failed(operation: String, reason: String):
	operation_failed.emit(operation, reason)

func _on_board_unit_moved(from_zone: String, from_pos: Variant, to_zone: String, to_pos: Variant, unit_data: Dictionary):
	unit_moved.emit(from_zone, from_pos, to_zone, to_pos, unit_data)

func _on_board_unit_sold(zone: String, pos: Variant, gold_refund: int):
	unit_sold.emit(zone, pos, gold_refund)

# ===== 核心动作入口 =====

func buy_unit(shop_index: int, expected_unit_key: String = "") -> Dictionary:
	action_dispatched.emit("buy_unit", {"shop_index": shop_index, "expected_unit_key": expected_unit_key})
	if BoardController:
		return BoardController.buy_unit(shop_index, expected_unit_key)
	return {"success": false, "error_message": "BoardController not found"}

func refresh_shop() -> Dictionary:
	action_dispatched.emit("refresh_shop", {})
	if BoardController:
		return BoardController.refresh_shop()
	return {"success": false, "error_message": "BoardController not found"}

func try_move_unit(from_zone: String, from_pos: Variant, to_zone: String, to_pos: Variant) -> Dictionary:
	action_dispatched.emit("try_move_unit", {
		"from_zone": from_zone,
		"from_pos": from_pos,
		"to_zone": to_zone,
		"to_pos": to_pos
	})
	if BoardController:
		return BoardController.try_move_unit(from_zone, from_pos, to_zone, to_pos)
	return {"success": false, "error_message": "BoardController not found"}

func sell_unit(zone: String, pos: Variant) -> Dictionary:
	action_dispatched.emit("sell_unit", {"zone": zone, "pos": pos})
	if BoardController:
		return BoardController.sell_unit(zone, pos)
	return {"success": false, "error_message": "BoardController not found"}

func start_wave() -> Dictionary:
	action_dispatched.emit("start_wave", {})
	if BoardController:
		return BoardController.start_wave()
	return {"success": false, "error_message": "BoardController not found"}

func retry_wave() -> void:
	action_dispatched.emit("retry_wave", {})
	if BoardController:
		BoardController.retry_wave()

func get_unlocked_tiles() -> Array:
	if BoardController:
		return BoardController.get_unlocked_tiles()
	return []
