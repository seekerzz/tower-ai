class_name WaveSystemManager
extends Node

## 波次系统管理器
## 负责波次状态管理、配置加载、敌人生成逻辑和波次事件发射

# ===== 信号定义 =====
signal wave_started(wave_number: int, wave_type: String, difficulty: float)
signal wave_ended(wave_number: int, stats: Dictionary)
signal elite_wave_started(wave_number: int)
signal boss_wave_started(wave_number: int, boss_count: int)
signal enemy_spawned(enemy: Node, wave_number: int)
signal batch_started(batch_index: int, total_batches: int)
signal all_enemies_spawned(wave_number: int)

# ===== 波次类型枚举 =====
enum WaveType {
	NORMAL,     # 普通波
	ELITE,      # 精英波（每5波）
	BOSS,       # Boss波（每10波）
	EVENT,      # 事件波（每3波）
	HEALER,     # 治疗者波（第3波教学）
	MUTANT      # 变异波（第2波）
}

# ===== 难度系数常量 =====
const DIFFICULTY_NORMAL = 1.0
const DIFFICULTY_ELITE = 1.5
const DIFFICULTY_BOSS = 2.0

# ===== 配置参数 =====
const BASE_ENEMY_COUNT = 20
const ENEMY_COUNT_PER_WAVE = 6
const BASE_BATCH_COUNT = 3
const BATCH_COUNT_PER_WAVE = 0.5  # 每2波增加1批次
const MAX_BATCH_SIZE = 20         # 单批次上限，避免卡顿
const MAX_CONCURRENT_ENEMIES = 50 # 同时存在敌人上限
const SPAWN_INTERVAL = 0.1        # 敌人生成间隔
const MIN_BATCH_DELAY = 2.0       # 最小批次间隔
const MAX_BATCH_DELAY = 4.0       # 最大批次间隔

# ===== 波次状态 =====
var current_wave: int = 1
var current_wave_type: WaveType = WaveType.NORMAL
var is_wave_active: bool = false
var difficulty_multiplier: float = 1.0

# ===== 生成状态 =====
var enemies_to_spawn: int = 0
var total_enemies_for_wave: int = 0
var spawned_enemies_count: int = 0
var defeated_enemies_count: int = 0
var current_batch: int = 0
var total_batches: int = 0

# ===== 配置数据 =====
var wave_config: Dictionary = {}
var enemy_variants: Dictionary = {}

# ===== 运行时统计 =====
var wave_stats: Dictionary = {
	"enemies_spawned": 0,
	"enemies_defeated": 0,
	"enemies_reached_core": 0,
	"total_damage_dealt": 0.0,
	"total_damage_taken": 0.0,
	"gold_earned": 0,
	"start_time": 0.0,
	"end_time": 0.0
}

# ===== 场景引用 =====
var enemy_scene: PackedScene = preload("res://src/Scenes/Game/Enemy.tscn")
var healer_script: Script = preload("res://src/Scripts/Enemies/HealerEnemy.gd")

# ===== 初始化 =====
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_wave_config()
	_load_enemy_variants()
	_connect_signals()

func _connect_signals():
	# 连接GameManager的信号
	if GameManager:
		GameManager.enemy_died.connect(_on_enemy_died)
		GameManager.enemy_hit.connect(_on_enemy_hit)

# ===== 配置加载 =====
func _load_wave_config():
	"""从JSON文件加载波次配置"""
	var config_path = "res://data/wave_config.json"
	var file = FileAccess.open(config_path, FileAccess.READ)

	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)

		if error == OK:
			wave_config = json.data
			print("[WaveSystemManager] Wave config loaded successfully")
		else:
			push_error("[WaveSystemManager] Failed to parse wave config: " + json.get_error_message())
			_use_default_config()
	else:
		push_warning("[WaveSystemManager] Wave config file not found, using defaults")
		_use_default_config()

func _use_default_config():
	"""使用内置默认配置"""
	wave_config = _generate_default_wave_config()

func _generate_default_wave_config() -> Dictionary:
	"""生成默认波次配置（1-20波）"""
	var config = {
		"waves": {},
		"enemy_types": ["slime", "mutant_slime", "crab", "wolf", "poison", "treant", "yeti", "golem"],
		"boss_types": ["summoner", "ranger", "tank"]
	}

	for wave in range(1, 21):
		var wave_data = _generate_wave_data(wave)
		config.waves[str(wave)] = wave_data

	return config

