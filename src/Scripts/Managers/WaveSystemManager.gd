class_name WaveSystemManager
extends Node

## 波次系统管理器
## 负责波次状态管理、配置加载、敌人生成逻辑和波次事件发射

# ===== 信号定义 =====
signal wave_started(wave_number: int, wave_type: String, difficulty: float)
signal wave_ended(wave_number: int, stats: Dictionary)
signal elite_wave_started(wave_number: int)
signal boss_wave_started(wave_number: int, boss_count: int)
signal season_boss_started(wave_number: int, season: String, boss_name: String)
signal enemy_spawned(enemy: Node, wave_number: int)
signal batch_started(batch_index: int, total_batches: int)
signal all_enemies_spawned(wave_number: int)
signal season_changed(new_season: Season, season_name: String)
signal secondary_totem_selection_requested()  # 第1个Boss击败后请求次级图腾选择
signal third_totem_selection_requested()  # 第2个Boss击败后请求第三图腾选择

# ===== 季节枚举 =====
enum Season {
	SPRING,     # 春 - 波次 1-6
	SUMMER,     # 夏 - 波次 7-12
	AUTUMN,     # 秋 - 波次 13-18
	WINTER      # 冬 - 波次 19-24
}

# ===== 季节名称映射 =====
const SEASON_NAMES = {
	Season.SPRING: "春之觉醒",
	Season.SUMMER: "夏之炎阳",
	Season.AUTUMN: "秋之凋零",
	Season.WINTER: "冬之严寒"
}

# ===== 波次类型枚举 =====
enum WaveType {
	NORMAL,       # 普通波
	ELITE,        # 精英波（每5波）
	BOSS,         # Boss波（每10波）
	EVENT,        # 事件波（每3波）
	HEALER,       # 治疗者波（第3波教学）
	MUTANT,       # 变异波（第2波）
	SEASON_BOSS   # 季节Boss波（第6,12,18,24波）
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
var current_season: Season = Season.SPRING
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

# ===== Boss选择管理器 =====
var boss_selection_manager: Node = null
var BossSelectionManagerScript: Script = preload("res://src/Scripts/Managers/BossSelectionManager.gd")

# ===== 初始化 =====
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_wave_config()
	_load_enemy_variants()
	_init_boss_selection_manager()
	_connect_signals()

func _connect_signals():
	# 连接GameManager的信号
	if GameManager:
		GameManager.enemy_died.connect(_on_enemy_died)
		GameManager.enemy_hit.connect(_on_enemy_hit)

func _init_boss_selection_manager():
	"""初始化Boss选择管理器"""
	if BossSelectionManagerScript:
		boss_selection_manager = BossSelectionManagerScript.new()
		boss_selection_manager.name = "BossSelectionManager"
		add_child(boss_selection_manager)

	# 从GameManager获取游戏种子（如果有）
	var seed_value = -1
	if GameManager.session_data and GameManager.session_data.has("game_seed"):
		seed_value = GameManager.session_data.game_seed

	# 初始化Boss选择
	boss_selection_manager.initialize(seed_value)

	# 连接信号
	boss_selection_manager.boss_selected.connect(_on_boss_selected)

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

	var wave_type = get_wave_type(wave)
	var wave_data = {
		"wave_number": wave,
		"wave_type": wave_type_str,
		"difficulty": difficulty,
		"enemy_count": enemy_count,
		"batch_count": int(batch_count),
		"enemies_per_batch": int(enemies_per_batch),
		"batch_delay": max(MIN_BATCH_DELAY, MAX_BATCH_DELAY - (wave * 0.1)),
		"spawn_interval": SPAWN_INTERVAL,
		"enemy_types": get_season_enemy_pool(wave),
		"is_elite": wave_type == WaveType.ELITE,
		"is_boss": wave_type == WaveType.BOSS or wave_type == WaveType.SEASON_BOSS
	}

	# 季节Boss波特殊配置
	if wave_type == WaveType.SEASON_BOSS:
		wave_data.boss_count = 1
		wave_data.enemy_count = 1
		wave_data.batch_count = 1
		wave_data.enemies_per_batch = 1
		wave_data.season = _get_season_string(wave)
	# 普通Boss波特殊配置
	elif wave_type == WaveType.BOSS:
		wave_data.boss_count = 2 if wave >= 10 else 1
		wave_data.enemy_count = wave_data.boss_count
		wave_data.batch_count = wave_data.boss_count
		wave_data.enemies_per_batch = 1

