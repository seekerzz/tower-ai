extends Node

const ENEMY_SCENE = preload("res://src/Scenes/Game/Enemy.tscn")
const HEALER_SCRIPT = preload("res://src/Scripts/Enemies/HealerEnemy.gd")
const PROJECTILE_SCENE = preload("res://src/Scenes/Game/Projectile.tscn")
const LIGHTNING_SCENE = preload("res://src/Scenes/Game/LightningArc.tscn")
const SLASH_EFFECT_SCRIPT = preload("res://src/Scripts/Effects/SlashEffect.gd")

var enemies_to_spawn: int = 0
var total_enemies_for_wave: int = 0
# spawn_timer removed as we use coroutines now

var explosion_queue: Array = []
const MAX_EXPLOSIONS_PER_FRAME = 10

func _ready():
	GameManager.combat_manager = self
	GameManager.wave_started.connect(_on_wave_started)

func _process(delta):
	if explosion_queue.size() > 0:
		var process_count = min(explosion_queue.size(), MAX_EXPLOSIONS_PER_FRAME)
		for i in range(process_count):
			var expl = explosion_queue.pop_front()
			if expl.type == "poison":
				_process_poison_explosion_logic(expl.pos, expl.damage, expl.stacks, expl.source)
			else:
				_process_burn_explosion_logic(expl.pos, expl.damage, expl.source)

func _on_wave_started():
	start_wave_logic()

func get_wave_type(n: int) -> String:
	var types = ['slime', 'wolf', 'poison', 'treant', 'yeti', 'golem']
	if n % 10 == 0: return 'boss'
	if n == 3: return 'healer'
	if n % 3 == 0: return 'event'

	if n == 2: return 'mutant_slime'

	# Logic from ref.html: const idx = Math.min(types.length - 1, Math.floor((n-1)/2));
	var idx = min(types.size() - 1, floor((n - 1) / 2.0))
	return types[int(idx) % types.size()]

func start_wave_logic():
	var wave = GameManager.wave

	if wave == 5:
		spawn_boss_wave()
		return

	# Calculate total enemies (Increased difficulty logic from ref.html)
	# const baseCount = 20 + Math.floor(game.wave * 6);
	total_enemies_for_wave = 20 + floor(wave * 6)
	enemies_to_spawn = total_enemies_for_wave

	# Batch calculation
	# const batchCount = 3 + Math.floor(game.wave / 2);
	var batch_count = 3 + floor(wave / 2.0)
	var enemies_per_batch = ceil(float(total_enemies_for_wave) / batch_count)

	_run_batch_sequence(batch_count, int(enemies_per_batch))

func start_meteor_shower(center_pos: Vector2, damage: float):
	# Wave Loop: 5 Waves, 0.1s interval (using async/await)
	for w in range(5):
		# Spawn Loop: 8 projectiles per wave
		for i in range(8):
			# land_pos: Random point within 1.5 * TILE_SIZE (3x3 grid)
			var spread = 1.5 * Constants.TILE_SIZE
			var offset = Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			var land_pos = center_pos + offset

			# start_pos: land_pos + Vector2(-300, -800) (Angle from top-left)
			var start_pos = land_pos + Vector2(-300, -800)

			var stats = {
				"is_meteor": true,
				"ground_pos": land_pos,
				"pierce": 2,
				"bounce": 0
			}

			# Call spawn (passing null as source_unit for now, or we could pass a dummy if needed)
			# But _spawn_single_projectile expects a source_unit to get 'damage', 'crit_rate' etc.
			# Or we can pass 'damage' directly if we modify _spawn_single_projectile to handle manual damage override more gracefully.
			# Let's see _spawn_single_projectile...
			# It uses source_unit.calculate_damage_against...
			# I need to create a dummy source unit or modify _spawn_single_projectile to accept direct damage.
			# Actually, I can pass a dummy dictionary acting as object if GDScript allows (duck typing),
			# but 'calculate_damage_against' is a method.

			# Workaround: Create a lightweight object or struct, OR better:
			# create a specialized spawn function for this, OR reuse _spawn_single_projectile but fix the source dependency.

			# Let's check _spawn_single_projectile again.
			# `var base_dmg = source_unit.calculate_damage_against(target) if target else source_unit.damage`
			# So if I pass a duck-typed object with `damage` property, it works if target is null.
			# Here target is null.

			var dummy_source = MeteorSource.new(damage)
			_spawn_single_projectile(dummy_source, start_pos, null, stats)

		await get_tree().create_timer(0.1).timeout

