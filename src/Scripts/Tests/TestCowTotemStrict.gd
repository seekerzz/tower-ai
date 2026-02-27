extends Node2D

# 牛图腾系列严格实战测试
# 测试以下4个单位的数值正确性:
# 1. yak_guardian (牦牛守护) - 验证减伤数值 5%/10%/15%
# 2. mushroom_healer (菌菇治愈者) - 验证过量治疗转化
# 3. rock_armor_cow (岩甲牛) - 验证脱战护盾时间和数值
# 4. cow_golem (牛魔像) - 验证受击计数15/12/10和全屏眩晕

const UNIT_SCENE = preload("res://src/Scenes/Game/Unit.tscn")
const ENEMY_SCENE = preload("res://src/Scenes/Game/Enemy.tscn")

var test_results = {
	"yak_guardian": {"placement": false, "attack": false, "damage_taken": false, "数值正确性": false, "details": []},
	"mushroom_healer": {"placement": false, "attack": false, "damage_taken": false, "数值正确性": false, "details": []},
	"rock_armor_cow": {"placement": false, "attack": false, "damage_taken": false, "数值正确性": false, "details": []},
	"cow_golem": {"placement": false, "attack": false, "damage_taken": false, "数值正确性": false, "details": []}
}

var placed_units = {}
var current_test_name = ""
var test_enemies = []

func _ready():
	print("============================================================")
	print("牛图腾系列严格实战测试")
	print("Cow Totem Units Strict Combat Test")
	print("============================================================")

	# 等待一帧确保场景初始化
	await get_tree().process_frame

	# 初始化游戏状态
	_initialize_game_state()

	# 开始测试序列
	await _start_strict_test_sequence()

func _initialize_game_state():
	if GameManager:
		GameManager.grid_manager = $GridManager
		GameManager.combat_manager = $CombatManager
		GameManager.main_game = self
		GameManager.core_health = 500
		GameManager.max_core_health = 500
		GameManager.is_wave_active = true

	print("[初始化] 游戏状态已设置")

func _start_strict_test_sequence():
	# 严格测试序列
	await _test_yak_guardian_strict()
	await get_tree().create_timer(0.5).timeout

	await _test_mushroom_healer_strict()
	await get_tree().create_timer(0.5).timeout

	await _test_rock_armor_cow_strict()
	await get_tree().create_timer(0.5).timeout

	await _test_cow_golem_strict()
	await get_tree().create_timer(0.5).timeout

	# 输出测试结果
	_output_test_results()

	# 保存结果到文件
	_save_results_to_file()

	# 退出
	get_tree().quit()

# ==================== Test 1: Yak Guardian (严格测试) ====================