func _generate_wave_data(wave: int) -> Dictionary:
	"""生成单波配置数据"""
	var wave_type_str = _get_wave_type_string(wave)
	var difficulty = calculate_wave_difficulty(wave)

	var enemy_count = BASE_ENEMY_COUNT + floor(wave * ENEMY_COUNT_PER_WAVE)
	var batch_count = min(BASE_BATCH_COUNT + floor(wave * BATCH_COUNT_PER_WAVE), ceil(enemy_count / 5.0))
	var enemies_per_batch = ceil(float(enemy_count) / batch_count)

	# 限制单批次数量
	if enemies_per_batch > MAX_BATCH_SIZE:
		enemies_per_batch = MAX_BATCH_SIZE
		batch_count = ceil(float(enemy_count) / enemies_per_batch)

	var wave_data = {
		"wave_number": wave,
		"wave_type": wave_type_str,
		"difficulty": difficulty,
		"enemy_count": enemy_count,
		"batch_count": int(batch_count),
		"enemies_per_batch": int(enemies_per_batch),
		"batch_delay": max(MIN_BATCH_DELAY, MAX_BATCH_DELAY - (wave * 0.1)),
		"spawn_interval": SPAWN_INTERVAL,
		"enemy_types": _get_enemy_types_for_wave(wave),
		"is_elite": wave % 5 == 0 and wave % 10 != 0,
		"is_boss": wave % 10 == 0
	}

	# Boss波特殊配置
	if wave_data.is_boss:
		wave_data.boss_count = 2 if wave >= 10 else 1
		wave_data.enemy_count = wave_data.boss_count
		wave_data.batch_count = wave_data.boss_count
		wave_data.enemies_per_batch = 1

	return wave_data

func _load_enemy_variants():
	"""加载敌人类型数据"""
	if Constants.ENEMY_VARIANTS.size() > 0:
		enemy_variants = Constants.ENEMY_VARIANTS
	else:
		# 等待Constants加载完成
		await get_tree().process_frame
		enemy_variants = Constants.ENEMY_VARIANTS

# ===== 波次类型判断 =====
func get_wave_type(wave: int) -> WaveType:
	"""获取波次类型"""
	if wave % 10 == 0:
		return WaveType.BOSS
	elif wave % 5 == 0:
		return WaveType.ELITE
	elif wave == 3:
		return WaveType.HEALER
	elif wave == 2:
		return WaveType.MUTANT
	elif wave % 3 == 0:
		return WaveType.EVENT
	else:
		return WaveType.NORMAL

func _get_wave_type_string(wave: int) -> String:
	"""获取波次类型字符串"""
	var type = get_wave_type(wave)
	match type:
		WaveType.NORMAL: return "normal"
		WaveType.ELITE: return "elite"
		WaveType.BOSS: return "boss"
		WaveType.EVENT: return "event"
		WaveType.HEALER: return "healer"
		WaveType.MUTANT: return "mutant"
		_: return "normal"

func _get_enemy_types_for_wave(wave: int) -> Array:
	"""获取波次可用的敌人类型"""
	var available_types = ["slime"]  # 第1波只有史莱姆

	if wave >= 2:
		available_types.append_array(["mutant_slime", "crab"])
	if wave >= 3:
		available_types.append("healer")
	if wave >= 4:
		available_types.append("wolf")
	if wave >= 6:
		available_types.append("poison")
	if wave >= 7:
		available_types.append("treant")
	if wave >= 8:
		available_types.append("yeti")
	if wave >= 9:
		available_types.append("golem")

	# 根据波次类型返回特定组合
	var wave_type = get_wave_type(wave)
	match wave_type:
		WaveType.MUTANT:
			return ["mutant_slime", "crab"]
		WaveType.HEALER:
			return ["healer", "slime"]
		WaveType.EVENT:
			# 随机混合
			return available_types.slice(0, min(available_types.size(), 3))
		WaveType.BOSS:
			return ["boss"]
		_:
			# 普通波：根据进度解锁
			var idx = min(available_types.size() - 1, floor((wave - 1) / 2.0))
			return [available_types[int(idx)]]

