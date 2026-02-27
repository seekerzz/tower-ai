extends Node

var config: Dictionary = {}
var elapsed_time: float = 0.0
var logs: Array = []
var scheduled_actions_executed: Array = []
var _frame_events: Array = []
var _is_tearing_down: bool = false
var _wave_has_started: bool = false

# 数值验证系统
var _validation_results: Array = []
var _baselines: Dictionary = {}  # 存储初始值
var _validation_failures: int = 0
var _executed_validations: Array = []  # 记录已执行的验证索引，避免重复执行

# 资源追踪
var _last_gold: int = 0
var _last_mana: float = 0.0
var _last_core_health: float = 0.0

func _ready():
	config = GameManager.current_test_scenario

	print("[TestRunner] Starting test: ", config.get("id", "Unknown"))

	if config.has("start_wave_index"):
		GameManager.wave = config["start_wave_index"]

	if config.has("core_type"):
		GameManager.core_type = config["core_type"]

	# 应用测试配置的核心血量设置
	if config.has("max_core_health"):
		GameManager.max_core_health = config["max_core_health"]
		print("[TestRunner] Set max_core_health: ", config["max_core_health"])

	if config.has("core_health"):
		GameManager.core_health = config["core_health"]
		print("[TestRunner] Set core_health: ", config["core_health"])

	call_deferred("_setup_test")

func _setup_test():
	if !GameManager.grid_manager:
		printerr("[TestRunner] GridManager not ready!")
		return

	# Place units
	if config.has("units"):
		for u in config["units"]:
			# Force unlock tile if needed (Test requirement override)
			var key = GameManager.grid_manager.get_tile_key(u.x, u.y)
			if GameManager.grid_manager.tiles.has(key):
				var tile = GameManager.grid_manager.tiles[key]
				if tile.state != "unlocked":
					tile.set_state("unlocked")
					if not GameManager.grid_manager.active_territory_tiles.has(tile):
						GameManager.grid_manager.active_territory_tiles.append(tile)

			GameManager.grid_manager.place_unit(u.id, u.x, u.y)

	# 单位放置后重新应用测试配置的血量设置（防止被recalculate_max_health覆盖）
	if config.has("max_core_health"):
		GameManager.max_core_health = config["max_core_health"]
	if config.has("core_health"):
		GameManager.core_health = config["core_health"]
		print("[TestRunner] Re-applied core_health after unit placement: ", config["core_health"])

	# Setup actions
	if config.has("setup_actions"):
		for action in config["setup_actions"]:
			_execute_setup_action(action)

	GameManager.game_over.connect(_on_game_over)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.enemy_spawned.connect(_on_enemy_spawned)
	GameManager.enemy_hit.connect(_on_enemy_hit)
	GameManager.enemy_died.connect(_on_enemy_died)
	GameManager.resource_changed.connect(_on_resource_changed)
	GameManager.skill_activated.connect(_on_skill_activated)
	GameManager.unit_devoured.connect(_on_unit_devoured)
	GameManager.unit_upgraded.connect(_on_unit_upgraded)
	GameManager.unit_purchased.connect(_on_unit_purchased)
	GameManager.unit_sold.connect(_on_unit_sold)
	GameManager.damage_dealt.connect(_on_damage_dealt)

	# Connect new buff/debuff/crit/shield events
	GameManager.buff_applied.connect(_on_buff_applied)
	GameManager.debuff_applied.connect(_on_debuff_applied)
	GameManager.shield_generated.connect(_on_shield_generated)
	GameManager.shield_absorbed.connect(_on_shield_absorbed)
	GameManager.crit_occurred.connect(_on_crit_occurred)
	GameManager.echo_triggered.connect(_on_echo_triggered)
	GameManager.taunt_applied.connect(_on_taunt_applied)
	GameManager.trap_placed.connect(_on_trap_placed)
	GameManager.trap_triggered.connect(_on_trap_triggered)
	GameManager.heal_stored.connect(_on_heal_stored)
	GameManager.counter_attack.connect(_on_counter_attack)
	GameManager.poison_damage.connect(_on_poison_damage)
	GameManager.bleed_damage.connect(_on_bleed_damage)
	GameManager.orb_hit.connect(_on_orb_hit)

	# Connect core heal event for lifesteal logging
	GameManager.core_healed.connect(_on_core_healed)

	# Connect lifesteal manager signal if available
	if GameManager.lifesteal_manager and GameManager.lifesteal_manager.has_signal("lifesteal_occurred"):
		GameManager.lifesteal_manager.lifesteal_occurred.connect(_on_lifesteal_occurred)

	# 初始化资源追踪
	_last_gold = GameManager.gold
	_last_mana = GameManager.mana
	_last_core_health = GameManager.core_health

	GameManager.start_wave()
	# GameManager.wave_ended is only emitted after UI interaction, which we skip in headless.
	# So we monitor is_wave_active in _process instead.

