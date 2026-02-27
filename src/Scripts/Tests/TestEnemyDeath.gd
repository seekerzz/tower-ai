extends Node

# TestEnemyDeath - 测试敌人死亡时不会重复调用 die() 函数
# 这个测试验证以下修复：
# 1. die() 函数应该检查 is_dying 防止重复调用
# 2. die() 函数应该设置 is_dying = true

var test_passed: bool = true
var error_messages: Array = []

var initial_soul_count: int = 0
var death_call_count: int = 0
var enemies_killed: int = 0

func _ready():
	print("[TestEnemyDeath] 启动敌人死亡测试...")

	# 连接到相关信号
	if GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.disconnect(_on_enemy_died)
	GameManager.enemy_died.connect(_on_enemy_died)

	if SoulManager.soul_count_changed.is_connected(_on_soul_changed):
		SoulManager.soul_count_changed.disconnect(_on_soul_changed)
	SoulManager.soul_count_changed.connect(_on_soul_changed)

	initial_soul_count = SoulManager.current_souls
	print("[TestEnemyDeath] 初始魂魄数: ", initial_soul_count)

	# 延迟开始测试，让场景完全加载
	get_tree().create_timer(2.0).timeout.connect(_start_test)

func _start_test():
	print("[TestEnemyDeath] 开始测试...")

	# 创建一个测试敌人
	var enemy = _spawn_test_enemy()
	if not enemy:
		_error("无法创建测试敌人")
		return

	print("[TestEnemyDeath] 测试敌人创建成功，HP: ", enemy.hp)

	# 记录敌人的 instance_id 用于验证
	var enemy_id = enemy.get_instance_id()

	# 模拟多次伤害（模拟多颗子弹同时命中的情况）
	print("[TestEnemyDeath] 模拟多段伤害...")

	# 在同一帧内多次调用 take_damage，使 HP < 0
	# 这在实际游戏中可能发生：多颗子弹同时命中
	enemy.take_damage(50, null)  # 第一段伤害
	enemy.take_damage(50, null)  # 第二段伤害 - 此时 HP 可能已经 <= 0
	enemy.take_damage(50, null)  # 第三段伤害 - 可能触发重复的 die()

	# 等待一帧让信号处理
	await get_tree().process_frame

	# 验证结果
	_verify_test_results()

func _spawn_test_enemy():
	var enemy_scene = load("res://src/Scenes/Enemies/Enemy.tscn")
	if not enemy_scene:
		_error("无法加载敌人场景")
		return null

	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(200, 200)  # 放置在一个固定位置

	# 设置测试用的敌人数据
	enemy.setup("test_enemy", 1)
	enemy.hp = 100
	enemy.max_hp = 100

	# 连接到 die 信号来统计调用次数
	if enemy.died.is_connected(_on_enemy_die_signal):
		enemy.died.disconnect(_on_enemy_die_signal)
	enemy.died.connect(_on_enemy_die_signal)

	# 重写 die 函数来统计调用次数（测试用钩子）
	var original_die = Callable(enemy, "die")
	var die_call_count = 0

	var wrapped_die = func(killer_unit = null):
		die_call_count += 1
		print("[TestEnemyDeath] die() 被调用 #", die_call_count)
		if die_call_count > 1:
			_error("die() 被多次调用！这是重复调用的bug")
		return original_die.call(killer_unit)

	# 注意：由于 GDScript 的限制，我们不能直接替换函数
	# 所以我们使用信号来统计调用次数
	enemy.set_meta("die_call_count", 0)

	get_tree().current_scene.add_child(enemy)
	return enemy

func _on_enemy_die_signal():
	death_call_count += 1
	print("[TestEnemyDeath] died 信号触发 #", death_call_count)
	if death_call_count > 1:
		_error("died 信号被多次触发！die() 函数被重复调用")

func _on_enemy_died(enemy, killer_unit):
	enemies_killed += 1
	print("[TestEnemyDeath] enemy_died 信号触发，当前击杀数: ", enemies_killed)

func _on_soul_changed(new_count: int, delta: int):
	print("[TestEnemyDeath] 魂魄变化: ", delta, ", 新总数: ", new_count)

func _verify_test_results():
	print("\n[TestEnemyDeath] ========== 验证测试结果 ==========")

	# 验证1: died 信号只应该触发一次
	if death_call_count == 0:
		_error("died 信号没有被触发 - 敌人没有被正确击杀")
	elif death_call_count > 1:
		_error("died 信号被触发了 %d 次 - 存在重复调用bug!" % death_call_count)
	else:
		print("[TestEnemyDeath] ✓ died 信号正确触发1次")

	# 验证2: 魂魄只应该增加1次
	var soul_increase = SoulManager.current_souls - initial_soul_count
	if soul_increase == 0:
		_error("魂魄没有增加 - SoulManager.add_souls_from_enemy_death 没有被调用")
	elif soul_increase > 1:
		_error("魂魄增加了 %d 次 - _on_death() 被重复调用!" % soul_increase)
	else:
		print("[TestEnemyDeath] ✓ 魂魄正确增加1次")

	# 验证3: 击杀的敌人数量
	if enemies_killed == 0:
		_error("没有检测到敌人死亡")
	elif enemies_killed > 1:
		_error("检测到 %d 个敌人死亡 - 可能重复计算!" % enemies_killed)
	else:
		print("[TestEnemyDeath] ✓ 正确检测到1个敌人死亡")

	# 总结
	if test_passed:
		print("\n[TestEnemyDeath] ========== 测试通过 ✓ ==========")
	else:
		print("\n[TestEnemyDeath] ========== 测试失败 ✗ ==========")
		for msg in error_messages:
			print("  - ", msg)

	# 清理
	_cleanup()

func _error(msg: String):
	test_passed = false
	error_messages.append(msg)
	push_error("[TestEnemyDeath] " + msg)

func _cleanup():
	if GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.disconnect(_on_enemy_died)
	if SoulManager.soul_count_changed.is_connected(_on_soul_changed):
		SoulManager.soul_count_changed.disconnect(_on_soul_changed)

	print("[TestEnemyDeath] 测试完成，清理完成")
