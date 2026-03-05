extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var ammo_queue: Array = []
var max_ammo: int = 5
var is_discharging: bool = false

func on_setup():
	# Initial Setup if needed
	pass

func on_stats_updated():
	update_range()
	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		var stats = unit.unit_data["levels"][str(unit.level)]
		if stats.has("mechanics") and stats["mechanics"].has("max_ammo"):
			max_ammo = stats["mechanics"]["max_ammo"]

func update_range():
	var neighbors = unit._get_neighbor_units()
	var min_range = 9999.0
	var has_ranged = false
	for u in neighbors:
		if u.unit_data.get("attackType") == "ranged":
			has_ranged = true
			if u.range_val < min_range: min_range = u.range_val

	if has_ranged: unit.range_val = min_range
	else: unit.range_val = 0.0

func capture_bullet(bullet_snapshot: Dictionary):
	if is_discharging: return
	if ammo_queue.size() >= max_ammo: return
	ammo_queue.append(bullet_snapshot.duplicate(true))

	if unit.visual_holder:
		var tween = unit.create_tween()
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(unit.visual_holder, "scale", Vector2(1.0, 1.0), 0.1)

func on_combat_tick(delta: float) -> bool:
	if !is_discharging:
		# Check Start Condition: Full Ammo AND Enemy in Range
		if ammo_queue.size() >= max_ammo:
			var target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
			if target:
				is_discharging = true

	if is_discharging:
		if unit.cooldown > 0:
			unit.cooldown -= delta
			return true

		if ammo_queue.size() > 0:
			var aim_target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
			if aim_target:
				if unit.attack_cost_mana > 0: GameManager.consume_resource("mana", unit.attack_cost_mana)
				unit.cooldown = unit.atk_speed

				var bullet_data = ammo_queue.pop_front()
				unit.play_attack_anim("ranged", aim_target.global_position)

				var extra = bullet_data.duplicate()
				extra["mimic_damage"] = bullet_data.get("damage", 10.0)
				extra["proj_override"] = bullet_data.get("type", "pinecone")

				GameManager.combat_manager.spawn_projectile(unit, unit.global_position, aim_target, extra)
				unit.attack_performed.emit(aim_target)
		else:
			is_discharging = false

	return true