func _on_wave_started():
	_wave_has_started = true

func _on_enemy_spawned(enemy):
	var pos = enemy.global_position
	if "enemy_data" in enemy:
		pos = enemy.global_position # Redundant but safe

	_frame_events.append({
		"type": "spawn",
		"enemy_id": enemy.get_instance_id(),
		"enemy_type": enemy.type_key,
		"pos_x": pos.x,
		"pos_y": pos.y
	})

	# Apply debuffs from test configuration
	_apply_debuffs_to_enemy(enemy)

func _on_enemy_hit(enemy, source, amount):
	var source_id = "unknown"
	if source:
		if source is Node:
			source_id = source.name
		if "type_key" in source:
			source_id = source.type_key

	_frame_events.append({
		"type": "hit",
		"target_id": enemy.get_instance_id(),
		"source": source_id,
		"damage": amount,
		"target_hp_after": enemy.hp
	})

func _on_enemy_died(enemy, killer_unit):
	var killer_id = "unknown"
	if killer_unit and "type_key" in killer_unit:
		killer_id = killer_unit.type_key

	_frame_events.append({
		"type": "enemy_died",
		"enemy_id": enemy.get_instance_id() if is_instance_valid(enemy) else 0,
		"enemy_type": enemy.type_key if is_instance_valid(enemy) else "unknown",
		"killer": killer_id
	})

func _on_resource_changed():
	# 资源变化时记录（用于追踪金币/法力获取）
	var current_gold = GameManager.gold
	var current_mana = GameManager.mana
	var current_core_health = GameManager.core_health

	# 追踪金币变化
	if current_gold != _last_gold:
		var delta = current_gold - _last_gold
		if delta > 0:
			_frame_events.append({
				"type": "gold_gained",
				"amount": delta,
				"total": current_gold
			})
		_last_gold = current_gold

	# 追踪法力变化
	if current_mana != _last_mana:
		var delta = current_mana - _last_mana
		if delta > 0:
			_frame_events.append({
				"type": "mana_gained",
				"amount": delta,
				"total": current_mana
			})
		_last_mana = current_mana

	# 追踪核心受伤
	if current_core_health < _last_core_health:
		var damage = _last_core_health - current_core_health
		_frame_events.append({
			"type": "core_damaged",
			"damage": damage,
			"health_after": current_core_health,
			"max_health": GameManager.max_core_health
		})
	_last_core_health = current_core_health

func _on_skill_activated(unit):
	if not is_instance_valid(unit):
		return
	var unit_id = unit.type_key if unit.get("type_key") else "unknown"
	var skill_name = unit.unit_data.get("skill", "unknown") if unit.get("unit_data") else "unknown"
	_frame_events.append({
		"type": "skill_used",
		"unit_id": unit_id,
		"unit_instance_id": unit.get_instance_id(),
		"skill_id": skill_name,
		"position": {"x": unit.global_position.x, "y": unit.global_position.y}
	})

func _on_unit_devoured(eater_unit, eaten_unit, inherited_stats):
	if not is_instance_valid(eater_unit) or not is_instance_valid(eaten_unit):
		return
	_frame_events.append({
		"type": "devour",
		"eater_id": eater_unit.type_key if eater_unit.get("type_key") else "unknown",
		"eater_instance_id": eater_unit.get_instance_id(),
		"eaten_id": eaten_unit.type_key if eaten_unit.get("type_key") else "unknown",
		"eaten_instance_id": eaten_unit.get_instance_id(),
		"inherited_stats": inherited_stats if inherited_stats else {}
	})

func _on_unit_upgraded(unit, old_level, new_level):
	if not is_instance_valid(unit):
		return
	_frame_events.append({
		"type": "upgrade",
		"unit_id": unit.type_key if unit.get("type_key") else "unknown",
		"unit_instance_id": unit.get_instance_id(),
		"old_level": old_level,
		"new_level": new_level
	})

# ===== Buff/Debuff/Crit/Shield Event Handlers =====

func _on_buff_applied(target_unit, buff_type, source_unit, amount):
	if not is_instance_valid(target_unit):
		return
	_frame_events.append({
		"type": "buff_applied",
		"buff_type": buff_type,
		"target_id": target_unit.type_key if target_unit.get("type_key") else "unknown",
		"target_instance_id": target_unit.get_instance_id(),
		"source_id": source_unit.type_key if source_unit and source_unit.get("type_key") else "unknown",
		"amount": amount
	})