	return wave_data

func _get_season_string(wave: int) -> String:
	"""获取季节字符串"""
	match get_season(wave):
		Season.SPRING: return "spring"
		Season.SUMMER: return "summer"
		Season.AUTUMN: return "autumn"
		Season.WINTER: return "winter"
		_: return "spring"

func _load_enemy_variants():
	"""加载敌人类型数据"""
	if Constants.ENEMY_VARIANTS.size() > 0:
		enemy_variants = Constants.ENEMY_VARIANTS
	else:
		# 等待Constants加载完成
		await get_tree().process_frame
		enemy_variants = Constants.ENEMY_VARIANTS

# ===== 季节系统 =====
func get_season(wave: int) -> Season:
	"""根据波次获取季节"""
	if wave >= 1 and wave <= 6:
		return Season.SPRING
	elif wave >= 7 and wave <= 12:
		return Season.SUMMER
	elif wave >= 13 and wave <= 18:
		return Season.AUTUMN
	elif wave >= 19 and wave <= 24:
		return Season.WINTER
	return Season.SPRING

func get_season_name(wave: int) -> String:
	"""获取季节名称"""
	return SEASON_NAMES[get_season(wave)]

func get_season_enemy_pool(wave: int) -> Array:
	"""获取当前季节的敌人池"""
	var season = get_season(wave)
	var config = wave_config.get("seasons", {})
	match season:
		Season.SPRING:
			return config.get("spring", {}).get("enemy_pool", ["slime", "mutant_slime", "healer", "wolf"])
		Season.SUMMER:
			return config.get("summer", {}).get("enemy_pool", ["crab", "wolf", "poison", "mutant_slime"])
		Season.AUTUMN:
			return config.get("autumn", {}).get("enemy_pool", ["treant", "poison", "wolf", "golem"])
		Season.WINTER:
			return config.get("winter", {}).get("enemy_pool", ["yeti", "golem", "treant", "healer"])
	return ["slime"]

func get_season_boss_type(wave: int) -> String:
	"""获取季节Boss类型

	使用Boss选择管理器获取随机选择的Boss
	"""
	# 如果有Boss选择管理器，使用它的选择
	if boss_selection_manager and boss_selection_manager.is_initialized:
		return boss_selection_manager.get_boss_for_wave(wave)

	# 回退到默认逻辑
	var season = get_season(wave)
	match season:
		Season.SPRING:
			return "spring_guardian"
		Season.SUMMER:
			return "summer_dragon"
		Season.AUTUMN:
			return "autumn_lord"
		Season.WINTER:
			return "winter_queen"
	return "boss"

func _on_boss_selected(season: String, boss_type: String, boss_name: String):
	"""Boss选择回调"""
	print("[WaveSystemManager] Boss selected for %s: %s (%s)" % [season, boss_name, boss_type])

func _check_season_change(wave: int):
	"""检查是否需要触发季节切换信号"""
	var new_season = get_season(wave)
	if new_season != current_season:
		var old_season_name = SEASON_NAMES[current_season]
		current_season = new_season
		var season_name = SEASON_NAMES[new_season]
		season_changed.emit(new_season, season_name)
		print("[WAVE_SYSTEM] 季节切换: %s" % season_name)

