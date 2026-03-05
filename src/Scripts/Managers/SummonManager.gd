class_name SummonManager
extends Node

var active_summons: Array = []
var max_summons_per_source: int = 8

signal summon_created(summon, source)
signal summon_destroyed(summon)

func create_summon(data: Dictionary):
	# Check limit per source
	var source = data.get("source")
	if source:
		var summons_of_source = []
		for s in active_summons:
			if is_instance_valid(s) and s.summon_source == source:
				summons_of_source.append(s)

		if summons_of_source.size() >= max_summons_per_source:
			# Remove oldest
			var oldest = summons_of_source[0]
			if is_instance_valid(oldest):
				oldest._on_lifetime_expired()

	var summon_scene = load("res://src/Scenes/Units/SummonedUnit.tscn")
	if not summon_scene:
		push_error("SummonedUnit scene not found!")
		return null

	var summon = summon_scene.instantiate()

	var unit_id = data.get("unit_id", "spiderling")
	summon.setup(unit_id)

	if data.has("level"):
		summon.level = data.get("level")
		summon.reset_stats()

	if data.has("lifetime"):
		summon.lifetime = data.get("lifetime")

	summon.is_clone = data.get("is_clone", false)
	summon.summon_source = data.get("source")
	summon.global_position = data.get("position", Vector2.ZERO)

	# Handle Grid Position if needed (snap to grid or just visual)
	# Assuming summons are free-moving or placed at specific points
	# If they need to be on grid, we might need to set grid_pos

	# 如果是克隆体，继承属性
	if summon.is_clone and summon.summon_source:
		_inherit_stats(summon, summon.summon_source, data.get("inherit_ratio", 0.4))

	# Initialize current_hp
	summon.current_hp = summon.max_hp

	get_tree().current_scene.add_child(summon)
	active_summons.append(summon)

	summon.summon_expired.connect(_on_summon_removed)
	summon.summon_killed.connect(_on_summon_removed)

	summon_created.emit(summon, summon.summon_source)
	return summon

func _inherit_stats(summon, source, ratio: float):
	if "damage" in source:
		summon.damage = source.damage * ratio
	if "max_hp" in source:
		summon.max_hp = source.max_hp * ratio
		summon.current_hp = summon.max_hp
	if "atk_speed" in source:
		summon.atk_speed = source.atk_speed
	if "range_val" in source:
		summon.range_val = source.range_val # Also inherit range often useful for clones

func _on_summon_removed(summon):
	if summon in active_summons:
		active_summons.erase(summon)
	summon_destroyed.emit(summon)