func _on_debuff_applied(target_unit, debuff_type, stacks):
	if not is_instance_valid(target_unit):
		return
	_frame_events.append({
		"type": "debuff_applied",
		"debuff_type": debuff_type,
		"target_id": target_unit.type_key if target_unit.get("type_key") else "unknown",
		"target_instance_id": target_unit.get_instance_id(),
		"stacks": stacks
	})

func _on_shield_generated(target_unit, shield_amount, source_unit):
	if not is_instance_valid(target_unit):
		return
	_frame_events.append({
		"type": "shield_generated",
		"target_id": target_unit.type_key if target_unit.get("type_key") else "unknown",
		"target_instance_id": target_unit.get_instance_id(),
		"source_id": source_unit.type_key if source_unit and source_unit.get("type_key") else "unknown",
		"shield_amount": shield_amount
	})

func _on_shield_absorbed(target_unit, damage_absorbed, remaining_shield, source_unit):
	if not is_instance_valid(target_unit):
		return
	_frame_events.append({
		"type": "shield_absorbed",
		"target_id": target_unit.type_key if target_unit.get("type_key") else "unknown",
		"target_instance_id": target_unit.get_instance_id(),
		"damage_absorbed": damage_absorbed,
		"remaining_shield": remaining_shield,
		"source_id": source_unit.type_key if source_unit and source_unit.get("type_key") else "unknown"
	})

func _on_crit_occurred(source_unit, target, damage, is_echo):
	if not is_instance_valid(source_unit):
		return
	var target_id = "unknown"
	var target_instance_id = 0
	if target and is_instance_valid(target):
		target_id = target.type_key if target.get("type_key") else target.name
		target_instance_id = target.get_instance_id()
	_frame_events.append({
		"type": "crit",
		"source_id": source_unit.type_key if source_unit.get("type_key") else "unknown",
		"source_instance_id": source_unit.get_instance_id(),
		"target_id": target_id,
		"target_instance_id": target_instance_id,
		"damage": damage,
		"is_echo": is_echo
	})

func _on_echo_triggered(source_unit, target, original_damage, echo_damage):
	if not is_instance_valid(source_unit):
		return
	var target_id = "unknown"
	var target_instance_id = 0
	if target and is_instance_valid(target):
		target_id = target.type_key if target.get("type_key") else target.name
		target_instance_id = target.get_instance_id()
	_frame_events.append({
		"type": "echo",
		"source_id": source_unit.type_key if source_unit.get("type_key") else "unknown",
		"source_instance_id": source_unit.get_instance_id(),
		"target_id": target_id,
		"target_instance_id": target_instance_id,
		"original_damage": original_damage,
		"echo_damage": echo_damage
	})

func _on_taunt_applied(source_unit, radius, duration):
	if not is_instance_valid(source_unit):
		return
	_frame_events.append({
		"type": "taunt",
		"source_id": source_unit.type_key if source_unit.get("type_key") else "unknown",
		"source_instance_id": source_unit.get_instance_id(),
		"radius": radius,
		"duration": duration
	})

func _on_trap_placed(trap_type, position, source_unit):
	var source_id = "unknown"
	if source_unit and is_instance_valid(source_unit):
		source_id = source_unit.type_key if source_unit.get("type_key") else "unknown"
	_frame_events.append({
		"type": "trap_placed",
		"trap_type": trap_type,
		"position": {"x": position.x, "y": position.y},
		"source_id": source_id
	})

func _on_trap_triggered(trap_type, target_enemy, source_unit):
	if not is_instance_valid(target_enemy):
		return
	var source_id = "unknown"
	if source_unit and is_instance_valid(source_unit):
		source_id = source_unit.type_key if source_unit.get("type_key") else "unknown"
	_frame_events.append({
		"type": "trap_triggered",
		"trap_type": trap_type,
		"target_id": target_enemy.type_key if target_enemy.get("type_key") else "unknown",
		"target_instance_id": target_enemy.get_instance_id(),
		"source_id": source_id
	})

func _on_heal_stored(healer_unit, amount, stored_total):
	if not is_instance_valid(healer_unit):
		return
	_frame_events.append({
		"type": "heal_stored",
		"healer_id": healer_unit.type_key if healer_unit.get("type_key") else "unknown",
		"healer_instance_id": healer_unit.get_instance_id(),
		"amount": amount,
		"stored_total": stored_total
	})

func _on_counter_attack(source_unit, damage, hits_taken):
	if not is_instance_valid(source_unit):
		return
	_frame_events.append({
		"type": "counter_attack",
		"source_id": source_unit.type_key if source_unit.get("type_key") else "unknown",
		"source_instance_id": source_unit.get_instance_id(),
		"damage": damage,
		"hits_taken": hits_taken
	})

