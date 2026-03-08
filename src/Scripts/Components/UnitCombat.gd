extends RefCounted

signal attack_performed(target)
signal skill_activated(cost)
signal on_no_mana()

var stats: Dictionary = {
	"damage": 0.0,
	"range_val": 0.0,
	"atk_speed": 1.0,
	"attack_cost_mana": 0.0,
	"skill_mana_cost": 30.0,
	"skill_cd": 10.0,
	"attack_interval_modifier": 1.0, # GameManger stat modifier passed in
	"cooldown_modifier": 1.0, # GameManger stat modifier passed in
	"skill_cost_reduction": 0.0 # GameManager stat modifier passed in
}

var cooldown: float = 0.0
var skill_cooldown: float = 0.0
var is_no_mana: bool = false

func _init(initial_stats: Dictionary = {}):
	if not initial_stats.is_empty():
		stats.merge(initial_stats, true)

func update_stats(new_stats: Dictionary):
	stats.merge(new_stats, true)

func find_nearest_enemy(pos: Vector2, range_val: float, enemies: Array):
	var nearest = null
	var min_dist = range_val

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist = pos.distance_to(enemy.global_position)
		if dist <= min_dist:
			min_dist = dist
			nearest = enemy

	return nearest

func process_tick(delta: float):
	if skill_cooldown > 0:
		skill_cooldown -= delta

func process_combat(delta: float, current_pos: Vector2, available_enemies: Array, current_mana: float) -> Dictionary:
	var result = {"action": "none"}

	if cooldown > 0:
		cooldown -= delta
		return result

	var mana_cost = stats.get("attack_cost_mana", 0.0)
	if mana_cost > 0:
		if current_mana < mana_cost:
			is_no_mana = true
			return result
		else:
			is_no_mana = false

	var target = find_nearest_enemy(current_pos, stats.get("range_val", 0.0), available_enemies)

	if not target:
		return result

	# Emits signal and returns target information. It assumes the caller will actually
	# perform the consumption of mana and attack visually.
	# We set cooldown immediately assuming the attack will happen.
	cooldown = stats.get("atk_speed", 1.0) * stats.get("attack_interval_modifier", 1.0)

	attack_performed.emit(target)
	result["action"] = "attack"
	result["target"] = target

	return result

func execute_skill(current_mana: float) -> bool:
	if skill_cooldown > 0:
		return false

	var final_cost = stats.get("skill_mana_cost", 30.0)
	var cost_reduction = stats.get("skill_cost_reduction", 0.0)

	if cost_reduction > 0:
		final_cost *= (1.0 - cost_reduction)

	if current_mana >= final_cost:
		is_no_mana = false
		skill_cooldown = stats.get("skill_cd", 10.0) * stats.get("cooldown_modifier", 1.0)
		skill_activated.emit(final_cost)
		return true
	else:
		is_no_mana = true
		on_no_mana.emit()
		return false

func start_skill_cooldown(base_duration: float, fast_cooldown_cheat: bool = false):
	if fast_cooldown_cheat and base_duration > 1.0:
		skill_cooldown = 1.0
	else:
		skill_cooldown = base_duration * stats.get("cooldown_modifier", 1.0)