# ===== 难度计算 =====
func calculate_wave_difficulty(wave: int) -> float:
	"""
	计算波次难度
	公式：波次基础难度 = 波次编号 × 1.15^波次编号 × 难度系数
	"""
	var base_difficulty = wave * pow(1.15, wave)
	var difficulty_coefficient = _get_difficulty_coefficient(wave)
	return base_difficulty * difficulty_coefficient * difficulty_multiplier

func _get_difficulty_coefficient(wave: int) -> float:
	"""获取难度系数"""
	var wave_type = get_wave_type(wave)
	match wave_type:
		WaveType.ELITE: return DIFFICULTY_ELITE
		WaveType.BOSS: return DIFFICULTY_BOSS
		_: return DIFFICULTY_NORMAL

func calculate_enemy_hp(wave: int, base_hp: float) -> float:
	"""计算敌人生命值"""
	return base_hp * (1.0 + (wave - 1) * 0.15)

func calculate_enemy_damage(wave: int, base_damage: float) -> float:
	"""计算敌人攻击力"""
	return base_damage * (1.0 + (wave - 1) * 0.12)

func calculate_enemy_speed(wave: int, base_speed: float) -> float:
	"""计算敌人移动速度"""
	return base_speed * (1.0 + (wave - 1) * 0.02)

# ===== 波次控制 =====
func start_wave(wave: int = -1) -> bool:
	"""开始新波次"""
	if is_wave_active:
		push_warning("[WaveSystemManager] Cannot start wave while another is active")
		return false

	if wave > 0:
		current_wave = wave

	current_wave_type = get_wave_type(current_wave)
	is_wave_active = true

	# 重置统计
	_reset_wave_stats()
	wave_stats.start_time = Time.get_ticks_msec() / 1000.0

	# 获取波次配置
	var wave_data = get_wave_config(current_wave)
	total_enemies_for_wave = wave_data.enemy_count
	enemies_to_spawn = total_enemies_for_wave
	spawned_enemies_count = 0
	defeated_enemies_count = 0
	current_batch = 0
	total_batches = wave_data.batch_count

	# 发射信号
	var difficulty = calculate_wave_difficulty(current_wave)
	wave_started.emit(current_wave, wave_data.wave_type, difficulty)

	# 发射特殊波次信号
	match current_wave_type:
		WaveType.ELITE:
			elite_wave_started.emit(current_wave)
		WaveType.BOSS:
			var boss_count = wave_data.get("boss_count", 1)
			boss_wave_started.emit(current_wave, boss_count)

	# 开始生成敌人
	_start_wave_spawning(wave_data)

	print("[WaveSystemManager] Wave %d started (Type: %s, Difficulty: %.2f)" % [
		current_wave, wave_data.wave_type, difficulty
	])

	return true

func _start_wave_spawning(wave_data: Dictionary):
	"""开始波次生成序列"""
	if current_wave_type == WaveType.BOSS:
		_spawn_boss_wave(wave_data)
	else:
		_spawn_normal_wave(wave_data)

func _spawn_normal_wave(wave_data: Dictionary):
	"""生成普通波次"""
	var batch_count = wave_data.batch_count
	var enemies_per_batch = wave_data.enemies_per_batch
	var batch_delay = wave_data.batch_delay

	_run_batch_sequence(batch_count, enemies_per_batch, batch_delay)

func _spawn_boss_wave(wave_data: Dictionary):
	"""生成Boss波次"""
	var boss_count = wave_data.get("boss_count", 2)
	var boss_types = wave_config.get("boss_types", ["summoner", "ranger", "tank"])

	# 打乱Boss类型
	boss_types = boss_types.duplicate()
	boss_types.shuffle()

	# 获取生成点
	var spawn_points = _get_spawn_points()
	if spawn_points.size() < 2:
		spawn_points = [Vector2(-300, 0), Vector2(300, 0)]

	# 排序生成点（左到右）
	spawn_points.sort_custom(func(a, b): return a.x < b.x)

	# 生成Boss
	for i in range(boss_count):
		var boss_type = boss_types[i % boss_types.size()]
		var spawn_pos = spawn_points[i % spawn_points.size()]

		if i > 0:
			await get_tree().create_timer(1.0).timeout

		_spawn_enemy_at_pos(spawn_pos, boss_type)
		enemies_to_spawn -= 1
		spawned_enemies_count += 1

	all_enemies_spawned.emit(current_wave)
	_start_win_check()