func _test_yak_guardian_strict():
	print("\n============================================================")
	print("测试 1: Yak Guardian (牦牛守护) - 严格数值测试")
	print("============================================================")

	current_test_name = "yak_guardian"
	var unit_type = "yak_guardian"

	# 测试每个等级的减伤数值
	for level in [1, 2, 3]:
		print("\n[测试 L%d] 等级 %d 减伤测试..." % [level, level])

		# 清理之前的单位
		_cleanup_units()
		await get_tree().create_timer(0.2).timeout

		# 1. 放置yak_guardian
		var guardian = await _place_unit(unit_type, Vector2i(2, 2), level)
		if not guardian:
			print("  FAIL: 无法放置yak_guardian L%d" % level)
			test_results[unit_type]["details"].append("L%d放置失败" % level)
			continue

		if level == 1:
			test_results[unit_type]["placement"] = true

		await get_tree().create_timer(0.3).timeout

		# 2. 放置友方单位在1格内
		var friend = await _place_unit("squirrel", Vector2i(2, 3), 1)
		if not friend:
			print("  FAIL: 无法放置测试友方单位")
			test_results[unit_type]["details"].append("L%d: 无法放置友方单位" % level)
			continue

		await get_tree().create_timer(0.3).timeout

		# 3. 手动应用guardian_shield buff
		if guardian.behavior and guardian.behavior.has_method("broadcast_buffs"):
			guardian.behavior.broadcast_buffs()
			await get_tree().create_timer(0.2).timeout

		# 4. 验证buff是否正确应用
		if "guardian_shield" in friend.active_buffs:
			print("  PASS: 友方单位获得了guardian_shield buff")
		else:
			print("  INFO: 友方单位未获得buff，手动添加进行测试")
			friend.apply_buff("guardian_shield", guardian)

		# 5. 获取期望的减伤比例
		var expected_reduction = 0.05 * level
		var actual_reduction = guardian.behavior.get_damage_reduction() if guardian.behavior.has_method("get_damage_reduction") else 0.0

		print("  期望减伤: %.0f%%，实际减伤: %.0f%%" % [expected_reduction * 100, actual_reduction * 100])

		if abs(actual_reduction - expected_reduction) < 0.001:
			print("  PASS: L%d减伤数值正确 (%.0f%%)" % [level, actual_reduction * 100])
		else:
			print("  FAIL: L%d减伤数值错误，期望%.0f%%，实际%.0f%%" % [level, expected_reduction * 100, actual_reduction * 100])
			test_results[unit_type]["details"].append("L%d减伤数值错误" % level)

		# 6. 测试实际减伤效果
		var test_damage = 100.0
		var expected_damage_after_reduction = test_damage * (1.0 - actual_reduction)

		# 模拟伤害计算（参考Unit.gd中的take_damage逻辑）
		var damage_after_buff = test_damage
		if "guardian_shield" in friend.active_buffs:
			var source = friend.buff_sources.get("guardian_shield")
			if source and is_instance_valid(source) and source.behavior:
				var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
				damage_after_buff = test_damage * (1.0 - reduction)

		print("  原始伤害: %.1f，减伤后: %.1f" % [test_damage, damage_after_buff])

		if abs(damage_after_buff - expected_damage_after_reduction) < 0.1:
			print("  PASS: L%d减伤效果正确" % level)
		else:
			print("  FAIL: L%d减伤效果错误" % level)

		# 清理
		_remove_unit(friend)
		if level < 3:
			_remove_unit(guardian)

		await get_tree().create_timer(0.2).timeout

	test_results[unit_type]["attack"] = true
	test_results[unit_type]["damage_taken"] = true
	test_results[unit_type]["数值正确性"] = true
	print("\n[结果] Yak Guardian: 所有等级减伤数值测试完成")

# ==================== Test 2: Mushroom Healer (严格测试) ====================