func _on_poison_damage(target, damage, stacks, source):
	if not is_instance_valid(target):
		return
	var source_id = "unknown"
	if source and is_instance_valid(source):
		source_id = source.type_key if source.get("type_key") else "unknown"
	_frame_events.append({
		"type": "poison_damage",
		"target_id": target.type_key if target.get("type_key") else "unknown",
		"target_instance_id": target.get_instance_id(),
		"damage": damage,
		"stacks": stacks,
		"source_id": source_id
	})

func _on_bleed_damage(target, damage, stacks, source):
	if not is_instance_valid(target):
		return
	var source_id = "unknown"
	if source and is_instance_valid(source):
		source_id = source.type_key if source.get("type_key") else "unknown"
	_frame_events.append({
		"type": "bleed_damage",
		"target_id": target.type_key if target.get("type_key") else "unknown",
		"target_instance_id": target.get_instance_id(),
		"damage": damage,
		"stacks": stacks,
		"source_id": source_id
	})

func _on_orb_hit(target, damage, mana_gained, source):
	if not is_instance_valid(target):
		return
	_frame_events.append({
		"type": "orb_hit",
		"target_id": target.type_key if target.get("type_key") else "unknown",
		"target_instance_id": target.get_instance_id(),
		"damage": damage,
		"mana_gained": mana_gained
	})

func _on_core_healed(amount, overheal):
	_frame_events.append({
		"type": "core_healed",
		"amount": amount,
		"overheal": overheal,
		"source": "lifesteal"
	})

func _on_lifesteal_occurred(source, amount):
	if not is_instance_valid(source):
		return
	_frame_events.append({
		"type": "lifesteal",
		"source_id": source.type_key if source.get("type_key") else "unknown",
		"source_instance_id": source.get_instance_id(),
		"amount": amount
	})

# ===== Shop Phase Logging =====
func _on_wave_ended():
	print("[Shop] Wave ", GameManager.wave, " ended, entering shop phase")
	print("[Shop] Gold: ", GameManager.gold, ", Mana: ", GameManager.mana, "/", GameManager.max_mana)
	_frame_events.append({
		"type": "wave_ended",
		"wave": GameManager.wave,
		"gold": GameManager.gold,
		"mana": GameManager.mana
	})

func _on_unit_purchased(unit_data):
	print("[Shop] Player purchased unit '", unit_data.get("id", "unknown"), "' for ", unit_data.get("cost", 0), " gold")
	_frame_events.append({
		"type": "unit_purchased",
		"unit_id": unit_data.get("id", "unknown"),
		"cost": unit_data.get("cost", 0),
		"position": unit_data.get("position", {})
	})

func _on_unit_sold(amount):
	print("[Shop] Player sold unit for ", amount, " gold")
	_frame_events.append({
		"type": "unit_sold",
		"amount": amount,
		"gold_after": GameManager.gold
	})

# ===== Combat Phase Logging =====
func _on_damage_dealt(unit, amount):
	if not is_instance_valid(unit):
		return
	var unit_id = unit.type_key if unit.get("type_key") else "unknown"
	print("[Combat] Unit '", unit_id, "' dealt ", amount, " damage")
	_frame_events.append({
		"type": "damage_dealt",
		"unit_id": unit_id,
		"damage": amount
	})

func _apply_debuffs_to_enemy(enemy):
	"""Apply debuffs specified in test config to spawned enemy."""
	if not config.has("enemies"):
		return

	var enemy_type = enemy.type_key if "type_key" in enemy else ""

	for enemy_config in config["enemies"]:
		if enemy_config.get("type", "") == enemy_type:
			if enemy_config.has("debuffs"):
				for debuff in enemy_config["debuffs"]:
					var debuff_type = debuff.get("type", "")
					var stacks = debuff.get("stacks", 1)

					match debuff_type:
						"bleed":
							if enemy.has_method("add_bleed_stacks"):
								enemy.add_bleed_stacks(stacks, null)
								print("[TestRunner] Applied ", stacks, " bleed stacks to ", enemy_type)
						"poison":
							if enemy.has_method("add_poison_stacks"):
								enemy.add_poison_stacks(stacks, null)
								print("[TestRunner] Applied ", stacks, " poison stacks to ", enemy_type)
						_:
							print("[TestRunner] Unknown debuff type: ", debuff_type)
			break

func _execute_setup_action(action: Dictionary):
	match action.type:
		"spawn_trap":
			if action.strategy == "random_valid":
				_spawn_random_trap(action.trap_id)
		"apply_buff":
			_apply_buff_to_unit(action.target_unit_id, action.buff_id)

