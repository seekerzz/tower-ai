extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

# 可扩展性设计
@export var ORB_COUNT: int = 3

@export var ORBIT_RADIUS_TILES: int = 3
@export var ROTATION_SPEED: float = 2.0 # 弧度/秒
@export var ORB_DAMAGE: float = 20.0
@export var MANA_GAIN: float = 20.0
@export var REHIT_INTERVAL: float = 0.5

# 模拟 Unit 属性 (Duck Typing)
var behavior = self
var unit_data: Dictionary = {} # Projectile 可能会读取 unit_data

# 确保 behavior 指向自己，以便 Projectile 可以调用 on_projectile_hit
func _init():
	behavior = self
var crit_rate: float = 0.0
var crit_dmg: float = 1.5

var orbs: Array = []
var angle_offset: float = 0.0
var rehit_timer: float = 0.0

func _ready():
	# 尝试初始化，如果 CombatManager 还没准备好，稍后会在 on_wave_started 或 _process 中再次检查
	if GameManager.combat_manager:
		_spawn_orbs()

func on_wave_started(wave_number: int = 0, wave_type: String = "", difficulty: float = 1.0):
	if orbs.is_empty():
		_spawn_orbs()

func _process(delta):
	# 确保法球存在 (如果 CombatManager 初始化较晚)
	if orbs.is_empty() and GameManager.combat_manager:
		_spawn_orbs()

	if orbs.is_empty():
		return

	# 旋转逻辑
	angle_offset += ROTATION_SPEED * delta
	if angle_offset > TAU:
		angle_offset -= TAU

	var center = _get_core_position()
	var radius = ORBIT_RADIUS_TILES * Constants.TILE_SIZE

	for i in range(orbs.size()):
		var orb = orbs[i]
		if is_instance_valid(orb):
			var angle = (TAU / ORB_COUNT) * i + angle_offset
			var target_pos = center + Vector2(cos(angle), sin(angle)) * radius
			orb.global_position = target_pos
			orb.rotation = angle + PI/2 # 使法球朝向切线方向 (或者 outward: angle)

			# 保持存活
			orb.life = 9999.0
		else:
			# 如果法球意外销毁，标记需要重新生成?
			# 这里简单起见，如果发现无效，可以移除或重建。
			# 但数组遍历中移除比较麻烦，暂不处理，等待重置。
			pass

	# 重置点击列表逻辑
	rehit_timer -= delta
	if rehit_timer <= 0:
		rehit_timer = REHIT_INTERVAL
		_reset_orb_hits()

func _spawn_orbs():
	# 清理旧的 (如果有)
	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	orbs.clear()

	if !GameManager.combat_manager:
		return

	var center = _get_core_position()

	# 记录法球生成日志
	if AILogger:
		pass
		pass
		# 记录[ORB_GENERATE]法球生成日志 - 使用测试脚本可检测的格式
		AILogger.broadcast_log("事件", "[ORB_GENERATE] 蝴蝶图腾法球生成 | 数量: %d | 伤害: %.0f | 环绕半径: %d格" % [ORB_COUNT, ORB_DAMAGE, ORBIT_RADIUS_TILES])
		# 同时保留[TOTEM]格式日志用于兼容性
		AILogger.broadcast_log("事件", "[TOTEM] 蝴蝶图腾法球生成 | 数量: %d | 伤害: %.0f | 环绕半径: %d格" % [ORB_COUNT, ORB_DAMAGE, ORBIT_RADIUS_TILES])
		if AIManager:
			AIManager.broadcast_text("[ORB_GENERATE] 蝴蝶图腾法球生成 | 数量: %d | 伤害: %.0f" % [ORB_COUNT, ORB_DAMAGE])

	for i in range(ORB_COUNT):
		var angle = (TAU / ORB_COUNT) * i
		var pos = center + Vector2(cos(angle), sin(angle)) * (ORBIT_RADIUS_TILES * Constants.TILE_SIZE)

		var stats = {
			"damage": ORB_DAMAGE,
			"pierce": 9999,
			"life": 9999,
			"type": "orb",
			"proj_override": "orb"
		}

		var proj = GameManager.combat_manager.spawn_projectile(self, pos, null, stats)
		orbs.append(proj)

func _reset_orb_hits():
	for orb in orbs:
		if is_instance_valid(orb):
			orb.hit_list.clear()

func _get_core_position() -> Vector2:
	if GameManager.grid_manager:
		return GameManager.grid_manager.global_position
	return Vector2.ZERO

# Duck Typing: 被 Projectile 调用
func calculate_damage_against(_target):
	return ORB_DAMAGE

# 回蓝逻辑
func on_projectile_hit(target, damage, projectile):
	GameManager.add_resource("mana", MANA_GAIN)

	var pierce_count = 1
	if projectile and "hit_list" in projectile:
		pierce_count = projectile.hit_list.size()

	var target_id = target.name if target and "name" in target else "未知敌人"
	if target and "type_key" in target:
		target_id = target.type_key

	if AILogger:
		pass
		pass
		if target and "type_key" in target:
			pass
		# 记录[ORB_DAMAGE]法球伤害日志 - 使用测试脚本可检测的格式
		AILogger.broadcast_log("事件", "[ORB_DAMAGE] 蝴蝶法球伤害 | 目标: %s | 伤害: %.0f | 穿透: %d" % [target_id, damage, pierce_count])
		# 记录[MANA_RESTORE]法力回复日志 - 使用测试脚本可检测的格式
		AILogger.broadcast_log("事件", "[MANA_RESTORE] 蝴蝶法球法力回复 | 回复量: %.0f | 当前法力: %.0f/%.0f" % [MANA_GAIN, GameManager.mana, GameManager.max_mana])
		# 同时保留[TOTEM]格式日志用于兼容性
		AILogger.broadcast_log("事件", "[TOTEM] 蝴蝶法球伤害 | 目标: %s | 伤害: %.0f | 穿透: %d" % [target_id, damage, pierce_count])
		AILogger.broadcast_log("事件", "[TOTEM] 蝴蝶法球法力回复 | 回复量: %.0f | 当前法力: %.0f/%.0f" % [MANA_GAIN, GameManager.mana, GameManager.max_mana])
		if AIManager:
			AIManager.broadcast_text("[ORB_DAMAGE] 蝴蝶法球伤害 | 目标: %s | 伤害: %.0f" % [target_id, damage])
			AIManager.broadcast_text("[MANA_RESTORE] 蝴蝶法球法力回复 | 回复量: %.0f" % [MANA_GAIN])

	# Emit orb_hit signal for test logging
	if GameManager.has_signal("orb_hit"):
		GameManager.orb_hit.emit(target, damage, MANA_GAIN, self)