		# SEASON-VERIFY-001: 添加季节切换日志
		if AILogger:
			AILogger.system_log("季节系统", "季节切换", "%s → %s | 波次: %d" % [old_season_name, season_name, wave])
		if AIManager:
			AIManager.broadcast_text("【季节系统】季节切换: %s → %s | 当前波次: %d" % [old_season_name, season_name, wave])

# ===== 波次类型判断 =====
func get_wave_type(wave: int) -> WaveType:
	"""获取波次类型

	优先从wave_config.json配置中读取wave_type，如果没有配置则使用硬编码逻辑
	"""
	# 首先尝试从配置文件中读取wave_type
	var key = str(wave)
	if wave_config.has("waves") and wave_config.waves.has(key):
		var wave_data = wave_config.waves[key]
		if wave_data.has("wave_type"):
			var config_type = wave_data.wave_type
			match config_type:
				"normal":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: NORMAL" % wave)
					return WaveType.NORMAL
				"elite":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: ELITE" % wave)
					return WaveType.ELITE
				"boss":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: BOSS" % wave)
					return WaveType.BOSS
				"event":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: EVENT" % wave)
					return WaveType.EVENT
				"healer":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: HEALER" % wave)
					return WaveType.HEALER
				"mutant":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: MUTANT" % wave)
					return WaveType.MUTANT
				"season_boss":
					print("[WaveSystemManager] 波次 %d 类型从配置读取: SEASON_BOSS" % wave)
					return WaveType.SEASON_BOSS
				_:
					print("[WaveSystemManager] 波次 %d 配置类型 '%s' 未匹配，使用硬编码逻辑" % [wave, config_type])
		else:
			print("[WaveSystemManager] 波次 %d 配置中没有 wave_type 字段，使用硬编码逻辑" % wave)
	else:
		print("[WaveSystemManager] 波次 %d 配置未找到 (waves.has('%s')=%s)，使用硬编码逻辑" % [wave, key, str(wave_config.has("waves") and wave_config.waves.has(key))])

	# 配置中没有或无效，回退到硬编码逻辑
	# 季节Boss波 (6, 12, 18, 24)
	if wave in [6, 12, 18, 24]:
		print("[WaveSystemManager] 波次 %d 使用硬编码: SEASON_BOSS" % wave)
		return WaveType.SEASON_BOSS
	elif wave % 10 == 0:
		print("[WaveSystemManager] 波次 %d 使用硬编码: BOSS" % wave)
		return WaveType.BOSS
	elif wave % 5 == 0:
		print("[WaveSystemManager] 波次 %d 使用硬编码: ELITE" % wave)
		return WaveType.ELITE
	elif wave == 3:
		print("[WaveSystemManager] 波次 %d 使用硬编码: HEALER" % wave)
		return WaveType.HEALER
	elif wave == 2:
		print("[WaveSystemManager] 波次 %d 使用硬编码: MUTANT" % wave)
		return WaveType.MUTANT
	elif wave % 3 == 0:
		print("[WaveSystemManager] 波次 %d 使用硬编码: EVENT" % wave)
		return WaveType.EVENT
	else:
		print("[WaveSystemManager] 波次 %d 使用硬编码: NORMAL" % wave)
		return WaveType.NORMAL

func _get_wave_type_string(wave: int) -> String:
	"""获取波次类型字符串"""
	var type = get_wave_type(wave)
	match type:
		WaveType.NORMAL: return "normal"
		WaveType.ELITE: return "elite"
		WaveType.BOSS: return "boss"
		WaveType.SEASON_BOSS: return "season_boss"
		WaveType.EVENT: return "event"
		WaveType.HEALER: return "healer"
		WaveType.MUTANT: return "mutant"
		_: return "normal"

func _get_enemy_types_for_wave(wave: int) -> Array:
	"""获取波次可用的敌人类型

	优先从wave_config.json配置中读取enemy_types，如果没有配置则使用默认逻辑
	"""
	# 首先尝试从配置文件中读取enemy_types
	var key = str(wave)
	if wave_config.has("waves") and wave_config.waves.has(key):
		var wave_data = wave_config.waves[key]
		if wave_data.has("enemy_types") and wave_data.enemy_types.size() > 0:
			print("[WaveSystemManager] 波次 %d 敌人类型从配置读取: %s" % [wave, str(wave_data.enemy_types)])
			return wave_data.enemy_types.duplicate()
		else:
			print("[WaveSystemManager] 波次 %d 配置中没有 enemy_types 字段" % wave)
	else:
		print("[WaveSystemManager] 波次 %d 配置未找到，使用默认逻辑" % wave)

	# 配置中没有，使用默认解锁逻辑
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

