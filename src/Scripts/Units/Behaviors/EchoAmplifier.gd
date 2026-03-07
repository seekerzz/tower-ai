extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Echo Amplifier - 回响增幅者
# Eagle Totem faction support unit
# Lv.1: 被附身单位触发回响时，回响伤害+50%
# Lv.2: 回响伤害+50%→+80%，触发概率+10%
# Lv.3: 回响特效 (50% 概率附加减速/减防)，回响连锁 (25% 概率额外回响)

var echo_damage_bonus: float = 0.50  # +50% echo damage
var echo_trigger_chance_bonus: float = 0.0  # +0% trigger chance
var has_echo_effect: bool = false  # Lv.3: echo special effects
var has_echo_chain: bool = false  # Lv.3: echo chain reaction

var slow_duration: float = 2.0
var slow_factor: float = 0.5  # 50% slow
var defense_reduction: float = 0.15  # -15% defense
var effect_chance: float = 0.5  # 50% chance for special effect
var chain_chance: float = 0.25  # 25% chain echo chance

var buffed_units: Array = []

func on_setup():
	_load_mechanics()
	_apply_echo_buff()

func _load_mechanics():
	match unit.level:
		1:
			echo_damage_bonus = 0.50
			echo_trigger_chance_bonus = 0.0
			has_echo_effect = false
			has_echo_chain = false
		2:
			echo_damage_bonus = 0.80  # +80% echo damage
			echo_trigger_chance_bonus = 0.10  # +10% trigger chance
			has_echo_effect = false
			has_echo_chain = false
		3:
			echo_damage_bonus = 0.80
			echo_trigger_chance_bonus = 0.10
			has_echo_effect = true  # Echo special effects
			has_echo_chain = true  # Echo chain reaction

func _apply_echo_buff():
	# Apply echo damage buff to all Eagle Totem units
	var all_units = unit.get_tree().get_nodes_in_group("units")

	for u in all_units:
		if is_instance_valid(u) and u != unit:
			var faction = u.unit_data.get("faction", "") if u.get("unit_data") else ""
			if faction == "eagle_totem" or u.unit_data.get("type_key", "").find("eagle") != -1:
				# Store original damage if not already stored
				if not u.has_meta("original_damage"):
					u.set_meta("original_damage", u.damage)

				# Apply echo damage bonus (this is a multiplier to their echo effects)
				u.set_meta("echo_damage_bonus", echo_damage_bonus)
				u.set_meta("echo_trigger_chance_bonus", echo_trigger_chance_bonus)

				if u not in buffed_units:
					buffed_units.append(u)
					u.spawn_buff_effect("🦅✨")

	# Log buff application
	if AILogger and buffed_units.size() > 0:
		AILogger.event("[ECHO_AMPLIFIER] 回响增幅者光环生效 | 回响伤害加成：%.0f%% | 触发概率加成：%.0f%% | 影响单位：%d" % [
			echo_damage_bonus * 100, echo_trigger_chance_bonus * 100, buffed_units.size()
		])
		if AIManager:
			AIManager.broadcast_text("[ECHO_AMPLIFIER] 回响增幅者 | 回响伤害+%.0f%% | 影响%d单位" % [echo_damage_bonus * 100, buffed_units.size()])

func on_combat_tick(delta: float) -> bool:
	# Re-apply buff periodically to ensure it stays active
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	_apply_echo_buff()
	unit.cooldown = 1.0  # Re-apply every second

	return true

func on_cleanup():
	# Clean up meta data from buffed units
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit):
			buffed_unit.remove_meta("echo_damage_bonus")
			buffed_unit.remove_meta("echo_trigger_chance_bonus")
	buffed_units.clear()

func get_status() -> Dictionary:
	return {
		"echo_damage_bonus": echo_damage_bonus,
		"echo_trigger_chance_bonus": echo_trigger_chance_bonus,
		"has_echo_effect": has_echo_effect,
		"has_echo_chain": has_echo_chain,
		"buffed_units_count": buffed_units.size()
	}