func _run_batch_sequence(batches_left: int, enemies_per_batch: int, batch_delay: float):
	"""运行批次序列"""
	if !is_wave_active or batches_left <= 0:
		return

	current_batch = total_batches - batches_left + 1
	batch_started.emit(current_batch, total_batches)

	# 确定本批次敌人类型
	var enemy_types = _get_enemy_types_for_wave(current_wave)
	var type_key = enemy_types.pick_random()

	# 特殊波次处理
	match current_wave_type:
		WaveType.MUTANT:
			# 30%概率生成螃蟹
			type_key = "crab" if randf() < 0.3 else "mutant_slime"
		WaveType.HEALER:
			# 混合治疗者和史莱姆
			type_key = "healer" if randf() < 0.4 else "slime"
		WaveType.EVENT:
			# 完全随机
			type_key = enemy_types.pick_random()

	# 生成批次
	await _spawn_batch(type_key, enemies_per_batch)

	# 调度下一批次
	if batches_left > 1:
		await get_tree().create_timer(batch_delay).timeout
		_run_batch_sequence(batches_left - 1, enemies_per_batch, batch_delay)
	else:
		# 最后一批生成完成
		all_enemies_spawned.emit(current_wave)
		_start_win_check()

func _spawn_batch(type_key: String, count: int):
	"""生成一批敌人"""
	var spawn_points = _get_spawn_points()
	if spawn_points.is_empty():
		spawn_points = [Vector2.ZERO]

	for i in range(count):
		if !is_wave_active:
			break
		if enemies_to_spawn <= 0:
			break

		# 检查并发敌人上限
		var current_enemies = get_tree().get_nodes_in_group("enemies").size()
		if current_enemies >= MAX_CONCURRENT_ENEMIES:
			# 等待直到敌人数量下降
			while get_tree().get_nodes_in_group("enemies").size() >= MAX_CONCURRENT_ENEMIES:
				await get_tree().create_timer(0.5).timeout
			if !is_wave_active:
				break

		var spawn_point = spawn_points.pick_random()
		var pos = spawn_point + Vector2(randf_range(-20, 20), randf_range(-20, 20))

		_spawn_enemy_at_pos(pos, type_key)

		enemies_to_spawn -= 1
		spawned_enemies_count += 1
		wave_stats.enemies_spawned += 1

		await get_tree().create_timer(SPAWN_INTERVAL).timeout

func _spawn_enemy_at_pos(pos: Vector2, type_key: String):
	"""在指定位置生成单个敌人"""
	if !enemy_scene:
		push_error("[WaveSystemManager] Enemy scene not loaded")
		return

	var enemy = enemy_scene.instantiate()

	# 特殊处理治疗者
	if type_key == "healer" and healer_script:
		enemy.set_script(healer_script)

	# 设置敌人数据
	enemy.setup(type_key, current_wave)
	enemy.global_position = pos

	# 应用难度缩放
	_apply_difficulty_scaling(enemy)

	# 添加到场景
	add_child(enemy)

	# 发射信号
	enemy_spawned.emit(enemy, current_wave)

	# 连接敌人死亡信号
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))

func _apply_difficulty_scaling(enemy: Node):
	"""应用难度缩放到敌人"""
	var difficulty = calculate_wave_difficulty(current_wave)
	var wave_type = get_wave_type(current_wave)

	# 根据波次类型应用额外加成
	match wave_type:
		WaveType.ELITE:
			if enemy.has_method("set_elite_modifiers"):
				enemy.set_elite_modifiers(1.3, 1.2)  # HP+30%, Speed+20%
		WaveType.BOSS:
			# Boss由BossBehavior处理
			pass

func _get_spawn_points() -> Array:
	"""获取敌人生成点"""
	if GameManager.grid_manager:
		return GameManager.grid_manager.get_spawn_points()
	return []

