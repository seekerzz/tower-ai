extends RefCounted
class_name BuffManager

var unit: Node2D
var active_buffs: Array = []
var buff_sources: Dictionary = {}

func _init():
	pass

func add_buff(buff_type: String, source_unit: Node2D):
	var is_stackable = (buff_type in ["bounce", "split", "guaranteed_crit"])
	var has_buff = buff_type in active_buffs
	var is_new_buff = not has_buff

	if not is_stackable and has_buff:
		return

	if is_new_buff:
		active_buffs.append(buff_type)

	if source_unit:
		buff_sources[buff_type] = source_unit

	if buff_type == "bounce" and unit.get("bounce_count") != null:
		unit.bounce_count += 1
	elif buff_type == "split" and unit.get("split_count") != null:
		unit.split_count += 1
	elif buff_type == "guaranteed_crit" and unit.get("guaranteed_crit_stacks") != null:
		unit.guaranteed_crit_stacks += 1

	# 记录[BUFF]日志
	var source_name = source_unit.type_key if source_unit and "type_key" in source_unit else "未知"
	var target_name = unit.type_key if unit and "type_key" in unit else "单位"
	var effect_desc = ""
	match buff_type:
		"range": effect_desc = "射程+25%"
		"speed": effect_desc = "攻速+20%"
		"crit": effect_desc = "暴击率+25%"
		"bounce": effect_desc = "弹射+1"
		"split": effect_desc = "分裂+1"
		"forest_blessing": effect_desc = "森林祝福"
		"guardian_shield": effect_desc = "守护护盾"

	var in_tree = unit.is_inside_tree()

	if is_new_buff:
		var buff_msg = "[BUFF] %s 施加 %s Buff | 目标: %s | 效果: %s" % [source_name, buff_type, target_name, effect_desc]
		if in_tree:
			var ailogger = unit.get_node_or_null("/root/AILogger")
			if ailogger:
				ailogger.event(buff_msg)
			var aimanager = unit.get_node_or_null("/root/AIManager")
			if aimanager:
				aimanager.broadcast_text(buff_msg)

	elif is_stackable:
		# 记录[BUFF_STACK]日志
		var current_stacks = 1
		if "bounce_count" in unit and buff_type == "bounce":
			current_stacks = unit.bounce_count
		elif "split_count" in unit and buff_type == "split":
			current_stacks = unit.split_count
		elif "guaranteed_crit_stacks" in unit and buff_type == "guaranteed_crit":
			current_stacks = unit.guaranteed_crit_stacks

		var stack_msg = "[BUFF_STACK] %s %s Buff叠加 | 目标: %s | 当前层数: %d | 效果: %s" % [source_name, buff_type, target_name, current_stacks, effect_desc]
		if in_tree:
			var ailogger = unit.get_node_or_null("/root/AILogger")
			if ailogger:
				ailogger.event(stack_msg)
			var aimanager = unit.get_node_or_null("/root/AIManager")
			if aimanager:
				aimanager.broadcast_text(stack_msg)

	if unit.has_signal("buff_applied"):
		unit.emit_signal("buff_applied", buff_type)

func remove_buff(buff_type: String):
	if buff_type in active_buffs:
		active_buffs.erase(buff_type)
		buff_sources.erase(buff_type)

func has_buff(buff_type: String) -> bool:
	return buff_type in active_buffs

func modify_damage_taken(amount: float, source: Node2D) -> float:
	var final_amount = amount
	if "guardian_shield" in active_buffs:
		var buff_source = buff_sources.get("guardian_shield")
		if buff_source and is_instance_valid(buff_source) and buff_source.behavior:
			var reduction = buff_source.behavior.get_damage_reduction() if buff_source.behavior.has_method("get_damage_reduction") else 0.05
			final_amount *= (1.0 - reduction)
	return final_amount
