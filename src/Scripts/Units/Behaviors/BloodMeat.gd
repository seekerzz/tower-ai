extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# BloodMeat - 血食
# Wolf faction support unit
# ATK aura to adjacent Wolves, enhances devour mechanics
# Active skill: self-sacrifice heals core and buffs all Wolves

var adjacent_wolf_buff: float = 0.10
var devour_atk_bonus: float = 0.20
var devour_hp_bonus: float = 0.20
var sacrifice_heal_percent: float = 0.05
var sacrifice_buff_percent: float = 0.25
var sacrifice_duration: float = 5.0

# Lv3 blood stacks
var blood_stacks: int = 0
var max_blood_stacks: int = 5
var stack_bonus_per_devour: float = 0.02

# Track buffed units for cleanup
var buffed_units: Array = []

func on_setup():
	# Set level-based stats
	match unit.level:
		1:
			adjacent_wolf_buff = 0.10
			devour_atk_bonus = 0.20
			devour_hp_bonus = 0.20
			sacrifice_heal_percent = 0.05
			sacrifice_buff_percent = 0.25
			sacrifice_duration = 5.0
		2:
			adjacent_wolf_buff = 0.15
			devour_atk_bonus = 0.30
			devour_hp_bonus = 0.30
			sacrifice_heal_percent = 0.08
			sacrifice_buff_percent = 0.30
			sacrifice_duration = 6.0
		3:
			adjacent_wolf_buff = 0.20
			devour_atk_bonus = 0.40
			devour_hp_bonus = 0.40
			sacrifice_heal_percent = 0.10
			sacrifice_buff_percent = 0.40
			sacrifice_duration = 8.0

	# Connect to devour signal for Lv3
	if unit.level >= 3:
		if GameManager.has_signal("unit_devoured"):
			if GameManager.unit_devoured.is_connected(_on_unit_devoured):
				GameManager.unit_devoured.disconnect(_on_unit_devoured)
			GameManager.unit_devoured.connect(_on_unit_devoured)

	# Connect to wave started to reset stacks
	if GameManager.wave_started.is_connected(_on_wave_started):
		GameManager.wave_started.disconnect(_on_wave_started)
	GameManager.wave_started.connect(_on_wave_started)

func broadcast_buffs():
	# Apply ATK buff to adjacent Wolf units
	_apply_wolf_aura()

func _apply_wolf_aura():
	if !is_instance_valid(unit):
		return

	var neighbors = unit._get_neighbor_units()
	var total_buff = adjacent_wolf_buff

	# Lv3: Add stack bonus
	if unit.level >= 3:
		total_buff += blood_stacks * stack_bonus_per_devour

	# Clear previous buffs
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit) and buffed_unit != unit:
			buffed_unit.damage /= (1.0 + adjacent_wolf_buff)
	buffed_units.clear()

	for neighbor in neighbors:
		if neighbor != unit and is_instance_valid(neighbor):
			# Check if neighbor is a Wolf faction unit
			var faction = neighbor.unit_data.get("faction", "") if neighbor.get("unit_data") else ""
			if faction == "wolf_totem" or neighbor.unit_data.get("type_key", "").find("wolf") != -1:
				# Apply damage buff directly
				neighbor.damage *= (1.0 + total_buff)
				buffed_units.append(neighbor)
				neighbor.spawn_buff_effect("🥩")

func on_skill_activated():
	# Self-sacrifice: heal core and buff all Wolf units
	_perform_sacrifice()

func _perform_sacrifice():
	# Heal core
	var heal_amount = GameManager.max_core_health * sacrifice_heal_percent
	GameManager.heal_core(heal_amount)

	# Visual feedback for core heal
	GameManager.spawn_floating_text(unit.global_position, "Core +%d%%" % int(sacrifice_heal_percent * 100), Color.GREEN)

	# Buff all Wolf units
	var all_units = unit.get_tree().get_nodes_in_group("units")
	var buffed_count = 0

	for u in all_units:
		if is_instance_valid(u) and u != unit:
			var faction = u.unit_data.get("faction", "") if u.get("unit_data") else ""
			if faction == "wolf_totem" or u.unit_data.get("type_key", "").find("wolf") != -1:
				# Apply temporary ATK buff
				if u.has_method("add_temporary_buff"):
					u.add_temporary_buff("damage", sacrifice_buff_percent, sacrifice_duration)
				u.spawn_buff_effect("🐺")
				buffed_count += 1

	# Visual feedback
	GameManager.spawn_floating_text(unit.global_position, "SACRIFICE! (%d)" % buffed_count, Color.RED)
	unit.spawn_buff_effect("💀")

	# Remove self after a short delay
	await unit.get_tree().create_timer(0.3).timeout
	if is_instance_valid(unit):
		# Notify GridManager to remove this unit from the grid
		var grid_manager = unit.get_tree().root.get_node_or_null("Main/GridManager")
		if grid_manager and grid_manager.has_method("remove_unit_from_grid"):
			grid_manager.remove_unit_from_grid(unit)
		else:
			unit.queue_free()

func _on_unit_devoured(devouring_unit: Node2D, devoured_unit: Node2D):
	# Lv3: Gain a stack when any Wolf unit devours something
	if unit.level >= 3 and blood_stacks < max_blood_stacks:
		# Check if devouring unit is Wolf faction
		var faction = devouring_unit.unit_data.get("faction", "") if devouring_unit.get("unit_data") else ""
		if faction == "wolf_totem" or devouring_unit.unit_data.get("type_key", "").find("wolf") != -1:
			blood_stacks += 1
			GameManager.spawn_floating_text(unit.global_position, "Blood Stack: %d" % blood_stacks, Color.DARK_RED)
			unit.spawn_buff_effect("🩸")

func _on_wave_started():
	# Reset blood stacks at wave start
	blood_stacks = 0

func on_cleanup():
	# Remove buffs from buffed units
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit) and buffed_unit != unit:
			buffed_unit.damage /= (1.0 + adjacent_wolf_buff)
	buffed_units.clear()

	if GameManager.wave_started.is_connected(_on_wave_started):
		GameManager.wave_started.disconnect(_on_wave_started)
	if unit.level >= 3 and GameManager.has_signal("unit_devoured"):
		if GameManager.unit_devoured.is_connected(_on_unit_devoured):
			GameManager.unit_devoured.disconnect(_on_unit_devoured)