# Inner class to act as a source unit for meteors, avoiding dictionary access errors
class MeteorSource:
	var damage: float
	var crit_rate: float = 0.0
	var crit_dmg: float = 1.5
	var type_key: String = "phoenix"
	var unit_data: Dictionary = {"proj": "fireball", "damageType": "fire"}

	func _init(dmg):
		damage = dmg

	func calculate_damage_against(_target):
		return damage

	func is_in_group(_group):
		return false

func spawn_boss_wave():
	# Hardcoded Wave 5 Event
	# Pick 2 different bosses from [summoner, ranger, tank]
	var boss_options = ["summoner", "ranger", "tank"]
	boss_options.shuffle()

	var boss1 = boss_options[0]
	var boss2 = boss_options[1]

	total_enemies_for_wave = 2
	enemies_to_spawn = 2

	GameManager.spawn_floating_text(Vector2(0, -200), "DOUBLE BOSS WAVE!", Color.RED)

	# Spawn Boss 1 on Left, Boss 2 on Right (Assuming standard spawn points)
	# We need to find valid spawn points.
	var spawn_points = []
	if GameManager.grid_manager:
		spawn_points = GameManager.grid_manager.get_spawn_points()

	if spawn_points.is_empty():
		spawn_points.append(Vector2(-300, 0))
		spawn_points.append(Vector2(300, 0))

	# Try to find left-most and right-most points
	spawn_points.sort_custom(func(a, b): return a.x < b.x)

	var left_point = spawn_points[0]
	var right_point = spawn_points[spawn_points.size() - 1]

	_spawn_enemy_at_pos(left_point, boss1)
	enemies_to_spawn -= 1
	await get_tree().create_timer(1.0).timeout
	_spawn_enemy_at_pos(right_point, boss2)
	enemies_to_spawn -= 1

	start_win_check_loop()

func _run_batch_sequence(batches_left: int, enemies_per_batch: int):
	if !GameManager.is_wave_active or batches_left <= 0:
		return

	# Determine type for this batch
	var wave_type = get_wave_type(GameManager.wave)
	var type_key = wave_type

	# Logic from ref.html simplified/fixed:
	# If it's a normal wave (not boss), we might want variation?
	# ref.html logic: if 'normal' (which is default for non-boss/tank/fast), pick random variant.
	# But get_wave_type returns specific types like 'slime', 'wolf'.
	# We will respect get_wave_type unless it is 'event'.

	if wave_type == 'boss':
		type_key = 'boss'
	elif wave_type == 'event':
		# Random variant for event waves (or maybe mixed)
		var variants = ['slime', 'wolf', 'poison', 'shooter']
		type_key = variants.pick_random()
	elif GameManager.wave == 2:
		# Special mix for Wave 2
		# Mix 'mutant_slime' and 'crab'
		if randf() < 0.3: # 30% chance for Crab
			type_key = 'crab'
		else:
			type_key = 'mutant_slime'
	else:
		# It returned a specific type like 'slime' or 'wolf'
		# We use that. However, ref.html seemed to fallback to random 'normal' often.
		# To make it more interesting and match "Game Expert" role, let's keep specific types
		# to give distinct wave feel, but maybe mix in some randoms if needed.
		# For now, strict adherence to the returned type.
		pass

	# Spawn Batch
	await _spawn_batch(type_key, enemies_per_batch)

	# Schedule next batch
	if batches_left > 1:
		# Wait between batches (2s - 4s depending on wave)
		# const nextDelay = Math.max(2000, 4000 - (game.wave * 100));
		var delay = max(2.0, 4.0 - (GameManager.wave * 0.1))
		await get_tree().create_timer(delay).timeout
		_run_batch_sequence(batches_left - 1, enemies_per_batch)
	else:
		# Last batch spawned, wait for clear
		pass

	# Check win condition is handled in unit death logic usually,
	# but we need to ensure we track "enemies_to_spawn" correctly.
	# Actually, enemies_to_spawn is decremented when we spawn.
	# Game over/Win check should be in _process or signal based.
	# Existing _process had: if enemies_to_spawn <= 0 and active_enemies == 0: end_wave
	# We should keep that check but maybe optimized.
	start_win_check_loop()

