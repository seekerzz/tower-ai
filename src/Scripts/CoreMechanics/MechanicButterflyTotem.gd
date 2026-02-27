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
var crit_rate: float = 0.0
var crit_dmg: float = 1.5

var orbs: Array = []
var angle_offset: float = 0.0
var rehit_timer: float = 0.0

func _ready():
	# 尝试初始化，如果 CombatManager 还没准备好，稍后会在 on_wave_started 或 _process 中再次检查
	if GameManager.combat_manager:
		_spawn_orbs()

func on_wave_started():
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
	# Emit orb_hit signal for test logging
	if GameManager.has_signal("orb_hit"):
		GameManager.orb_hit.emit(target, damage, MANA_GAIN, self)