	# 根据波次类型返回特定组合（仅在配置未指定时使用）
	var wave_type = get_wave_type(wave)
	match wave_type:
		WaveType.MUTANT:
			print("[WaveSystemManager] 波次 %d 使用MUTANT默认敌人类型: [mutant_slime, crab]" % wave)
			return ["mutant_slime", "crab"]
		WaveType.HEALER:
			print("[WaveSystemManager] 波次 %d 使用HEALER默认敌人类型: [healer, slime]" % wave)
			return ["healer", "slime"]
		WaveType.EVENT:
			# 随机混合
			print("[WaveSystemManager] 波次 %d 使用EVENT默认敌人类型" % wave)
			return available_types.slice(0, min(available_types.size(), 3))
		WaveType.BOSS:
			print("[WaveSystemManager] 波次 %d 使用BOSS默认敌人类型: [boss]" % wave)
			return ["boss"]
		_:
			# 普通波：根据进度解锁
			var idx = min(available_types.size() - 1, floor((wave - 1) / 2.0))
			print("[WaveSystemManager] 波次 %d 使用默认解锁逻辑敌人类型: [%s]" % [wave, available_types[int(idx)]])
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

	# 检查季节切换
	_check_season_change(current_wave)

	current_wave_type = get_wave_type(current_wave)
	is_wave_active = true

	# 同步到 SessionData (Source of Truth)
	if GameManager.session_data:
		GameManager.session_data.wave = current_wave
		GameManager.session_data.is_wave_active = true

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

	# 先生成第一批敌人（无时序延迟），确保信号发射时场上已有敌人
	# 这修复了CRASH-002：避免单位/图腾在wave_started信号后获取空敌人列表
	_spawn_first_batch_immediate(wave_data)

	# 发射信号（此时场上已有敌人）
	var difficulty = calculate_wave_difficulty(current_wave)
	wave_started.emit(current_wave, wave_data.wave_type, difficulty)

	# 发射特殊波次信号
	match current_wave_type:
		WaveType.ELITE:
			elite_wave_started.emit(current_wave)
		WaveType.BOSS:
			var boss_count = wave_data.get("boss_count", 1)
			boss_wave_started.emit(current_wave, boss_count)
		WaveType.SEASON_BOSS:
			var season_name = SEASON_NAMES[current_season]
			var boss_type = get_season_boss_type(current_wave)
			season_boss_started.emit(current_wave, season_name, boss_type)
			boss_wave_started.emit(current_wave, 1)
			# [BOSS选择] 日志埋点: Boss出场
			if AILogger:
				AILogger.system_log("季节系统", "季节Boss生成", "%s | 类型: %s | 波次: %d" % [season_name, boss_type, current_wave])
				AILogger.event("[BOSS选择] Boss出场 | 波次:%d | 季节:%s | Boss:%s" % [current_wave, season_name, boss_type])
			if AIManager:
				AIManager.broadcast_text("[BOSS选择] %s - %s 登场！| 波次: %d" % [season_name, boss_type, current_wave])

	# 继续生成剩余敌人
	_start_wave_spawning(wave_data)

	var season_str = SEASON_NAMES[current_season]
	print("[Wave_SYSTEM] Wave %d started | Type: %s | Season: %s | Difficulty: %.2f" % [
		current_wave, wave_data.wave_type, season_str, difficulty
	])

	return true

func _log_wave_start(wave: int, wave_type: WaveType, difficulty: float):
	"""记录波次开始日志"""
	var type_str = _get_wave_type_string(wave)
	var season_str = SEASON_NAMES[get_season(wave)]
	print("[WAVE_SYSTEM] Wave %d started | Type: %s | Season: %s | Difficulty: %.2f" % [
		wave, type_str, season_str, difficulty
	])

func _spawn_first_batch_immediate(wave_data: Dictionary):
	"""立即生成第一批敌人（无时序延迟）

	修复CRASH-002: 确保wave_started信号发射时场上已有敌人，
	避免单位/图腾获取空敌人列表导致空指针异常
	"""
	# 获取敌人类型
	var enemy_types = _get_enemy_types_for_wave(current_wave)
	var type_key = enemy_types.pick_random()
	print("[WaveSystemManager] 第一批敌人类型: %s (从 %s 中选择)" % [type_key, str(enemy_types)])

