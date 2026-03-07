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

# Blood stacks system - available at all levels
var blood_stacks: int = 0
var max_blood_stacks: int = 10  # Changed from 5 to 10 to match design doc
var stack_bonus_per_devour: float = 0.02  # +2% per stack as per design doc

# Track buffed units for cleanup
var buffed_units: Array = []

func on_setup():
	# Log initialization - 确保日志能被测试脚本检测到
	if AILogger:
		var lvl = unit.level if unit and unit.get("level") else 1
		AILogger.event("[BLOOD_MEAT] 血食单位初始化 | 等级: %d | 最大血魂层数: %d" % [lvl, max_blood_stacks])
		print("[BLOOD_MEAT DEBUG] 日志已记录")

	# Set level-based stats - safely get level
	var current_level = 1
	if unit and unit.get("level"):
		current_level = unit.level
	match current_level:
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

	# 血魂层数初始化为0（调试代码已移除）
	blood_stacks = 0

	# Connect to devour signal for blood stack mechanic (available at all levels)
	if GameManager.has_signal("unit_devoured"):
		if GameManager.unit_devoured.is_connected(_on_unit_devoured):
			GameManager.unit_devoured.disconnect(_on_unit_devoured)
		GameManager.unit_devoured.connect(_on_unit_devoured)

	# Connect to wave started to reset stacks
	# 连接到 WaveSystemManager 的 wave_started 信号
	if GameManager.wave_system_manager:
		if GameManager.wave_system_manager.wave_started.is_connected(_on_wave_started):
			GameManager.wave_system_manager.wave_started.disconnect(_on_wave_started)
		GameManager.wave_system_manager.wave_started.connect(_on_wave_started)

func broadcast_buffs():
	# Apply ATK buff to adjacent Wolf units
	_apply_wolf_aura()