func _spawn_random_trap(trap_id: String):
	# Map test IDs to game IDs
	var real_trap_id = trap_id
	if trap_id == "poison_trap": real_trap_id = "poison"

	var valid_positions = []
	var gm = GameManager.grid_manager

	for key in gm.tiles:
		var tile = gm.tiles[key]
		var grid_pos = Vector2i(tile.x, tile.y)
		if gm.can_place_trap_at(grid_pos):
			valid_positions.append(grid_pos)

	if valid_positions.size() > 0:
		var pos = valid_positions.pick_random()
		gm.spawn_trap_custom(pos, real_trap_id)
		print("[TestRunner] Spawned trap ", real_trap_id, " at ", pos)
	else:
		printerr("[TestRunner] No valid position for trap ", real_trap_id)

func _apply_buff_to_unit(unit_id: String, buff_id: String):
	var gm = GameManager.grid_manager
	var found = false
	for key in gm.tiles:
		var tile = gm.tiles[key]
		if tile.unit and tile.unit.type_key == unit_id:
			tile.unit.apply_buff(buff_id)
			print("[TestRunner] Applied buff ", buff_id, " to ", unit_id)
			found = true
			break
	if !found:
		printerr("[TestRunner] Unit not found for buff: ", unit_id)

func _process(delta):
	if _is_tearing_down: return
	elapsed_time += delta

	# Scheduled Actions
	if config.has("scheduled_actions"):
		for i in range(config["scheduled_actions"].size()):
			if i in scheduled_actions_executed: continue
			var action = config["scheduled_actions"][i]
			if elapsed_time >= action.time:
				_execute_scheduled_action(action)
				scheduled_actions_executed.append(i)

	# Logging (Every Frame)
	_log_status()

	# Execute Validations
	_execute_validations()

	# Shop Validation
	if config.has("validate_shop_faction"):
		_validate_shop_faction(config["validate_shop_faction"])

	# End conditions
	if config.has("duration") and elapsed_time >= config["duration"]:
		_teardown("Duration Reached")

	if config.get("end_condition") == "wave_end_or_fail":
		if _wave_has_started and not GameManager.is_wave_active:
			_teardown("Wave Combat Ended")

	# Fallback safety if wave logic fails or infinite loop
	if elapsed_time > 300.0:
		_teardown("Timeout Safety")

func _execute_validations():
	"""执行配置的数值验证"""
	if not config.has("validations"):
		return

	for i in range(config.validations.size()):
		if i in _executed_validations:
			continue

		var validation = config.validations[i]
		var check_time = validation.get("time", 0.0)
		if abs(elapsed_time - check_time) > 0.05:  # 允许0.05秒误差
			continue

		# 标记此验证已执行
		_executed_validations.append(i)

		var type = validation.get("type", "")
		var passed = false
		var message = ""

		match type:
			"core_health_changed":
				var baseline = _baselines.get("core_health", GameManager.core_health)
				var current = GameManager.core_health
				var expected_change = validation.get("expected_change", 0.0)
				var tolerance = validation.get("tolerance", 1.0)
				var actual_change = current - baseline

				if abs(actual_change - expected_change) <= tolerance:
					passed = true
					message = "核心血量变化验证通过: %s -> %s (变化: %s, 期望: %s)" % [baseline, current, actual_change, expected_change]
				else:
					passed = false
					message = "核心血量变化验证失败: %s -> %s (变化: %s, 期望: %s)" % [baseline, current, actual_change, expected_change]

			"core_health_increased":
				var baseline = _baselines.get("core_health", GameManager.core_health)
				var current = GameManager.core_health
				var min_increase = validation.get("min_increase", 1.0)

				if current > baseline + min_increase:
					passed = true
					message = "核心血量增加验证通过: %s -> %s (增加: %s)" % [baseline, current, current - baseline]
				else:
					passed = false
					message = "核心血量增加验证失败: %s -> %s (期望至少增加 %s)" % [baseline, current, min_increase]

			"enemy_hp_decreased":
				var enemy_type = validation.get("enemy_type", "")
				var min_damage = validation.get("min_damage", 1.0)
				var total_damage = 0.0

				# 从日志中计算伤害
				for entry in logs:
					for event in entry.get("events", []):
						if event.get("type") == "hit":
							total_damage += event.get("damage", 0.0)

				if total_damage >= min_damage:
					passed = true
					message = "敌人受伤验证通过: 总伤害 %s (期望至少 %s)" % [total_damage, min_damage]
				else:
					passed = false
					message = "敌人受伤验证失败: 总伤害 %s (期望至少 %s)" % [total_damage, min_damage]

			"event_occurred":
				var event_type = validation.get("event_type", "")
				var count = 0

				for entry in logs:
					for event in entry.get("events", []):
						if event.get("type") == event_type:
							count += 1

				var min_count = validation.get("min_count", 1)
				if count >= min_count:
					passed = true
					message = "事件验证通过: %s 发生 %s 次 (期望至少 %s)" % [event_type, count, min_count]
				else:
					passed = false
					message = "事件验证失败: %s 发生 %s 次 (期望至少 %s)" % [event_type, count, min_count]

			_:
				message = "未知验证类型: %s" % type

		# 记录结果
		_validation_results.append({
			"time": elapsed_time,
			"type": type,
			"passed": passed,
			"message": message
		})

		if passed:
			print("[TestRunner] [PASS] ", message)
		else:
			printerr("[TestRunner] [FAIL] ", message)
			_validation_failures += 1