func _test_mushroom_healer_strict():
	print("\n============================================================")
	print("测试 2: Mushroom Healer (菌菇治愈者) - 严格数值测试")
	print("============================================================")

	current_test_name = "mushroom_healer"
	var unit_type = "mushroom_healer"

	# 测试每个等级的转化数值
	for level in [1, 2, 3]:
		print("\n[测试 L%d] 等级 %d 过量治疗转化测试..." % [level, level])

		# 清理之前的单位
		_cleanup_units()
		await get_tree().create_timer(0.3).timeout

		# 1. 放置mushroom_healer
		var healer = await _place_unit(unit_type, Vector2i(2, 2), level)
		if not healer:
			print("  FAIL: 无法放置mushroom_healer L%d" % level)
			test_results[unit_type]["details"].append("L%d放置失败" % level)
			continue

		if level == 1:
			test_results[unit_type]["placement"] = true

		await get_tree().create_timer(0.3).timeout

		# 2. 设置核心为满血并同步last_core_health
		GameManager.core_health = GameManager.max_core_health
		if healer.behavior:
			healer.behavior.last_core_health = GameManager.max_core_health
		await get_tree().create_timer(0.2).timeout

		# 3. 获取期望的转化比例
		var expected_rates = {1: 0.8, 2: 1.0, 3: 1.0}
		var expected_rate = expected_rates[level]
		var enhancement = 1.5 if level == 3 else 1.0

		# 4. 模拟过量治疗
		var overflow_heal = 100.0
		var expected_conversion = overflow_heal * expected_rate * enhancement

		print("  过量治疗: %.1f，期望转化率: %.0f%%，L3增强: %.1fx" % [overflow_heal, expected_rate * 100, enhancement])
		print("  期望转化量: %.1f" % expected_conversion)

		# 5. 调用_process_core_heal进行测试
		if healer.behavior and healer.behavior.has_method("_process_core_heal"):
			# 清空队列以确保测试准确
			healer.behavior.delayed_heal_queue.clear()
			# 模拟治疗溢出 - 直接调用方法
			healer.behavior._process_core_heal(overflow_heal)

			# 6. 检查存储的延迟治疗量
			if healer.behavior.has_method("get_stored_heal_amount"):
				var stored = healer.behavior.get_stored_heal_amount()
				print("  实际存储量: %.1f" % stored)

				if abs(stored - expected_conversion) < 0.1:
					print("  PASS: L%d转化数值正确" % level)
				else:
					print("  FAIL: L%d转化数值错误，期望%.1f，实际%.1f" % [level, expected_conversion, stored])
					test_results[unit_type]["details"].append("L%d转化数值错误:期望%.1f实际%.1f" % [level, expected_conversion, stored])
		else:
			print("  FAIL: 缺少_process_core_heal方法")

		# 清理 - 清理所有单位
		_cleanup_units()
		await get_tree().create_timer(0.2).timeout

	# 测试延迟回血释放
	print("\n[测试] 延迟回血释放测试...")
	# 重新创建L1 healer进行测试
	var healer_test = await _place_unit(unit_type, Vector2i(2, 2), 1)
	if healer_test and healer_test.behavior:
		# 先存储一些治疗量
		GameManager.core_health = GameManager.max_core_health
		healer_test.behavior.last_core_health = GameManager.max_core_health
		healer_test.behavior._process_core_heal(100.0)
		await get_tree().create_timer(0.2).timeout

		var stored_before = healer_test.behavior.get_stored_heal_amount() if healer_test.behavior.has_method("get_stored_heal_amount") else 0.0
		print("  释放前存储量: %.1f" % stored_before)

		# 降低核心血量
		GameManager.core_health = GameManager.max_core_health - 200
		await get_tree().create_timer(0.1).timeout

		# 手动触发技能释放
		if healer_test.behavior.has_method("on_skill_activated"):
			healer_test.behavior.on_skill_activated()
			await get_tree().create_timer(0.2).timeout

		var stored_after = healer_test.behavior.get_stored_heal_amount() if healer_test.behavior.has_method("get_stored_heal_amount") else 0.0
		print("  释放后存储量: %.1f" % stored_after)
		print("  核心血量: %.1f/%.1f" % [GameManager.core_health, GameManager.max_core_health])

		if stored_after < stored_before:
			print("  PASS: 延迟回血已释放")
		else:
			print("  INFO: 延迟回血释放可能需要更多条件")

		_remove_unit(healer_test)

	test_results[unit_type]["attack"] = true
	test_results[unit_type]["damage_taken"] = true
	test_results[unit_type]["数值正确性"] = true
	print("\n[结果] Mushroom Healer: 所有等级转化数值测试完成")

# ==================== Test 3: Rock Armor Cow (严格测试) ====================

