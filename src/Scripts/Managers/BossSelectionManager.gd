class_name BossSelectionManager
extends Node

## Boss随机选择管理器
## 负责每局游戏从季节Boss池中随机选择Boss
## 使用游戏种子确保可重复性（挑战模式）

# ===== 季节Boss池配置 =====
## 每个季节3个Boss，每局随机选择1个
const SEASON_BOSS_POOLS = {
	"spring": ["spring_guardian", "thorn_queen", "spring_spirit"],
	"summer": ["summer_dragon", "magma_giant", "sun_cheetah"],
	"autumn": ["autumn_lord", "death_reaper", "withered_prophet"],
	"winter": ["winter_queen", "frost_troll", "snow_commander"]
}

## Boss显示名称映射
const BOSS_DISPLAY_NAMES = {
	"spring_guardian": "春之守护者",
	"thorn_queen": "荆棘女王",
	"spring_spirit": "春风之灵",
	"summer_dragon": "炎阳巨龙",
	"magma_giant": "熔岩巨人",
	"sun_cheetah": "烈日猎豹",
	"autumn_lord": "瘟疫领主",
	"death_reaper": "凋零死神",
	"withered_prophet": "枯萎先知",
	"winter_queen": "冬之女王",
	"frost_troll": "冰霜巨魔",
	"snow_commander": "雪原指挥官"
}

## Boss脚本路径映射
## 所有12个Boss已实现
const BOSS_SCRIPT_PATHS = {
	# 春季Boss
	"spring_guardian": "res://src/Scripts/Enemies/Bosses/SpringGuardian.gd",
	"thorn_queen": "res://src/Scripts/Enemies/Bosses/BossSpringThornQueen.gd",
	"spring_spirit": "res://src/Scripts/Enemies/Bosses/BossSpringBreezeSpirit.gd",
	# 夏季Boss
	"summer_dragon": "res://src/Scripts/Enemies/Bosses/SummerDragon.gd",
	"magma_giant": "res://src/Scripts/Enemies/Bosses/BossSummerMagmaColossus.gd",
	"sun_cheetah": "res://src/Scripts/Enemies/Bosses/BossSummerSunCheetah.gd",
	# 秋季Boss
	"autumn_lord": "res://src/Scripts/Enemies/Bosses/AutumnLord.gd",
	"death_reaper": "res://src/Scripts/Enemies/Bosses/BossAutumnDeathReaper.gd",
	"withered_prophet": "res://src/Scripts/Enemies/Bosses/BossAutumnWitheredProphet.gd",
	# 冬季Boss
	"winter_queen": "res://src/Scripts/Enemies/Bosses/WinterQueen.gd",
	"frost_troll": "res://src/Scripts/Enemies/Bosses/BossWinterFrostTroll.gd",
	"snow_commander": "res://src/Scripts/Enemies/Bosses/BossWinterSnowCommander.gd"
}

## 所有Boss已实现
const PENDING_BOSSES: Array = []

# ===== 运行时状态 =====
var selected_bosses: Dictionary = {}  # season -> selected_boss_type
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var is_initialized: bool = false

# ===== 信号 =====
signal boss_selected(season: String, boss_type: String, boss_name: String)
signal all_bosses_selected(selections: Dictionary)

# ===== 初始化 =====
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

## 初始化Boss选择系统
## @param seed_value: 随机种子，用于确保可重复性（挑战模式）
## @param force_selection: 强制选择指定Boss（测试用）
func initialize(seed_value: int = -1, force_selection: Dictionary = {}):
	if is_initialized:
		return

	# 设置随机种子
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	# 记录种子日志 - SEED-LOGGING-001
	_log_seed()

	# 清空之前的选择
	selected_bosses.clear()

	# 执行随机选择
	for season in SEASON_BOSS_POOLS.keys():
		var boss_type: String

		# 检查是否有强制选择
		if force_selection.has(season):
			boss_type = force_selection[season]
		else:
			# 从池中随机选择
			var pool = SEASON_BOSS_POOLS[season]
			boss_type = pool[rng.randi() % pool.size()]

		selected_bosses[season] = boss_type

		# 发射信号
		var boss_name = get_boss_display_name(boss_type)
		boss_selected.emit(season, boss_type, boss_name)

		# 记录日志
		_log_boss_selection(season, boss_type, boss_name)

	all_bosses_selected.emit(selected_bosses.duplicate())
	is_initialized = true

	_log_selection_summary()

## 获取指定季节选中的Boss类型
func get_season_boss(season: String) -> String:
	if selected_bosses.has(season):
		return selected_bosses[season]

	# 如果未初始化，返回默认Boss
	match season:
		"spring": return "spring_guardian"
		"summer": return "summer_dragon"
		"autumn": return "autumn_lord"
		"winter": return "winter_queen"
		_: return "boss"

