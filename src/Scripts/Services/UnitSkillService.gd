extends RefCounted
class_name UnitSkillService

var unit: Node2D

func _init(target_unit: Node2D):
	unit = target_unit

func activate_skill():
	if !unit.unit_data.has("skill"):
		return
	if unit.skill_cooldown > 0:
		return

	unit.behavior.on_skill_activated()

	if unit.unit_data.get("skillType") == "point":
		# Behavior handles targeting initiation
		return

	var skill_result = _consume_skill_mana_and_start_cooldown()
	if !skill_result.success:
		return

	_emit_skill_activated_feedback(skill_result.cost)
	if unit.visual_component and unit.visual_component.has_method("play_skill_cast_anim"):
		unit.visual_component.play_skill_cast_anim()

func execute_skill_at(target_grid_pos: Vector2i):
	if unit.skill_cooldown > 0:
		return
	if not unit.unit_data.has("skill"):
		return

	var skill_result = _consume_skill_mana_and_start_cooldown()
	if !skill_result.success:
		return

	_emit_skill_activated_feedback(skill_result.cost)
	unit.behavior.on_skill_executed_at(target_grid_pos)

func _consume_skill_mana_and_start_cooldown() -> Dictionary:
	var final_cost = unit.skill_mana_cost * (1.0 - _get_skill_cost_reduction())

	if GameManager.consume_resource("mana", final_cost):
		unit.is_no_mana = false
		unit._start_skill_cooldown(unit.unit_data.get("skillCd", 10.0))
		return {"success": true, "cost": final_cost}

	unit.is_no_mana = true
	GameManager.spawn_floating_text(unit.global_position, "No Mana!", Color.BLUE)
	return {"success": false, "cost": final_cost}

func _get_skill_cost_reduction() -> float:
	var reduction = 0.0
	if GameManager.has_method("get_global_buff"):
		reduction = max(reduction, GameManager.get_global_buff("skill_mana_cost_reduction", 0.0))
	if "skill_cost_reduction" in GameManager:
		reduction = max(reduction, GameManager.skill_cost_reduction)
	return clampf(reduction, 0.0, 0.95)

func _emit_skill_activated_feedback(final_cost: float):
	var skill_name = unit.unit_data.skill
	GameManager.spawn_floating_text(unit.global_position, skill_name.capitalize() + "!", Color.CYAN)
	GameManager.skill_activated.emit(unit)

	if AILogger:
		AILogger.action("[技能] %s(Lv%d) 使用了技能: %s (消耗%.0f法力)" % [unit.type_key, unit.level, skill_name, final_cost])