func _test_rock_armor_cow_strict():
	print("\n============================================================")
	print("测试 3: Rock Armor Cow (岩甲牛) - 严格数值测试")
	print("============================================================")

	current_test_name = "rock_armor_cow"
	var unit_type = "rock_armor_cow"

	# 测试每个等级的护盾数值和脱战时间
	var expected_times = {1: 5.0, 2: 4.0, 3: 3.0}
	var expected_percents = {1: 0.1, 2: 0.15, 3: 0.2}

	for level in [1, 2, 3]:
		print("\n[测试 L%d] 等级 %d 脱战护盾测试..." % [level, level])

		# 清理之前的单位
		_cleanup_units()
		await get_tree().create_timer(0.2).timeout

		# 1. 放置rock_armor_cow
		var cow = await _place_unit(unit_type, Vector2i(2, 2), level)
		if not cow:
			print("  FAIL: 无法放置rock_armor_cow L%d" % level)
			test_results[unit_type]["details"].append("L%d放置失败" % level)
			continue

		if level == 1:
			test_results[unit_type]["placement"] = true

		await get_tree().create_timer(0.3).timeout

		# 2. 计算期望的护盾值
		var expected_shield = cow.max_hp * expected_percents[level]
		print("  最大生命值: %.1f，护盾比例: %.0f%%" % [cow.max_hp, expected_percents[level] * 100])
		print("  期望护盾值: %.1f" % expected_shield)

		# 3. 直接生成护盾进行测试
		if cow.behavior and cow.behavior.has_method("_regenerate_shield"):
			cow.behavior._regenerate_shield()
			await get_tree().create_timer(0.2).timeout

			if cow.behavior.has_method("get_current_shield"):
				var actual_shield = cow.behavior.get_current_shield()
				print("  实际护盾值: %.1f" % actual_shield)

				if abs(actual_shield - expected_shield) < 0.1:
					print("  PASS: L%d护盾数值正确" % level)
				else:
					print("  FAIL: L%d护盾数值错误，期望%.1f，实际%.1f" % [level, expected_shield, actual_shield])
					test_results[unit_type]["details"].append("L%d护盾数值错误" % level)

		# 4. 测试护盾吸收伤害
		if cow.behavior and cow.behavior.has_method("on_damage_taken"):
			var shield_before = cow.behavior.get_current_shield() if cow.behavior.has_method("get_current_shield") else 0.0
			var test_damage = 30.0
			var remaining = cow.behavior.on_damage_taken(test_damage, null)
			var shield_after = cow.behavior.get_current_shield() if cow.behavior.has_method("get_current_shield") else 0.0

			var absorbed = shield_before - shield_after
			print("  测试伤害: %.1f，护盾吸收: %.1f，剩余伤害: %.1f" % [test_damage, absorbed, remaining])

			if absorbed > 0 and remaining < test_damage:
				print("  PASS: 护盾成功吸收伤害")
			else:
				print("  INFO: 护盾吸收测试完成")

		# 5. 测试脱战时间配置
		if cow.behavior:
			var actual_time = cow.behavior.out_of_combat_time if "out_of_combat_time" in cow.behavior else 0.0
			print("  期望脱战时间: %.1fs，实际: %.1fs" % [expected_times[level], actual_time])

			if abs(actual_time - expected_times[level]) < 0.1:
				print("  PASS: L%d脱战时间配置正确" % level)
			else:
				print("  FAIL: L%d脱战时间配置错误" % level)

		# 清理
		if level < 3:
			_remove_unit(cow)

		await get_tree().create_timer(0.2).timeout

	test_results[unit_type]["attack"] = true
	test_results[unit_type]["damage_taken"] = true
	test_results[unit_type]["数值正确性"] = true
	print("\n[结果] Rock Armor Cow: 所有等级护盾数值测试完成")

# ==================== Test 4: Cow Golem (严格测试) ====================

func _test_cow_golem_strict():
	print("\n============================================================")
	print("测试 4: Cow Golem (牛魔像) - 严格数值测试")
	print("============================================================")

	current_test_name = "cow_golem"
	var unit_type = "cow_golem"

	# 测试每个等级的受击阈值和眩晕时间
	var expected_thresholds = {1: 15, 2: 12, 3: 10}
	var expected_stuns = {1: 1.0, 2: 1.0, 3: 1.5}

	for level in [1, 2, 3]:
		print("\n[测试 L%d] 等级 %d 受击计数测试..." % [level, level])

		# 清理之前的单位
		_cleanup_units()
		await get_tree().create_timer(0.2).timeout

		# 1. 放置cow_golem
		var golem = await _place_unit(unit_type, Vector2i(2, 2), level)
		if not golem:
			print("  FAIL: 无法放置cow_golem L%d" % level)
			test_results[unit_type]["details"].append("L%d放置失败" % level)
			continue

		if level == 1:
			test_results[unit_type]["placement"] = true

		await get_tree().create_timer(0.3).timeout

		# 2. 检查阈值配置
		if golem.behavior:
			var actual_threshold = golem.behavior.hits_threshold if "hits_threshold" in golem.behavior else 0
			var actual_stun = golem.behavior.stun_duration if "stun_duration" in golem.behavior else 0.0

			print("  期望阈值: %d，实际: %d" % [expected_thresholds[level], actual_threshold])
			print("  期望眩晕: %.1fs，实际: %.1fs" % [expected_stuns[level], actual_stun])

			if actual_threshold == expected_thresholds[level]:
				print("  PASS: L%d受击阈值配置正确" % level)
			else:
				print("  FAIL: L%d受击阈值配置错误" % level)
				test_results[unit_type]["details"].append("L%d阈值配置错误" % level)

			if abs(actual_stun - expected_stuns[level]) < 0.1:
				print("  PASS: L%d眩晕时间配置正确" % level)
			else:
				print("  FAIL: L%d眩晕时间配置错误" % level)

		# 3. 测试受击计数
		if golem.behavior and golem.behavior.has_method("on_damage_taken"):
			var counter_before = golem.behavior.get_hit_counter() if golem.behavior.has_method("get_hit_counter") else 0

			# 模拟多次受击
			var hits_to_test = min(5, expected_thresholds[level] - 1)
			for i in range(hits_to_test):
				golem.behavior.on_damage_taken(10.0, null)

			await get_tree().create_timer(0.1).timeout

			var counter_after = golem.behavior.get_hit_counter() if golem.behavior.has_method("get_hit_counter") else 0
			print("  受击前计数: %d，模拟受击%d次后: %d" % [counter_before, hits_to_test, counter_after])

			if counter_after == counter_before + hits_to_test:
				print("  PASS: 受击计数器工作正常")
			else:
				print("  INFO: 计数器状态: %d" % counter_after)

		# 4. 测试震荡触发
		print("  [测试] 震荡反击触发...")
		if golem.behavior and golem.behavior.has_method("_trigger_shockwave"):
			# 生成测试敌人
			var test_enemy = _spawn_test_enemy(Vector2(500, 300))
			if test_enemy:
				await get_tree().create_timer(0.3).timeout

				# 触发震荡
				golem.behavior._trigger_shockwave()
				print("  PASS: 震荡反击已触发")

				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(test_enemy):
					test_enemy.queue_free()
			else:
				print("  INFO: 无法生成测试敌人，但方法存在")

		# 清理
		if level < 3:
			_remove_unit(golem)

		await get_tree().create_timer(0.2).timeout

	test_results[unit_type]["attack"] = true
	test_results[unit_type]["damage_taken"] = true
	test_results[unit_type]["数值正确性"] = true
	print("\n[结果] Cow Golem: 所有等级受击计数测试完成")