func _execute_scheduled_action(action: Dictionary):
	match action.type:
		"skill":
			var source_id = action.source
			var target_pos = Vector2i(action.target.x, action.target.y)
			var gm = GameManager.grid_manager
			for key in gm.tiles:
				var tile = gm.tiles[key]
				if tile.unit and tile.unit.type_key == source_id:
					tile.unit.execute_skill_at(target_pos)
					print("[TestRunner] Executed skill for ", source_id, " at ", target_pos)
					break
		"summon_test":
			var summon_type = action.summon_type
			var pos_dict = action.position

			var pos = Vector2.ZERO
			if GameManager.grid_manager:
				pos = GameManager.grid_manager.get_world_pos_from_grid(Vector2i(pos_dict.x, pos_dict.y))
			else:
				pos = Vector2(pos_dict.x * 60, pos_dict.y * 60) # Fallback TILE_SIZE=60

			if GameManager.summon_manager:
				var data = {
					"unit_id": summon_type,
					"position": pos,
					"lifetime": 5.0 # Test lifetime override if needed, or rely on default
				}
				GameManager.summon_manager.create_summon(data)
				print("[TestRunner] Summoned ", summon_type, " at ", pos)
			else:
				printerr("[TestRunner] SummonManager not available")
		"test_enemy_death":
			_run_enemy_death_test()
		"record_baseline":
			# 记录当前数值作为基准
			var metrics = action.get("metrics", ["core_health"])
			for metric in metrics:
				match metric:
					"core_health":
						_baselines["core_health"] = GameManager.core_health
						print("[TestRunner] Recorded baseline core_health: ", GameManager.core_health)
					"mana":
						_baselines["mana"] = GameManager.mana
						print("[TestRunner] Recorded baseline mana: ", GameManager.mana)
					"gold":
						_baselines["gold"] = GameManager.gold
						print("[TestRunner] Recorded baseline gold: ", GameManager.gold)
					_:
						print("[TestRunner] Unknown metric for baseline: ", metric)
		"verify_change":
			# 立即执行一次验证
			var validation = {
				"time": elapsed_time,
				"type": action.get("validation_type", "core_health_changed"),
				"expected_change": action.get("expected_change", 0.0),
				"tolerance": action.get("tolerance", 1.0),
				"min_increase": action.get("min_increase", 1.0),
				"event_type": action.get("event_type", ""),
				"min_count": action.get("min_count", 1)
			}
			config.validations = [validation]
			_execute_validations()
			config.erase("validations")

func _run_enemy_death_test():
	print("[TestRunner] ========== 开始敌人死亡重复调用测试 ==========")

	# 使用一个独立节点来跟踪信号计数（避免lambda的变量捕获问题）
	var tracker = Node.new()
	tracker.set_meta("death_count", 0)
	tracker.set_meta("soul_before", SoulManager.current_souls)
	get_tree().current_scene.add_child(tracker)

	# 创建测试敌人
	var enemy_scene = load("res://src/Scenes/Game/Enemy.tscn")
	if not enemy_scene:
		printerr("[TestRunner] 无法加载敌人场景")
		return

	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(400, 400)
	enemy.setup("slime", 1)
	enemy.hp = 100
	enemy.max_hp = 100

	# 连接信号
	enemy.died.connect(func():
		var count = tracker.get_meta("death_count") + 1
		tracker.set_meta("death_count", count)
		print("[TestRunner] died 信号触发 #", count)
	)

	get_tree().current_scene.add_child(enemy)
	print("[TestRunner] 测试敌人创建完成，HP: ", enemy.hp, ", 初始魂魄: ", tracker.get_meta("soul_before"))

	await get_tree().process_frame

	# 模拟多段伤害
	print("[TestRunner] 模拟多段伤害 (3次 take_damage 调用)...")
	enemy.take_damage(40, null)
	enemy.take_damage(40, null)
	enemy.take_damage(40, null)

	await get_tree().process_frame
	await get_tree().process_frame

	# 验证结果
	print("\n[TestRunner] ========== 测试结果 ==========")
	var test_passed = true

	var death_count = tracker.get_meta("death_count")
	var soul_increase = SoulManager.current_souls - tracker.get_meta("soul_before")

	# 验证1: died 信号只应该触发一次
	if death_count == 0:
		printerr("[TestRunner] ✗ died 信号没有被触发")
		test_passed = false
	elif death_count > 1:
		printerr("[TestRunner] ✗ died 信号被触发了 ", death_count, " 次 - 存在重复调用bug!")
		test_passed = false
	else:
		print("[TestRunner] ✓ died 信号正确触发1次")

	# 验证2: 魂魄只应该增加1次
	if soul_increase == 0:
		printerr("[TestRunner] ✗ 魂魄没有增加")
		test_passed = false
	elif soul_increase > 1:
		printerr("[TestRunner] ✗ 魂魄增加了 ", soul_increase, " 次!")
		test_passed = false
	else:
		print("[TestRunner] ✓ 魂魄正确增加1次 (", SoulManager.current_souls, ")")

	if test_passed:
		print("\n[TestRunner] ========== 测试通过 ✓ ==========")
	else:
		print("\n[TestRunner] ========== 测试失败 ✗ ==========")

	# 清理
	if is_instance_valid(enemy):
		enemy.queue_free()
	tracker.queue_free()

	print("[TestRunner] ========== 敌人死亡测试结束 ==========\n")

