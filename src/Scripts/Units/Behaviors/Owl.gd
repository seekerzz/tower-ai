extends "res://src/Scripts/Units/Behaviors/BuffProviderBehavior.gd"

# Owl - 猫头鹰
# 辅助单位，增加周围友军暴击率
# Lv2增加范围和暴击加成
# Lv3在友方触发回响时增加攻速

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_setup():
	GameManager.totem_echo_triggered.connect(_on_totem_echo)

func on_cleanup():
	if GameManager.totem_echo_triggered.is_connected(_on_totem_echo):
		GameManager.totem_echo_triggered.disconnect(_on_totem_echo)

func broadcast_buffs():
	var range_val = 1
	if unit.level >= 2:
		range_val = 2

	var neighbors = _get_units_in_range(range_val)
	var bonus = 0.12
	if unit.level >= 2:
		bonus = 0.20

	for neighbor in neighbors:
		if neighbor == unit: continue
		neighbor.crit_rate += bonus
		# Add to active buffs for UI if not present
		if not ("crit_chance" in neighbor.active_buffs):
			neighbor.active_buffs.append("crit_chance")
			neighbor.buff_sources["crit_chance"] = unit

func _get_units_in_range(r: int) -> Array:
	if not GameManager.grid_manager: return []
	var list = []
	var cx = unit.grid_pos.x
	var cy = unit.grid_pos.y

	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx == 0 and dy == 0: continue
			var key = GameManager.grid_manager.get_tile_key(cx + dx, cy + dy)
			if GameManager.grid_manager.tiles.has(key):
				var tile = GameManager.grid_manager.tiles[key]
				if tile.unit and is_instance_valid(tile.unit) and not (tile.unit in list):
					list.append(tile.unit)
	return list

func _on_totem_echo(source_unit: Node2D, damage: float):
	if unit.level < 3: return

	var range_val = 2
	var neighbors = _get_units_in_range(range_val)
	if source_unit in neighbors:
		if source_unit.has_method("add_temporary_buff"):
			source_unit.add_temporary_buff("attack_speed", 0.15, 3.0)
			GameManager.spawn_floating_text(source_unit.global_position, "+SPEED", Color.CYAN)