func _apply_wolf_aura():
	if !is_instance_valid(unit):
		return

	var neighbors = unit._get_neighbor_units()
	var total_buff = adjacent_wolf_buff

	# Add blood stack bonus (available at all levels)
	total_buff += blood_stacks * stack_bonus_per_devour

	# 正确清除所有旧buff（包括基础加成和血魂层数加成）
	# 首先需要记录原始基础伤害值或使用正确的计算方式
	# 这里重新设计buff清除机制，确保每次计算都是基于原始伤害值
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit) and buffed_unit != unit:
			# 为了正确计算，我们需要追踪原始伤害值
			# 如果单位没有原始伤害记录，我们需要先保存
			if not buffed_unit.has_meta("original_damage"):
				buffed_unit.set_meta("original_damage", buffed_unit.get_node("Stats").damage)
			else:
				# 恢复到原始伤害值
				buffed_unit.get_node("Stats").damage = buffed_unit.get_meta("original_damage")
	buffed_units.clear()

	for neighbor in neighbors:
		if neighbor != unit and is_instance_valid(neighbor):
			# Check if neighbor is a Wolf faction unit
			var faction = neighbor.unit_data.get("faction", "") if neighbor.get("unit_data") else ""
			if faction == "wolf_totem" or neighbor.unit_data.get("type_key", "").find("wolf") != -1:
				# 保存原始伤害值（如果尚未保存）
				if not neighbor.has_meta("original_damage"):
					neighbor.set_meta("original_damage", neighbor.get_node("Stats").damage)
				# 计算新的伤害值
				neighbor.get_node("Stats").damage = neighbor.get_meta("original_damage") * (1.0 + total_buff)
				buffed_units.append(neighbor)
				neighbor.spawn_buff_effect("🥩")

	# 记录[BLOOD_AURA]血食光环效果日志 - 使用测试脚本可检测的格式
	if AILogger and buffed_units.size() > 0:
		var stack_bonus = blood_stacks * stack_bonus_per_devour * 100
		AILogger.event("[BLOOD_AURA] 血食光环生效 | 基础加成: %.0f%% | 血魂层数: %d | 层数加成: +%.0f%% | 总加成: %.0f%% | 影响单位: %d" % [adjacent_wolf_buff * 100, blood_stacks, stack_bonus, total_buff * 100, buffed_units.size()])
		if AIManager:
			AIManager.broadcast_text("[BLOOD_AURA] 血食光环 | 层数%d | 总加成%.0f%% | 影响%d单位" % [blood_stacks, total_buff * 100, buffed_units.size()])

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

	# Log sacrifice skill
	if AILogger:
		# 记录[BLOOD_SACRIFICE]血祭技能日志 - 使用测试脚本可检测的格式
		AILogger.event("[BLOOD_SACRIFICE] 血食触发血祭技能 | 治疗核心: %.0f%% | 狼族buff: +%.0f%%攻击持续%.0f秒 | 影响单位: %d" % [sacrifice_heal_percent * 100, sacrifice_buff_percent * 100, sacrifice_duration, buffed_count])
		# 同时保留[BLOOD_MEAT]格式日志用于兼容性
		AILogger.event("[BLOOD_MEAT] 血食触发血祭 | 治疗核心: %.0f%% | 狼族buff: +%.0f%%攻击持续%.0f秒 | 影响单位: %d" % [sacrifice_heal_percent * 100, sacrifice_buff_percent * 100, sacrifice_duration, buffed_count])
		if AIManager:
			AIManager.broadcast_text("[BLOOD_SACRIFICE] 血食触发血祭技能 | 治疗核心: %.0f%% | 影响单位: %d" % [sacrifice_heal_percent * 100, buffed_count])
	if AIManager:
		AIManager.broadcast_text("【血食-血祭】自杀治疗核心%.0f%%，%d个狼族单位+%.0f%%攻击%.0f秒" % [sacrifice_heal_percent * 100, buffed_count, sacrifice_buff_percent * 100, sacrifice_duration])

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
	# Gain a stack when any Wolf unit devours something (available at all levels)
	if blood_stacks < max_blood_stacks:
		# Check if devouring unit is Wolf faction
		var faction = devouring_unit.unit_data.get("faction", "") if devouring_unit.get("unit_data") else ""
		if faction == "wolf_totem" or devouring_unit.unit_data.get("type_key", "").find("wolf") != -1:
			blood_stacks += 1
			GameManager.spawn_floating_text(unit.global_position, "Blood Stack: %d" % blood_stacks, Color.DARK_RED)
			unit.spawn_buff_effect("🩸")

			# Log blood stack gain
			if AILogger:
				var devourer_name = devouring_unit.unit_data.get("type_key", "unknown") if devouring_unit.get("unit_data") else "unknown"
				var current_bonus = blood_stacks * stack_bonus_per_devour * 100
				# 记录[BLOOD_SOUL]血魂层数日志 - 使用测试脚本可检测的格式
				AILogger.event("[BLOOD_SOUL] 血食获得血魂层数 | 吞噬者: %s | 当前层数: %d/%d | 每层+2%%光环 | 总加成: +%.0f%%" % [devourer_name, blood_stacks, max_blood_stacks, current_bonus])
				# 同时保留[BLOOD_MEAT]格式日志用于兼容性
				AILogger.event("[BLOOD_MEAT] 血食获得血魂层数 | 吞噬者: %s | 当前层数: %d/%d | 光环加成: +%.0f%%" % [devourer_name, blood_stacks, max_blood_stacks, current_bonus])
				if AIManager:
					AIManager.broadcast_text("[BLOOD_SOUL] 血食血魂层数 %d/%d | 光环+%.0f%%" % [blood_stacks, max_blood_stacks, current_bonus])
			if AIManager:
				AIManager.broadcast_text("【血食】血魂层数+%d，当前%d层，光环+%.0f%%" % [blood_stacks, blood_stacks, blood_stacks * stack_bonus_per_devour * 100])

func _on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	# Reset blood stacks at wave start
	blood_stacks = 0

func on_cleanup():
	# Remove buffs from buffed units
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit) and buffed_unit != unit:
			buffed_unit.get_node("Stats").damage /= (1.0 + adjacent_wolf_buff)
	buffed_units.clear()

	if GameManager.wave_system_manager and GameManager.wave_system_manager.wave_started.is_connected(_on_wave_started):
		GameManager.wave_system_manager.wave_started.disconnect(_on_wave_started)
	if GameManager.has_signal("unit_devoured"):
		if GameManager.unit_devoured.is_connected(_on_unit_devoured):
			GameManager.unit_devoured.disconnect(_on_unit_devoured)