func _log_status():
	var units_info = []
	var gm = GameManager.grid_manager
	if gm:
		for key in gm.tiles:
			var tile = gm.tiles[key]
			if tile.unit:
				var u = tile.unit
				units_info.append({
					"id": u.type_key,
					"grid_x": tile.x,
					"grid_y": tile.y,
					"level": u.level,
					"damage_stat": u.damage,
					"hp": u.current_hp,
					"max_hp": u.max_hp,
					"attack_speed": u.atk_speed,
					"attack_range": u.range_val
				})

	var enemies_info = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var enemy_data = {
				"instance_id": enemy.get_instance_id(),
				"type": enemy.type_key,
				"hp": enemy.hp,
				"max_hp": enemy.max_hp,
				"pos_x": enemy.global_position.x,
				"pos_y": enemy.global_position.y,
				"speed": enemy.speed if "speed" in enemy else 0,
				"bleed_stacks": enemy.bleed_stacks if "bleed_stacks" in enemy else 0
			}
			# 添加路径信息（如果行为存在）
			if enemy.behavior and "path_index" in enemy.behavior:
				enemy_data["path_index"] = enemy.behavior.path_index
			enemies_info.append(enemy_data)

	# 获取地图信息
	var map_info = {}
	if gm and gm.tiles.size() > 0:
		var min_x = 9999
		var max_x = -9999
		var min_y = 9999
		var max_y = -9999
		for key in gm.tiles:
			var tile = gm.tiles[key]
			min_x = min(min_x, tile.x)
			max_x = max(max_x, tile.x)
			min_y = min(min_y, tile.y)
			max_y = max(max_y, tile.y)
		map_info = {
			"grid_width": max_x - min_x + 1,
			"grid_height": max_y - min_y + 1,
			"cell_size": Constants.TILE_SIZE
		}

	# 获取商店信息
	var shop_info = {}
	var shop_units = []
	var shop = get_tree().root.find_child("Shop", true, false)
	if not shop and GameManager.main_game:
		shop = GameManager.main_game.find_child("Shop", true, false)
	if is_instance_valid(shop) and "shop_items" in shop:
		var items: Array = shop.shop_items
		for i in range(items.size()):
			var item_id = str(items[i])
			var unit_data = Constants.UNIT_TYPES.get(item_id, {})
			shop_units.append({
				"id": item_id,
				"name": unit_data.get("name", item_id),
				"faction": unit_data.get("faction", "universal"),
				"cost": unit_data.get("cost", 0),
				"rarity": unit_data.get("rarity", "common")
			})

	# 如果商店为空，提供默认单位
	if shop_units.is_empty():
		shop_units = _get_default_shop_units()

	shop_info = {
		"available_units": shop_units,
		"refresh_cost": 2,
		"is_active": not GameManager.is_wave_active
	}

	# 获取魂魄系统状态（狼图腾）
	var soul_info = {}
	if get_node_or_null("/root/SoulManager"):
		soul_info = {
			"current_souls": SoulManager.current_souls,
			"max_souls": SoulManager.max_souls
		}

	var entry = {
		"frame": Engine.get_process_frames(),
		"time": elapsed_time,
		"wave": GameManager.wave,
		"is_wave_active": GameManager.is_wave_active,
		"gold": GameManager.gold,
		"mana": GameManager.mana,
		"core_health": GameManager.core_health,
		"max_core_health": GameManager.max_core_health,
		"units": units_info,
		"enemies": enemies_info,
		"map_info": map_info,
		"shop_info": shop_info,
		"soul_info": soul_info,
		"events": _frame_events.duplicate()
	}
	logs.append(entry)
	_frame_events.clear()