func start_win_check_loop():
	# Simple polling for win condition
	while GameManager.is_wave_active:
		if enemies_to_spawn <= 0 and get_tree().get_nodes_in_group("enemies").size() == 0:
			GameManager.end_wave()
			break
		await get_tree().create_timer(0.5).timeout

func _spawn_batch(type_key: String, count: int):
	var points = []
	if GameManager.grid_manager:
		points = GameManager.grid_manager.get_spawn_points()

	if points.size() == 0:
		# Fallback to map center or some default
		points.append(Vector2.ZERO)

	for i in range(count):
		if !GameManager.is_wave_active: break
		if enemies_to_spawn <= 0: break

		var spawn_point = points.pick_random()

		# Spawn with slight spread around the chosen spawn point
		var pos = spawn_point + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		_spawn_enemy_at_pos(pos, type_key)

		enemies_to_spawn -= 1

		# Fast spawn (0.1s)
		await get_tree().create_timer(0.1).timeout

func _spawn_enemy_at_pos(pos: Vector2, type_key: String):
	var enemy = ENEMY_SCENE.instantiate()
	if type_key == "healer":
		enemy.set_script(HEALER_SCRIPT)
	enemy.setup(type_key, GameManager.wave)
	enemy.global_position = pos
	add_child(enemy)

func find_nearest_enemy(pos: Vector2, range_val: float):
	var nearest = null
	var min_dist = range_val

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist = pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy

	return nearest

func get_enemies_in_range(pos: Vector2, range_val: float) -> Array:
	var found = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
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

func trigger_burn_explosion(pos: Vector2, damage: float, source: Node2D):
	explosion_queue.append({ "type": "burn", "pos": pos, "damage": damage, "source": source, "stacks": 1 })

func trigger_poison_explosion(pos: Vector2, damage: float, stacks: int, source: Node2D):
	explosion_queue.append({ "type": "poison", "pos": pos, "damage": damage, "source": source, "stacks": stacks })

func _process_burn_explosion_logic(pos: Vector2, damage: float, source: Node2D):
	var radius = 120.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var burn_script = load("res://src/Scripts/Effects/BurnEffect.gd")
	var affected_targets = []

	for enemy in enemies:
		if !is_instance_valid(enemy): continue

		var dist = pos.distance_to(enemy.global_position)
		if dist <= radius:
			enemy.take_damage(damage, source, "fire")
			affected_targets.append(enemy)
			# Chain reaction: Apply burn
			if enemy.has_method("apply_status"):
				enemy.apply_status(burn_script, {
					"duration": 5.0,
					"damage": damage,
					"stacks": 1
				})

	# Emit signal for test logging with affected targets
	if GameManager.has_signal("burn_explosion"):
		GameManager.burn_explosion.emit(pos, damage, source, affected_targets)

func _process_poison_explosion_logic(pos: Vector2, damage: float, stacks: int, source: Node2D):
	var radius = 100.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var poison_script = load("res://src/Scripts/Effects/PoisonEffect.gd")
	var affected_targets = []

	for enemy in enemies:
		if !is_instance_valid(enemy): continue

		var dist = pos.distance_to(enemy.global_position)
		if dist <= radius:
			enemy.take_damage(damage, source, "poison")
			affected_targets.append(enemy)
			# Spread poison with reduced stacks (half of original, min 1)
			if enemy.has_method("apply_status"):
				var spread_stacks = max(1, int(stacks * 0.5))
				enemy.apply_status(poison_script, {
					"duration": 5.0,
					"damage": damage / spread_stacks if spread_stacks > 0 else damage,
					"stacks": spread_stacks
				})

	# Emit signal for test logging with affected targets
	if GameManager.has_signal("poison_explosion"):
		GameManager.poison_explosion.emit(pos, damage, stacks, source)

func check_kill_bonuses(killer_unit, victim = null):
	if killer_unit and "active_buffs" in killer_unit:
		if "wealth" in killer_unit.active_buffs:
			GameManager.add_gold(1)
			GameManager.spawn_floating_text(killer_unit.global_position, "+1 Gold", Color.YELLOW)

	if killer_unit and killer_unit is Node and "behavior" in killer_unit and killer_unit.behavior and killer_unit.behavior.has_method("on_kill"):
		killer_unit.behavior.on_kill(victim)


func deal_global_damage(damage: float, type: String):
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[CombatManager] Global Damage: ", damage, " Enemies found: ", enemies.size())
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Pass GameManager as source since it's a core effect
			enemy.take_damage(damage, GameManager, type)