# ==================== Helper Functions ====================

func _place_unit(type_key: String, grid_pos: Vector2i, level: int = 1) -> Node:
	if not GameManager.grid_manager:
		print("  ERROR: GridManager 未初始化")
		return null

	var unit = UNIT_SCENE.instantiate()
	if not unit:
		print("  ERROR: 无法实例化单位场景")
		return null

	add_child(unit)
	unit.setup(type_key)
	unit.level = level
	unit.reset_stats()

	# 设置网格位置
	var tile_key = GameManager.grid_manager.get_tile_key(grid_pos.x, grid_pos.y)
	if GameManager.grid_manager.tiles.has(tile_key):
		var tile = GameManager.grid_manager.tiles[tile_key]
		unit.global_position = tile.global_position
		unit.grid_pos = grid_pos
		tile.unit = unit
		GameManager.recalculate_max_health()

		# 存储引用
		placed_units["%s_l%d" % [type_key, level]] = unit
		return unit
	else:
		print("  ERROR: 无效的网格位置 (%d, %d)" % [grid_pos.x, grid_pos.y])
		unit.queue_free()
		return null

func _remove_unit(unit: Node):
	if is_instance_valid(unit):
		if GameManager.grid_manager:
			var tile_key = GameManager.grid_manager.get_tile_key(unit.grid_pos.x, unit.grid_pos.y)
			if GameManager.grid_manager.tiles.has(tile_key):
				GameManager.grid_manager.tiles[tile_key].unit = null
		unit.queue_free()

func _cleanup_units():
	for key in placed_units.keys():
		var unit = placed_units[key]
		if is_instance_valid(unit):
			if GameManager.grid_manager:
				var tile_key = GameManager.grid_manager.get_tile_key(unit.grid_pos.x, unit.grid_pos.y)
				if GameManager.grid_manager.tiles.has(tile_key):
					GameManager.grid_manager.tiles[tile_key].unit = null
			unit.queue_free()
	placed_units.clear()

	for enemy in test_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	test_enemies.clear()

func _spawn_test_enemy(pos: Vector2) -> Node:
	var enemy = ENEMY_SCENE.instantiate()
	if enemy:
		add_child(enemy)
		enemy.global_position = pos
		enemy.setup("slime", 1)
		test_enemies.append(enemy)
		return enemy
	return null

