extends Node

# Distance Damage Debuff
# 效果: 每隔一段时间造成基于距离核心的伤害
# 机制: distance_to_core * 0.08
# params: { duration, tick_interval }

var duration: float = 2.5
var tick_interval: float = 0.5
var stacks: int = 1
var source_unit = null
var type_key = "distance_damage"

func setup(target: Node, source: Object, params: Dictionary):
	source_unit = source
	if params.has("duration"): duration = params.duration
	if params.has("tick_interval"): tick_interval = params.tick_interval

	var d_timer = Timer.new()
	d_timer.wait_time = duration
	d_timer.one_shot = true
	d_timer.timeout.connect(queue_free)
	add_child(d_timer)
	d_timer.start()

	var t_timer = Timer.new()
	t_timer.wait_time = tick_interval
	t_timer.timeout.connect(_apply_damage)
	add_child(t_timer)
	t_timer.start()

func stack(params: Dictionary):
	# Refresh duration
	if params.has("duration"):
		for c in get_children():
			if c is Timer and c.one_shot:
				c.start(params.duration)
				return

func _apply_damage():
	var enemy = get_parent()
	if not is_instance_valid(enemy):
		return

	# Calculate distance to core
	var core_pos = Vector2.ZERO
	if GameManager.grid_manager:
		core_pos = GameManager.grid_manager.global_position

	var dist = enemy.global_position.distance_to(core_pos)
	var damage = dist * 0.08

	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, source_unit, "magic")