	if current_wave_type == WaveType.BOSS or current_wave_type == WaveType.SEASON_BOSS:
		# Boss波：立即生成第一个Boss
		var boss_count = wave_data.get("boss_count", 1)
		var spawn_points = _get_spawn_points()
		if spawn_points.size() < 2:
			spawn_points = [Vector2(-300, 0), Vector2(300, 0)]
		spawn_points.sort_custom(func(a, b): return a.x < b.x)

		# 只生成第一个Boss，不等待
		if boss_count > 0:
			var boss_type: String
			if current_wave_type == WaveType.SEASON_BOSS:
				# 季节Boss：使用对应季节的Boss类型
				boss_type = get_season_boss_type(current_wave)
			else:
				# 普通Boss波：从Boss类型列表中随机选择
				var boss_types = wave_config.get("boss_types", ["summoner", "ranger", "tank"])
				boss_types = boss_types.duplicate()
				boss_types.shuffle()
				boss_type = boss_types[0]
			var spawn_pos = spawn_points[0]
			_spawn_enemy_at_pos(spawn_pos, boss_type)
			enemies_to_spawn -= 1
			spawned_enemies_count += 1
	else:
		# 普通波（包括 HEALER、NORMAL、ELITE、EVENT、MUTANT 等）：立即生成第一批敌人
		# 注意：敌人类型选择逻辑已移至 _get_enemy_types_for_wave 函数
		# 这里不再根据 current_wave_type 强制覆盖，确保配置文件的 enemy_types 生效

		# WAVE-FIX: 计算实际的第一批大小
		# 需要生成 enemies_per_batch 个，或者如果剩余不足则生成全部剩余
		var first_batch_size = min(wave_data.enemies_per_batch, enemies_to_spawn)
		print("[WaveSystemManager] 立即生成第一批 %d 个敌人 (剩余需生成: %d)" % [first_batch_size, enemies_to_spawn])
		for i in range(first_batch_size):
			_spawn_single_enemy(type_key)

		# 如果只有一批敌人，立即启动胜利检查
		if wave_data.batch_count <= 1:
			print("[WaveSystemManager] 只有一批敌人，立即启动胜利检查")
			_start_win_check()

func _spawn_single_enemy(type_key: String):
	"""生成单个敌人（同步，不等待）"""
	if !is_wave_active or enemies_to_spawn <= 0:
		return

	var spawn_points = _get_spawn_points()
	if spawn_points.is_empty():
		spawn_points = [Vector2.ZERO]

	var spawn_pos = spawn_points[randi() % spawn_points.size()]

	# 添加随机偏移
	spawn_pos += Vector2(randf_range(-50, 50), randf_range(-50, 50))

	_spawn_enemy_at_pos(spawn_pos, type_key)
	enemies_to_spawn -= 1
	spawned_enemies_count += 1

func _start_wave_spawning(wave_data: Dictionary):
	"""开始波次生成序列（剩余敌人）"""
	if current_wave_type == WaveType.BOSS or current_wave_type == WaveType.SEASON_BOSS:
		# Boss波：生成剩余的Boss（第一个已在immediate中生成）
		var boss_count = wave_data.get("boss_count", 1)
		if boss_count > 1:
			_spawn_remaining_bosses(wave_data, boss_count - 1)
	else:
		# 普通波：生成剩余批次（第一批已在immediate中生成）
		_spawn_remaining_batches(wave_data)

func _spawn_remaining_bosses(wave_data: Dictionary, remaining: int):
	"""生成剩余的Boss"""
	var spawn_points = _get_spawn_points()
	if spawn_points.size() < 2:
		spawn_points = [Vector2(-300, 0), Vector2(300, 0)]
	spawn_points.sort_custom(func(a, b): return a.x < b.x)

	# 季节Boss波：使用季节Boss类型（理论上remaining应为0，因为季节Boss只有1个）
	if current_wave_type == WaveType.SEASON_BOSS:
		for i in range(remaining):
			var boss_type = get_season_boss_type(current_wave)
			var spawn_pos = spawn_points[(i + 1) % spawn_points.size()]
			await get_tree().create_timer(1.0).timeout
			_spawn_enemy_at_pos(spawn_pos, boss_type)
			enemies_to_spawn -= 1
			spawned_enemies_count += 1
	else:
		# 普通Boss波：从Boss类型列表中随机选择
		var boss_types = wave_config.get("boss_types", ["summoner", "ranger", "tank"])
		boss_types = boss_types.duplicate()
		boss_types.shuffle()