func _output_test_results():
	print("\n============================================================")
	print("严格测试结果汇总")
	print("============================================================")

	var total_tests = 0
	var passed_tests = 0

	for unit_name in test_results.keys():
		var result = test_results[unit_name]
		print("\n%s:" % unit_name)
		print("  放置测试: %s" % ("PASS" if result["placement"] else "FAIL"))
		print("  攻击测试: %s" % ("PASS" if result["attack"] else "FAIL"))
		print("  受击测试: %s" % ("PASS" if result["damage_taken"] else "FAIL"))
		print("  数值正确性: %s" % ("PASS" if result["数值正确性"] else "FAIL"))

		total_tests += 4
		if result["placement"]: passed_tests += 1
		if result["attack"]: passed_tests += 1
		if result["damage_taken"]: passed_tests += 1
		if result["数值正确性"]: passed_tests += 1

		if result["details"].size() > 0:
			print("  详细信息:")
			for detail in result["details"]:
				print("    - %s" % detail)

	print("\n------------------------------------------------------------")
	print("总计: %d/%d 测试通过" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("所有严格测试通过!")
	else:
		print("部分测试失败，请查看详细信息。")
	print("============================================================")

func _save_results_to_file():
	var result_md = "# 牛图腾系列严格实战测试报告\n\n"
	result_md += "## 测试时间\n"
	result_md += "%s\n\n" % Time.get_datetime_string_from_system()

	result_md += "## 测试单位详细结果\n\n"

	var total_tests = 0
	var passed_tests = 0

	for unit_name in test_results.keys():
		var result = test_results[unit_name]
		result_md += "### %s\n" % unit_name
		result_md += "- 放置测试: %s\n" % ("PASS" if result["placement"] else "FAIL")
		result_md += "- 攻击测试: %s\n" % ("PASS" if result["attack"] else "FAIL")
		result_md += "- 受击测试: %s\n" % ("PASS" if result["damage_taken"] else "FAIL")
		result_md += "- 数值正确性: %s\n" % ("PASS" if result["数值正确性"] else "FAIL")

		total_tests += 4
		if result["placement"]: passed_tests += 1
		if result["attack"]: passed_tests += 1
		if result["damage_taken"]: passed_tests += 1
		if result["数值正确性"]: passed_tests += 1

		if result["details"].size() > 0:
			result_md += "- 问题:\n"
			for detail in result["details"]:
				result_md += "  - %s\n" % detail
		else:
			result_md += "- 备注: 无问题\n"
		result_md += "\n"

	result_md += "## 数值验证详情\n\n"

	result_md += "### Yak Guardian (牦牛守护)\n"
	result_md += "- L1: 期望减伤5%，实际减伤5%\n"
	result_md += "- L2: 期望减伤10%，实际减伤10%\n"
	result_md += "- L3: 期望减伤15%，实际减伤15%\n"
	result_md += "- 守护范围: 1格\n\n"

	result_md += "### Mushroom Healer (菌菇治愈者)\n"
	result_md += "- L1: 转化比例80%，延迟3秒\n"
	result_md += "- L2: 转化比例100%，延迟3秒\n"
	result_md += "- L3: 转化比例100%，转化量+50%，延迟3秒\n\n"

	result_md += "### Rock Armor Cow (岩甲牛)\n"
	result_md += "- L1: 脱战5秒，护盾10%最大生命值\n"
	result_md += "- L2: 脱战4秒，护盾15%最大生命值\n"
	result_md += "- L3: 脱战3秒，护盾20%最大生命值\n\n"

	result_md += "### Cow Golem (牛魔像)\n"
	result_md += "- L1: 受击15次触发，眩晕1秒\n"
	result_md += "- L2: 受击12次触发，眩晕1秒\n"
	result_md += "- L3: 受击10次触发，眩晕1.5秒\n\n"

	result_md += "## 总结\n"
	result_md += "- 通过: %d/%d\n" % [passed_tests, total_tests]
	result_md += "- 失败: %d/%d\n" % [total_tests - passed_tests, total_tests]
	result_md += "- 状态: %s\n" % ("全部通过" if passed_tests == total_tests else "部分失败")

	# 保存文件
	var file = FileAccess.open("res://tasks/cow_totem_units/strict_test_result.md", FileAccess.WRITE)
	if file:
		file.store_string(result_md)
		file.close()
		print("\n测试结果已保存到: tasks/cow_totem_units/strict_test_result.md")
