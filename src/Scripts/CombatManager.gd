extends Node

const PROJECTILE_SCENE = preload("res://src/Scenes/Game/Projectile.tscn")
const LIGHTNING_SCENE = preload("res://src/Scenes/Game/LightningArc.tscn")
const SLASH_EFFECT_SCRIPT = preload("res://src/Scripts/Effects/SlashEffect.gd")

func _ready():
	GameManager.combat_manager = self

func find_nearest_enemy(pos: Vector2, range_val: float):
	var nearest = null
	var min_dist = range_val

	for enemy in get_tree().get_nodes_in_group("enemies"):
		# 检查敌人是否有效且已完成初始化
		if not is_instance_valid(enemy) or not enemy.is_node_ready():
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy

	return nearest

func get_enemies_in_range(pos: Vector2, range_val: float) -> Array:
	var found = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		# 检查敌人是否有效且已完成初始化
		if is_instance_valid(enemy) and enemy.is_node_ready():
			if pos.distance_to(enemy.global_position) <= range_val:
				found.append(enemy)
	return found

func perform_lightning_attack(source_unit, start_pos, target, chain_left, hit_list = null):
	if hit_list == null: hit_list = []
	if !is_instance_valid(target): return

	# Apply damage
	var dmg = source_unit.calculate_damage_against(target)
	target.take_damage(dmg, source_unit, "lightning")
	hit_list.append(target)

	# Visual
	var arc = LIGHTNING_SCENE.instantiate()
	add_child(arc)
	arc.setup(start_pos, target.global_position)

	# 记录闪电链攻击日志（仅在第一次攻击时记录）
	if AILogger and hit_list.size() == 1:
		var source_name = source_unit.type_key if "type_key" in source_unit else "单位"
		AILogger.totem_triggered("闪电链", source_name, "伤害%.0f，剩余跳跃%d次" % [dmg, chain_left])

	# Chain
	if chain_left > 0:
		var next_target = find_nearest_enemy_excluding(target.global_position, 300.0, hit_list)
		if next_target:
			var next_start_pos = target.global_position
			await get_tree().create_timer(0.15).timeout
			if is_instance_valid(source_unit):
				perform_lightning_attack(source_unit, next_start_pos, next_target, chain_left - 1, hit_list)

func find_nearest_enemy_excluding(pos: Vector2, range_val: float, exclude_list: Array):
	var nearest = null
	var min_dist = range_val

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in exclude_list: continue

		var dist = pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy

	return nearest

func spawn_projectile(source_unit, pos, target, extra_stats = {}):
	return _spawn_single_projectile(source_unit, pos, target, extra_stats)