# ===== 胜利检测 =====
func _start_win_check():
	"""开始胜利条件检测"""
	while is_wave_active:
		var active_enemies = get_tree().get_nodes_in_group("enemies").size()

		if enemies_to_spawn <= 0 and active_enemies == 0:
			_end_wave()
			break

		await get_tree().create_timer(0.5).timeout

func _end_wave():
	"""结束当前波次"""
	if !is_wave_active:
		return

	is_wave_active = false
	wave_stats.end_time = Time.get_ticks_msec() / 1000.0

	var duration = wave_stats.end_time - wave_stats.start_time
	var stats = {
		"wave": current_wave,
		"duration": duration,
		"enemies_spawned": wave_stats.enemies_spawned,
		"enemies_defeated": wave_stats.enemies_defeated,
		"enemies_reached_core": wave_stats.enemies_reached_core,
		"total_damage_dealt": wave_stats.total_damage_dealt,
		"gold_earned": wave_stats.gold_earned
	}

	wave_ended.emit(current_wave, stats)

	print("[WaveSystemManager] Wave %d ended (Duration: %.2fs, Defeated: %d/%d)" % [
		current_wave, duration, wave_stats.enemies_defeated, wave_stats.enemies_spawned
	])

# ===== 事件处理 =====
func _on_enemy_died(enemy: Node = null, killer_unit = null):
	"""敌人死亡处理"""
	if !is_wave_active:
		return

	defeated_enemies_count += 1
	wave_stats.enemies_defeated += 1
	wave_stats.gold_earned += 1  # 基础金币奖励

func _on_enemy_hit(enemy: Node, source_unit, amount: float):
	"""敌人受伤处理"""
	if !is_wave_active:
		return

	wave_stats.total_damage_dealt += amount

# ===== 公共接口 =====
func get_wave_config(wave: int) -> Dictionary:
	"""获取指定波次的配置"""
	var key = str(wave)
	if wave_config.has("waves") and wave_config.waves.has(key):
		return wave_config.waves[key]

	# 动态生成配置
	return _generate_wave_data(wave)

func get_current_wave_config() -> Dictionary:
	"""获取当前波次配置"""
	return get_wave_config(current_wave)

func set_difficulty_multiplier(multiplier: float):
	"""设置难度倍数"""
	difficulty_multiplier = max(0.1, multiplier)

func get_wave_progress() -> Dictionary:
	"""获取当前波次进度"""
	var active_enemies = 0
	if is_inside_tree():
		active_enemies = get_tree().get_nodes_in_group("enemies").size()

	return {
		"wave": current_wave,
		"wave_type": _get_wave_type_string(current_wave),
		"is_active": is_wave_active,
		"enemies_remaining": enemies_to_spawn,
		"enemies_active": active_enemies,
		"enemies_defeated": defeated_enemies_count,
		"total_enemies": total_enemies_for_wave,
		"batch": current_batch,
		"total_batches": total_batches,
		"progress_percent": (float(defeated_enemies_count) / max(1, total_enemies_for_wave)) * 100.0
	}

func force_end_wave():
	"""强制结束当前波次"""
	_end_wave()

func reset():
	"""重置波次系统"""
	is_wave_active = false
	current_wave = 1
	enemies_to_spawn = 0
	spawned_enemies_count = 0
	defeated_enemies_count = 0
	_reset_wave_stats()

func _reset_wave_stats():
	"""重置波次统计"""
	wave_stats = {
		"enemies_spawned": 0,
		"enemies_defeated": 0,
		"enemies_reached_core": 0,
		"total_damage_dealt": 0.0,
		"total_damage_taken": 0.0,
		"gold_earned": 0,
		"start_time": 0.0,
		"end_time": 0.0
	}

# ===== 调试功能 =====
func skip_to_wave(wave: int):
	"""跳转到指定波次（调试用）"""
	current_wave = wave
	print("[WaveSystemManager] Skipped to wave %d" % wave)

func spawn_test_enemy(type_key: String = "slime"):
	"""生成测试敌人"""
	var spawn_points = _get_spawn_points()
	var pos = Vector2.ZERO if spawn_points.is_empty() else spawn_points[0]
	_spawn_enemy_at_pos(pos, type_key)