		for i in range(remaining):
			var boss_type = boss_types[(i + 1) % boss_types.size()]
			var spawn_pos = spawn_points[(i + 1) % spawn_points.size()]
			await get_tree().create_timer(1.0).timeout
			_spawn_enemy_at_pos(spawn_pos, boss_type)
			enemies_to_spawn -= 1
			spawned_enemies_count += 1

func _spawn_remaining_batches(wave_data: Dictionary):
	"""生成剩余的批次（第一批已生成）"""
	var batch_count = wave_data.batch_count
	var enemies_per_batch = wave_data.enemies_per_batch
	var batch_delay = wave_data.batch_delay

	# 第一批已生成，从第二批开始
	if batch_count > 1:
		_run_batch_sequence(batch_count - 1, enemies_per_batch, batch_delay, 2)
	else:
		# 只有一批敌人，立即启动胜利检查
		print("[WaveSystemManager] 只有一批敌人，立即启动胜利检查")
		_start_win_check()

func _spawn_normal_wave(wave_data: Dictionary):
	"""生成普通波次"""
	var batch_count = wave_data.batch_count
	var enemies_per_batch = wave_data.enemies_per_batch
	var batch_delay = wave_data.batch_delay

	_run_batch_sequence(batch_count, enemies_per_batch, batch_delay)

func _spawn_boss_wave(wave_data: Dictionary):
	"""生成Boss波次"""
	var boss_count = wave_data.get("boss_count", 2)
	var boss_types = []

	# 季节Boss波使用BossSelectionManager的选择
	if current_wave_type == WaveType.SEASON_BOSS:
		var season_boss = get_season_boss_type(current_wave)
		boss_types = [season_boss]
		boss_count = 1
		print("[WaveSystemManager] 生成季节Boss: %s (波次 %d)" % [season_boss, current_wave])
	else:
		# 普通Boss波使用配置中的boss_types
		boss_types = wave_config.get("boss_types", ["summoner", "ranger", "tank"])
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

func _run_batch_sequence(batches_left: int, enemies_per_batch: int, batch_delay: float, start_from_batch: int = 1):
	"""运行批次序列

	Args:
		batches_left: 剩余批次数量
		enemies_per_batch: 每批次敌人数量
		batch_delay: 批次间隔
		start_from_batch: 从第几批开始（默认1，用于跳过已生成的第一批）
	"""
	if !is_wave_active or batches_left <= 0:
		return

	# 计算当前批次号（考虑起始偏移）
	if start_from_batch > 1:
		current_batch = start_from_batch - 1 + (total_batches - batches_left - start_from_batch + 2)
	else:
		current_batch = total_batches - batches_left + 1
	batch_started.emit(current_batch, total_batches)

	# 确定本批次敌人类型
	var enemy_types = _get_enemy_types_for_wave(current_wave)
	var type_key = enemy_types.pick_random()
	print("[WaveSystemManager] 批次 %d 敌人类型: %s (从 %s 中选择)" % [current_batch, type_key, str(enemy_types)])

	# 注意：敌人类型选择逻辑已移至 _get_enemy_types_for_wave 函数
	# 这里不再根据 current_wave_type 强制覆盖，确保配置文件的 enemy_types 生效

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

	# 应用难度缩放
	_apply_difficulty_scaling(enemy)

	# 添加到场景（必须先添加到场景树，再设置全局位置，避免Transform问题）
	add_child(enemy)
	enemy.global_position = pos

	# 发射信号
	enemy_spawned.emit(enemy, current_wave)