func _spawn_single_projectile(source_unit, pos, target, extra_stats):
	# Safe Data Access
	var data_source = {}
	if "unit_data" in source_unit:
		data_source = source_unit.unit_data
	elif "enemy_data" in source_unit:
		data_source = source_unit.enemy_data

	# FIX: Shotgun logic - force straight flight by removing target
	if data_source.get("proj") == "ink" or extra_stats.has("angle"):
		target = null

	var proj = PROJECTILE_SCENE.instantiate()

	# Crit Calculation
	var crit_rate = source_unit.get("crit_rate") if source_unit.get("crit_rate") else 0.0
	var is_critical = randf() < crit_rate

	if source_unit.get("guaranteed_crit_stacks") and source_unit.guaranteed_crit_stacks > 0:
		is_critical = true
		source_unit.guaranteed_crit_stacks -= 1

	# Damage Calculation
	var base_dmg = 0.0
	if extra_stats.has("damage"):
		base_dmg = extra_stats.damage
	elif extra_stats.has("mimic_damage"):
		base_dmg = extra_stats.mimic_damage
	else:
		if source_unit.has_method("calculate_damage_against"):
			base_dmg = source_unit.calculate_damage_against(target) if target else source_unit.damage
		else:
			base_dmg = source_unit.get("damage", 10.0)

	var final_damage = base_dmg
	var crit_dmg = source_unit.get("crit_dmg") if source_unit.get("crit_dmg") else 1.5
	if is_critical:
		final_damage *= crit_dmg

	# Gather stats from unit data + active buffs
	var stats = {
		"pierce": data_source.get("pierce", 0),
		"bounce": data_source.get("bounce", 0),
		"split": data_source.get("split", 0),
		"chain": data_source.get("chain", 0),
		"damageType": data_source.get("damageType", "physical"),
		"is_critical": is_critical
	}

	# Merge buffs from Unit.gd (if present)
	var effects = {}
	if "active_buffs" in source_unit:
		for buff in source_unit.active_buffs:
			if buff == "bounce": stats["bounce"] += 1
			if buff == "split": stats["split"] += 1
			if buff == "fire": effects["burn"] = 3.0
			if buff == "poison": effects["poison"] = 5.0

	# Check native unit traits/attributes if they have intrinsic effects (Optional, based on task)
	# But Task says "fire" buff or attribute.
	if data_source.get("buffProvider") == "fire": # Although Torch doesn't shoot usually
		effects["burn"] = 3.0
	if data_source.get("buffProvider") == "poison":
		effects["poison"] = 5.0

	# New Traits Logic
	var unit_trait = data_source.get("trait")
	if unit_trait == "poison_touch":
		effects["poison"] = 5.0 # Accumulates
	elif unit_trait == "slow":
		effects["slow"] = 2.0 # Duration
	elif unit_trait == "freeze":
		effects["freeze"] = 2.0 # Duration

	stats["effects"] = effects

	# Merge extra stats
	stats.merge(extra_stats, true)
	stats.source = source_unit

	# Determine Projectile Type
	var proj_type = data_source.get("proj", "melee")
	if extra_stats.has("proj_override"):
		proj_type = extra_stats.proj_override
	elif extra_stats.has("type"): # Allow simple type override
		proj_type = extra_stats.type

	var proj_speed = stats.get("speed", data_source.get("projectile_speed", 400.0))
	proj.setup(pos, target, final_damage, proj_speed, proj_type, stats)
	add_child(proj)

	# --- Parrot Logic: Feed Neighbors ---
	# Only feed if this is NOT a mimicked shot (prevent loops)
	if !extra_stats.has("mimic_damage") and source_unit.has_method("_get_neighbor_units"):
		# Debounce: Only record one bullet per frame/action for multi-shot units
		var current_time = Time.get_ticks_msec()
		var last_shot = source_unit.get_meta("last_shot_time_parrot", 0)

		# If enough time passed (e.g. 50ms), treat as new shot.
		# If called instantly in loop (multi-shot), skip subsequent calls.
		if (current_time - last_shot) > 50:
			source_unit.set_meta("last_shot_time_parrot", current_time)

			var neighbors = source_unit._get_neighbor_units()
			if neighbors.size() > 0:
				# Create snapshot
				var snapshot = {
					"damage": final_damage,
					"type": proj_type,
					"speed": proj_speed,
					"pierce": stats.pierce,
					"bounce": stats.bounce,
					"split": stats.split,
					"chain": stats.chain,
					"damageType": stats.damageType,
					"effects": effects.duplicate()
				}

				for neighbor in neighbors:
					if neighbor.type_key == "parrot":
						neighbor.capture_bullet(snapshot)

	return proj

func check_kill_bonuses(killer_unit, victim = null):
	if killer_unit and "active_buffs" in killer_unit:
		if "wealth" in killer_unit.active_buffs:
			GameManager.add_gold(1)
			GameManager.spawn_floating_text(killer_unit.global_position, "+1 Gold", Color.YELLOW)

	# 安全类型检查：避免 Node 类为 null 时崩溃
	if killer_unit and Node != null and killer_unit is Node and "behavior" in killer_unit and killer_unit.behavior and killer_unit.behavior.has_method("on_kill"):
		killer_unit.behavior.on_kill(victim)


func deal_global_damage(damage: float, type: String):
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[CombatManager] Global Damage: ", damage, " Enemies found: ", enemies.size())
	for enemy in enemies:
		# 检查敌人是否有效且已完成初始化（避免攻击半成品敌人导致崩溃）
		if is_instance_valid(enemy) and enemy.is_node_ready():
			# Pass GameManager as source since it's a core effect
			enemy.take_damage(damage, GameManager, type)