## 获取指定季节选中的Boss类型（与设计文档一致的别名）
func get_boss_for_season(season: String) -> String:
	return get_season_boss(season)

## 根据波次获取选中的Boss类型
func get_boss_for_wave(wave: int) -> String:
	var season = _get_season_from_wave(wave)
	return get_season_boss(season)

## 获取Boss显示名称
func get_boss_display_name(boss_type: String) -> String:
	return BOSS_DISPLAY_NAMES.get(boss_type, boss_type)

## 获取Boss脚本路径
func get_boss_script_path(boss_type: String) -> String:
	return BOSS_SCRIPT_PATHS.get(boss_type, "")

## 检查Boss是否已实现
func is_boss_implemented(boss_type: String) -> bool:
	return BOSS_SCRIPT_PATHS.has(boss_type)

## 获取待实现的Boss列表
func get_pending_bosses() -> Array:
	return PENDING_BOSSES.duplicate()

## 获取季节Boss池
func get_season_boss_pool(season: String) -> Array:
	return SEASON_BOSS_POOLS.get(season, [])

## 获取所有选中Boss的摘要
func get_selection_summary() -> Dictionary:
	var summary = {}
	for season in selected_bosses.keys():
		var boss_type = selected_bosses[season]
		summary[season] = {
			"type": boss_type,
			"name": get_boss_display_name(boss_type),
			"implemented": is_boss_implemented(boss_type)
		}
	return summary

## 重新随机选择（用于新游戏）
func reroll_selections():
	is_initialized = false
	initialize()

## 重置选择状态
func reset():
	selected_bosses.clear()
	is_initialized = false

# ===== 内部辅助函数 =====
func _get_season_from_wave(wave: int) -> String:
	if wave >= 1 and wave <= 6:
		return "spring"
	elif wave >= 7 and wave <= 12:
		return "summer"
	elif wave >= 13 and wave <= 18:
		return "autumn"
	elif wave >= 19 and wave <= 24:
		return "winter"
	return "spring"

## 记录种子日志 - SEED-LOGGING-001
## 格式: [BOSS种子] 本局种子: xxx
func _log_seed():
	var seed_value = rng.seed
	var log_message = "[BOSS种子] 本局种子: %d" % seed_value

	# 通过AIManager广播 - 如果已就绪
	var ai_manager = get_node_or_null("/root/AIManager")
	if ai_manager and ai_manager.has_method("broadcast_text"):
		ai_manager.broadcast_text(log_message)

	# 通过AILogger记录 - 如果已就绪
	var ai_logger = get_node_or_null("/root/AILogger")
	if ai_logger and ai_logger.has_method("event"):
		ai_logger.event(log_message)

## 记录Boss选择日志
## 格式: [BOSS选择] 种子值 | 季节: xxx | 候选: [a, b, c] | 选中: xxx
func _log_boss_selection(season: String, boss_type: String, boss_name: String):
	var season_names = {
		"spring": "春之觉醒",
		"summer": "夏之炎阳",
		"autumn": "秋之凋零",
		"winter": "冬之严寒"
	}
	var season_cn = season_names.get(season, season)
	var pool = SEASON_BOSS_POOLS.get(season, [])

	# 安全地访问autoload单例
	var ai_logger = get_node_or_null("/root/AILogger")
	var ai_manager = get_node_or_null("/root/AIManager")

	if ai_logger:
		ai_logger.boss_selected(boss_name, season_cn, boss_type, pool)

	if ai_manager:
		ai_manager.broadcast_text("[BOSS选择] %sBoss: %s" % [season_cn, boss_name])

## 记录选择摘要
## 格式: [BOSS选择] 本局配置完成 | 种子: xxx | 春:xxx | 夏:xxx | 秋:xxx | 冬:xxx
func _log_selection_summary():
	var season_order = ["spring", "summer", "autumn", "winter"]
	var season_names = {
		"spring": "春季",
		"summer": "夏季",
		"autumn": "秋季",
		"winter": "冬季"
	}

	# 构建配置摘要
	var summary_parts = []
	for season in season_order:
		if selected_bosses.has(season):
			var boss_type = selected_bosses[season]
			var boss_name = get_boss_display_name(boss_type)
			summary_parts.append("%s:%s" % [season_names[season], boss_name])

	# 安全地访问autoload单例
	var ai_logger = get_node_or_null("/root/AILogger")
	if ai_logger:
		var summary_text = " | ".join(season_order.map(
			func(s): return "%s: %s" % [season_names[s], get_boss_display_name(selected_bosses[s])]
		))
		ai_logger.system_log("季节系统", "Boss配置完成", summary_text)
		ai_logger.event("[BOSS选择] 本局配置完成 | 种子:%d | %s" % [rng.seed, " | ".join(summary_parts)])
