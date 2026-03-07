extends "res://src/Scripts/Enemies/Behaviors/BossBehavior.gd"

## 荆棘女王 - 春季Boss B
## 主题：荆棘、控制、自然防御

# 技能配置
const SKILL_THORN_TRAP = "thorn_trap"           # 荆棘丛生(陷阱)
const SKILL_VINE_BIND = "vine_bind"             # 藤蔓缠绕(控制)
const SKILL_SPIKE_BURST = "spike_burst"         # 尖刺爆发
const SKILL_NATURE_SHELTER = "nature_shelter"   # 自然庇护

# 技能参数
var thorn_trap_count: int = 3
var thorn_trap_damage: float = 25.0
var vine_bind_duration: float = 2.0
var spike_burst_damage: float = 60.0
var nature_shelter_heal: float = 80.0
var nature_shelter_defense: float = 0.5  # 50%减伤

# 陷阱管理
var active_traps: Array = []

func _ready():
	# 注册技能CD
	register_skill(SKILL_THORN_TRAP, 10.0)      # 10秒CD
	register_skill(SKILL_VINE_BIND, 12.0)       # 12秒CD
	register_skill(SKILL_SPIKE_BURST, 8.0)      # 8秒CD
	register_skill(SKILL_NATURE_SHELTER, 15.0)  # 15秒CD

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	# 设置Boss元数据
	enemy_data["boss_name"] = "ThornQueen"
	enemy_data["boss_title"] = "荆棘女王"
	enemy_data["max_phase"] = 2
	enemy_data["phase_hp_thresholds"] = [0.5]  # 50%血量进入第二阶段

	super.init(enemy_node, enemy_data)

## 阶段变化回调
func on_phase_changed(old_phase: int, new_phase: int):
	match new_phase:
		2:
			# 第二阶段：增强控制能力
			thorn_trap_count = 5
			vine_bind_duration = 3.0
			spike_burst_damage = 90.0
			nature_shelter_heal = 120.0
			_log_boss_skill("自然觉醒", "自身", "进入强化形态")

## 重写技能执行
func perform_boss_skill(skill_name: String):
	match skill_name:
		SKILL_THORN_TRAP:
			perform_skill_thorn_trap()
		SKILL_VINE_BIND:
			perform_skill_vine_bind()
		SKILL_SPIKE_BURST:
			perform_skill_spike_burst()
		SKILL_NATURE_SHELTER:
			perform_skill_nature_shelter()
		_:
			super.perform_boss_skill(skill_name)

## 荆棘丛生 - 放置荆棘陷阱
func perform_skill_thorn_trap():
	_log_boss_skill("荆棘丛生", "战场", "放置%d个陷阱" % thorn_trap_count)

	GameManager.spawn_floating_text(enemy.global_position, "🌿 荆棘丛生!", Color.GREEN)

	# 在核心周围放置陷阱（通过召唤毒怪模拟陷阱效果）
	if GameManager.combat_manager and GameManager.core:
		for i in range(thorn_trap_count):
			var angle = (TAU / thorn_trap_count) * i + randf_range(-0.3, 0.3)
			var distance = randf_range(80, 150)
			var offset = Vector2(cos(angle), sin(angle)) * distance
			var trap_pos = GameManager.core.global_position + offset
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos", trap_pos, "poison")

	set_skill_cooldown(SKILL_THORN_TRAP)

## 藤蔓缠绕 - 控制效果：缠绕2个防御塔4秒
func perform_skill_vine_bind():
	_log_boss_skill("藤蔓缠绕", "防御塔", "缠绕2个防御塔%.1f秒" % vine_bind_duration)

	GameManager.spawn_floating_text(enemy.global_position, "🌿 藤蔓缠绕!", Color.DARK_GREEN)

	# 对核心造成伤害
	if GameManager.core:
		GameManager.core.take_damage(spike_burst_damage * 0.5, "荆棘女王-藤蔓缠绕")

	# 眩晕2个随机防御塔
	_stun_random_towers(2, vine_bind_duration)

	set_skill_cooldown(SKILL_VINE_BIND)

## 眩晕指定数量的随机防御塔
func _stun_random_towers(count: int, duration: float):
	if not GameManager.grid_manager:
		return

	# 获取所有部署的防御塔
	var deployed_units = []
	for pos in GameManager.grid_manager.units.keys():
		var unit = GameManager.grid_manager.units[pos]
		if is_instance_valid(unit) and not unit.get_meta("is_stunned", false):
			deployed_units.append(unit)

	# 随机选择指定数量的防御塔进行眩晕
	deployed_units.shuffle()
	var stun_count = min(count, deployed_units.size())

	for i in range(stun_count):
		var target_unit = deployed_units[i]
		_apply_stun_effect(target_unit, duration)

	if stun_count > 0:
		_log_boss_skill("藤蔓缠绕", "防御塔", "成功眩晕%d个防御塔" % stun_count)

## 应用眩晕效果
func _apply_stun_effect(target_unit: Node, duration: float):
	# 创建眩晕效果
	var stun_effect = preload("res://src/Scripts/Effects/StunEffect.gd").new(duration)
	stun_effect.setup(target_unit, self, {"duration": duration})
	target_unit.add_child(stun_effect)

	GameManager.spawn_floating_text(target_unit.global_position, "💫 眩晕!", Color.YELLOW)

## 尖刺爆发 - AOE伤害
func perform_skill_spike_burst():
	_log_boss_skill("尖刺爆发", "全屏", "造成%.0f伤害" % spike_burst_damage)

	GameManager.spawn_floating_text(enemy.global_position, "💥 尖刺爆发!", Color.YELLOW_GREEN)

	# 对核心造成AOE伤害
	if GameManager.core:
		GameManager.core.take_damage(spike_burst_damage, "荆棘女王-尖刺爆发")

	# 召唤尖刺小怪
	if GameManager.combat_manager:
		for i in range(2):
			var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			GameManager.combat_manager.call_deferred("_spawn_enemy_at_pos",
				enemy.global_position + offset, "slime")

	set_skill_cooldown(SKILL_SPIKE_BURST)

## 自然庇护 - 防御+恢复
func perform_skill_nature_shelter():
	_log_boss_skill("自然庇护", "自身", "恢复%.0f HP" % nature_shelter_heal)

	GameManager.spawn_floating_text(enemy.global_position, "🛡️ 自然庇护!", Color.LIGHT_GREEN)

	# 恢复生命
	if enemy:
		enemy.get_node("Stats").current_hp = min(enemy.get_node("Stats").current_hp + nature_shelter_heal, enemy.get_node("Stats").max_hp)
		GameManager.spawn_floating_text(enemy.global_position + Vector2(0, -30),
			"+%.0f" % nature_shelter_heal, Color.GREEN)

	set_skill_cooldown(SKILL_NATURE_SHELTER)

## 重写physics_process以自动释放技能
func physics_process(delta: float) -> bool:
	# 调用父类更新CD和阶段检查
	var handled = super.physics_process(delta)
	if handled:
		return true

	# 自动释放可用技能（按优先级）
	if is_skill_ready(SKILL_NATURE_SHELTER) and enemy and enemy.get_node("Stats").current_hp < enemy.get_node("Stats").max_hp * 0.5:
		perform_skill_nature_shelter()
	elif is_skill_ready(SKILL_SPIKE_BURST):
		perform_skill_spike_burst()
	elif is_skill_ready(SKILL_THORN_TRAP):
		perform_skill_thorn_trap()
	elif is_skill_ready(SKILL_VINE_BIND):
		perform_skill_vine_bind()

	return false
