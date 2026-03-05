extends RefCounted
class_name CombatController

var unit: Node2D

func _init():
	pass

func activate_skill():
	var GameManager = unit.get_node_or_null("/root/GameManager")
	var AILogger = unit.get_node_or_null("/root/AILogger")

	if !unit.unit_data.has("skill"): return
	if unit.skill_cooldown > 0: return

	if unit.behavior:
		unit.behavior.on_skill_activated()

	if unit.unit_data.get("skillType") == "point":
		# Behavior handles targeting initiation
		return

	var final_cost = unit.stats.skill_mana_cost
	if GameManager and GameManager.skill_cost_reduction > 0:
		final_cost *= (1.0 - GameManager.skill_cost_reduction)

	if GameManager and GameManager.consume_resource("mana", final_cost):
		unit.is_no_mana = false

		# Replace unit._start_skill_cooldown
		var base_duration = unit.unit_data.get("skillCd", 10.0)
		if GameManager.cheat_fast_cooldown and base_duration > 1.0:
			unit.skill_cooldown = 1.0
		else:
			unit.skill_cooldown = base_duration * GameManager.get_stat_modifier("cooldown")

		var skill_name = unit.unit_data.skill
		GameManager.spawn_floating_text(unit.global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(unit)
		# 中文技能日志
		if AILogger:
			AILogger.action("[技能] %s(Lv%d) 使用了技能: %s (消耗%.0f法力)" % [unit.type_key, unit.level, skill_name, final_cost])

		if unit.visual_holder and unit.is_inside_tree():
			var tween = unit.create_tween()
			tween.tween_property(unit.visual_holder, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.1)

	else:
		unit.is_no_mana = true
		if GameManager:
			GameManager.spawn_floating_text(unit.global_position, "No Mana!", Color.BLUE)

func execute_skill_at(grid_pos: Vector2i):
	var GameManager = unit.get_node_or_null("/root/GameManager")

	if unit.skill_cooldown > 0: return
	if not unit.unit_data.has("skill"): return

	var final_cost = unit.stats.skill_mana_cost
	var cost_reduction = 0.0
	if GameManager:
		cost_reduction = GameManager.get_global_buff("skill_mana_cost_reduction", 0.0)
	if cost_reduction > 0:
		final_cost *= (1.0 - cost_reduction)

	if GameManager and GameManager.consume_resource("mana", final_cost):
		unit.is_no_mana = false
		var base_duration = unit.unit_data.get("skillCd", 10.0)
		if GameManager.cheat_fast_cooldown and base_duration > 1.0:
			unit.skill_cooldown = 1.0
		else:
			unit.skill_cooldown = base_duration * GameManager.get_stat_modifier("cooldown")

		var skill_name = unit.unit_data.skill
		GameManager.spawn_floating_text(unit.global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(unit)

		if unit.behavior:
			unit.behavior.on_skill_executed_at(grid_pos)

	else:
		unit.is_no_mana = true
		if GameManager:
			GameManager.spawn_floating_text(unit.global_position, "No Mana!", Color.BLUE)


func _do_melee_attack(target: Node2D):
	if unit.get("attack_cost_mana") != null and unit.attack_cost_mana > 0:
		if unit.get_tree().root.has_node("GameManager"):
			unit.get_node("/root/GameManager").consume_resource("mana", unit.attack_cost_mana)

	if unit.get("atk_speed") != null:
		var GameManager = unit.get_node_or_null("/root/GameManager")
		if GameManager:
			unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	if unit.has_method("play_attack_anim"):
		unit.play_attack_anim("melee", target.global_position)

	# Original logic has await, but RefCounted can't easily handle awaits tied to tree like Node does
	# In tests or for simple component we assume it returns
	pass

func _do_standard_ranged_attack(target: Node2D):
	if !unit.is_inside_tree(): return
	var GameManager = unit.get_node_or_null("/root/GameManager")
	var combat_manager = null
	if GameManager:
		combat_manager = GameManager.combat_manager
	if !combat_manager: return

	if unit.get("attack_cost_mana") != null and unit.attack_cost_mana > 0:
		GameManager.consume_resource("mana", unit.attack_cost_mana)

	if unit.get("atk_speed") != null:
		unit.cooldown = unit.atk_speed * GameManager.get_stat_modifier("attack_interval")

	if unit.get("unit_data") != null and typeof(unit.unit_data) == TYPE_DICTIONARY:
		if unit.unit_data.get("proj") == "lightning":
			if unit.has_method("play_attack_anim"):
				unit.play_attack_anim("lightning", target.global_position)
			combat_manager.perform_lightning_attack(unit, unit.global_position, target, unit.unit_data.get("chain", 0))
			return

	if unit.has_method("play_attack_anim"):
		unit.play_attack_anim("ranged", target.global_position)