	# 连接敌人死亡信号
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))

	# [敌人生成] 日志埋点: 确保测试脚本能够检测到敌人的生成
	print("[ENEMY_SPAWNED] 敌人生成 | 类型: %s | 位置: (%.0f, %.0f) | 波次: %d" % [type_key, pos.x, pos.y, current_wave])

	# [BOSS生成] 日志埋点: 记录Boss生成
	if current_wave_type == WaveType.SEASON_BOSS or current_wave_type == WaveType.BOSS:
		var boss_name = type_key
		# 安全获取HP，避免属性不存在导致崩溃
		var boss_hp = 0
		if "hp" in enemy:
			boss_hp = enemy.get_node("Stats").current_hp
		elif "health" in enemy:
			boss_hp = enemy.health
		# 确保 [BOSS生成] 日志总是被记录
		if AILogger:
			AILogger.boss_spawned(boss_name, 1, boss_hp)
		if AIManager:
			AIManager.broadcast_text("[BOSS生成] %s 降临！波次:%d" % [boss_name, current_wave])
	else:
		# 普通敌人通过AILogger记录生成日志
		if AILogger:
			AILogger.enemy_spawned(current_wave, type_key, enemy.get_node("Stats").current_hp if "hp" in enemy else 0, pos)

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
		var points = GameManager.grid_manager.get_spawn_points()
		if not points.is_empty():
			return points

	# 当无法获取正常的生成点时，返回默认的边缘位置
	# 这样可以确保敌人不会在核心位置(0,0)周围生成
	print("[WaveSystemManager] WARNING: Using fallback spawn points!")
	return [
		Vector2(-300, -200), Vector2(300, -200),
		Vector2(-300, 200), Vector2(300, 200)
	]

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

	# 同步到 SessionData (Source of Truth)
	if GameManager.session_data:
		GameManager.session_data.is_wave_active = false

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

	# 检查是否需要触发次级图腾选择（第1个Boss击败后，即第6波结束）
	if current_wave == 6:
		if GameManager.session_data and not GameManager.session_data.has_secondary_totem:
			print("[WaveSystemManager] 第6波结束，触发次级图腾选择")
			secondary_totem_selection_requested.emit()
			if AIManager:
				AIManager.broadcast_text("【次级图腾】第1个Boss已被击败！请打开次级图腾选择界面。")

	# 检查是否需要触发第三图腾选择（第2个Boss击败后，即第12波结束）
	if current_wave == 12:
		if GameManager.session_data and GameManager.session_data.has_secondary_totem and not GameManager.session_data.has_third_totem:
			print("[WaveSystemManager] 第12波结束，触发第三图腾选择")
			third_totem_selection_requested.emit()
			if AIManager:
				AIManager.broadcast_text("【第三图腾】第2个Boss已被击败！请打开第三图腾选择界面。")

	# 波次结束，递增波次号
	current_wave += 1

	# 同步到 SessionData (Source of Truth)
	if GameManager.session_data:
		GameManager.session_data.wave = current_wave

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

	# 同步到 SessionData (Source of Truth)
	if GameManager.session_data:
		GameManager.session_data.wave = 1
		GameManager.session_data.is_wave_active = false

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
	# 确保波次状态一致
	is_wave_active = false
	current_wave = wave
	enemies_to_spawn = 0
	spawned_enemies_count = 0
	defeated_enemies_count = 0
	current_batch = 0
	total_batches = 0
	_reset_wave_stats()

	# 检查季节切换
	_check_season_change(current_wave)

	# 更新波次类型
	current_wave_type = get_wave_type(current_wave)

	# 重置波次统计
	wave_stats = {
		"enemies_spawned": 0,
		"enemies_defeated": 0,
		"damage_dealt": 0,
		"wave_time": 0
	}

	# 同步到 SessionData (Source of Truth)
	if GameManager.session_data:
		GameManager.session_data.wave = wave
		GameManager.session_data.is_wave_active = false

	print("[WaveSystemManager] Skipped to wave %d (Type: %s, Season: %s)" % [
		wave, _get_wave_type_string(wave), SEASON_NAMES[current_season]
	])

func spawn_test_enemy(type_key: String = "slime"):
	"""生成测试敌人"""
	var spawn_points = _get_spawn_points()
	var pos = Vector2.ZERO if spawn_points.is_empty() else spawn_points[0]

	# 确保波次状态为激活，以便敌人能够被正确生成和管理
	if !is_wave_active:
		is_wave_active = true
		print("[WaveSystemManager] 波次状态已激活，以便生成测试敌人")

	_spawn_enemy_at_pos(pos, type_key)
