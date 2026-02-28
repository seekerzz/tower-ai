extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Shell - 贝壳
# Tracks hits taken, generates gold (Pearl) if under threshold at wave end
# Lv3: Provides 5% damage reduction aura to adjacent allies

var hit_count: int = 0
var hit_threshold: int = 5
var pearl_value: int = 50
var has_generated_pearl: bool = false

func on_setup():
	# Set level-based stats
	match unit.level:
		1:
			hit_threshold = 5
			pearl_value = 50
		2:
			hit_threshold = 8
			pearl_value = 75
		3:
			hit_threshold = 8
			pearl_value = 100

	# Connect to wave ended signal
	if GameManager.wave_ended.is_connected(_on_wave_ended):
		GameManager.wave_ended.disconnect(_on_wave_ended)
	GameManager.wave_ended.connect(_on_wave_ended)

func on_damage_taken(amount: float, source: Node2D) -> float:
	# Track hits taken (only count actual damage)
	if amount > 0:
		hit_count += 1
		unit.spawn_buff_effect("🐚")
	return amount

func _on_wave_ended():
	if has_generated_pearl:
		return

	# Check if hit count is under threshold
	if hit_count < hit_threshold:
		_generate_pearl()

func _generate_pearl():
	has_generated_pearl = true

	# Add gold
	GameManager.add_resource("gold", pearl_value)

	# Visual feedback
	GameManager.spawn_floating_text(unit.global_position, "+%d🪙 Pearl!" % pearl_value, Color.GOLD)
	unit.spawn_buff_effect("✨")

	# Remove unit after a short delay
	await unit.get_tree().create_timer(0.5).timeout
	if is_instance_valid(unit):
		# Notify GridManager to remove this unit from the grid
		var grid_manager = unit.get_tree().root.get_node_or_null("Main/GridManager")
		if grid_manager and grid_manager.has_method("remove_unit_from_grid"):
			grid_manager.remove_unit_from_grid(unit)
		else:
			unit.queue_free()

func broadcast_buffs():
	# Lv3: Damage reduction aura for adjacent allies
	if unit.level >= 3:
		_apply_damage_reduction_aura()

func _apply_damage_reduction_aura():
	if !is_instance_valid(unit):
		return

	var neighbors = unit._get_neighbor_units()
	for neighbor in neighbors:
		if neighbor != unit and is_instance_valid(neighbor):
			# Apply 5% damage reduction using temporary buff
			if neighbor.has_method("add_temporary_buff"):
				neighbor.add_temporary_buff("damage_reduction", 0.05, 999999.0)  # Long duration for persistent effect

func on_cleanup():
	if GameManager.wave_ended.is_connected(_on_wave_ended):
		GameManager.wave_ended.disconnect(_on_wave_ended)