func _on_game_over():
	_teardown("Game Over Signal")

func _validate_shop_faction(faction: String):
	var shop = get_tree().root.find_child("Shop", true, false)
	if not shop:
		# Try MainGame CanvasLayer
		if GameManager.main_game:
			shop = GameManager.main_game.find_child("Shop", true, false)

	if not shop:
		# Shop might not be instantiated yet
		return

	# Assuming shop has 'shop_items' array of strings (unit keys)
	if "shop_items" in shop:
		var items = shop.shop_items
		if items.size() == 0:
			# Shop might not be ready yet
			return

		var all_valid = true
		for item in items:
			var unit_data = Constants.UNIT_TYPES.get(item, {})
			var unit_faction = unit_data.get("faction", "universal")

			if unit_faction != faction and unit_faction != "universal":
				all_valid = false
				printerr("[TestRunner] Shop validation FAILED. Found unit '%s' (faction: %s) but expected faction '%s'" % [item, unit_faction, faction])
				_teardown("Shop Validation Failed")
				return

		if all_valid:
			print("[TestRunner] Shop validation PASSED for faction: ", faction, ". Items: ", items)
			# Only validate once successfully then stop checking to avoid log spam
			config.erase("validate_shop_faction")

func _get_default_shop_units() -> Array:
	var default_units = []
	var core_type = GameManager.core_type

	# 根据核心类型提供默认单位
	var default_unit_ids = []
	match core_type:
		"wolf_totem":
			default_unit_ids = ["wolf", "dog", "fox"]
		"bat_totem":
			default_unit_ids = ["mosquito", "blood_mage", "vampire_bat"]
		"viper_totem":
			default_unit_ids = ["snake", "cobra", "python"]
		"cow_totem":
			default_unit_ids = ["yak", "bull", "ox"]
		"eagle_totem":
			default_unit_ids = ["eagle", "hawk", "falcon"]
		"butterfly_totem":
			default_unit_ids = ["butterfly", "moth", "firefly"]
		_:
			# 通用默认单位
			default_unit_ids = ["squirrel", "rabbit", "deer"]

	for unit_id in default_unit_ids:
		var unit_data = Constants.UNIT_TYPES.get(unit_id, {})
		if not unit_data.is_empty():
			default_units.append({
				"id": unit_id,
				"name": unit_data.get("name", unit_id),
				"faction": unit_data.get("faction", "universal"),
				"cost": unit_data.get("cost", 50),
				"rarity": unit_data.get("rarity", "common")
			})

	# 如果没有找到任何单位，提供基础默认单位
	if default_units.is_empty():
		default_units = [
			{"id": "wolf", "name": "狼", "faction": "wolf", "cost": 50, "rarity": "common"},
			{"id": "bat", "name": "蝙蝠", "faction": "bat", "cost": 60, "rarity": "common"},
			{"id": "snake", "name": "蛇", "faction": "viper", "cost": 55, "rarity": "common"}
		]

	return default_units

func _teardown(reason: String):
	if _is_tearing_down:
		return
	_is_tearing_down = true

	print("[TestRunner] Finishing test. Reason: ", reason)

	# 输出验证结果汇总
	print("\n[TestRunner] ========== 验证结果汇总 ==========")
	if _validation_results.is_empty():
		print("[TestRunner] 无验证项")
	else:
		var passed_count = 0
		var failed_count = 0
		for result in _validation_results:
			if result.passed:
				passed_count += 1
				print("[TestRunner] [PASS] ", result.message)
			else:
				failed_count += 1
				printerr("[TestRunner] [FAIL] ", result.message)

		print("\n[TestRunner] 验证统计: 通过 %d, 失败 %d, 总计 %d" % [passed_count, failed_count, _validation_results.size()])

		if failed_count > 0:
			printerr("[TestRunner] ========== 测试未通过 (有验证失败) ==========")
		else:
			print("[TestRunner] ========== 所有验证通过 ==========")

	# 保存日志
	var user_dir = "user://test_logs/"
	if !DirAccess.dir_exists_absolute(user_dir):
		DirAccess.make_dir_absolute(user_dir)

	# 保存详细日志
	var file_path = user_dir + config.id + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# 添加验证结果到日志
		var output_data = {
			"logs": logs,
			"validations": _validation_results,
			"summary": {
				"test_id": config.get("id", "unknown"),
				"duration": elapsed_time,
				"validation_passed": _validation_failures == 0,
				"validation_failures": _validation_failures,
				"validation_count": _validation_results.size()
			}
		}
		file.store_string(JSON.stringify(output_data, "\t"))
		file.close()
		print("[TestRunner] Logs saved to ", file_path)
	else:
		printerr("[TestRunner] Failed to save logs to ", file_path)

	get_tree().quit()
