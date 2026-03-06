extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 牛魔像 - 怒火中烧机制
# Lv.1: 每受击1次攻击力+3%（上限30%）
# Lv.2: 叠加上限提升至50%
# Lv.3: 受击时20%概率给敌人叠加瘟疫易伤Debuff

var current_attack_bonus: int = 0      # 当前攻击加成百分比
var max_attack_bonus: int = 30         # 最大攻击加成（Lv.1:30%, Lv.2:50%）
var bonus_per_hit: int = 3             # 每次受击加成（%）
var vulnerable_chance: float = 0.0     # Lv.3时20%概率施加易伤

# 记录基础攻击力，用于计算加成后的伤害
var base_damage: float = 0.0

func on_setup():
	# 保存基础攻击力
	base_damage = unit.stats.damage if unit else 0.0
	# 根据等级初始化机制参数
	_update_mechanics()

func _update_mechanics():
	if not unit:
		return

	var level = unit.level

	# 根据等级设置参数
	match level:
		1:
			max_attack_bonus = 30
			vulnerable_chance = 0.0
		2:
			max_attack_bonus = 50
			vulnerable_chance = 0.0
		3:
			max_attack_bonus = 50
			vulnerable_chance = 0.2  # 20%概率

	# 确保当前加成不超过新上限
	if current_attack_bonus > max_attack_bonus:
		current_attack_bonus = max_attack_bonus
		_update_attack_damage()

func on_damage_taken(amount: float, source: Node2D) -> float:
	# 怒火中烧：每次受击增加攻击力
	if current_attack_bonus < max_attack_bonus:
		current_attack_bonus = min(current_attack_bonus + bonus_per_hit, max_attack_bonus)
		_update_attack_damage()

		# 日志输出 [COW_GOLEM] 怒火中烧触发
		print("[COW_GOLEM] 怒火中烧触发，当前攻击力+%d%% (%d/%d)" % [current_attack_bonus, current_attack_bonus, max_attack_bonus])

		# 显示视觉反馈
		if unit:
			GameManager.spawn_floating_text(unit.global_position, "怒火中烧! +%d%%" % current_attack_bonus, Color.ORANGE_RED)

	# Lv.3: 充能震荡 - 20%概率给攻击者叠加瘟疫易伤
	if unit and unit.level >= 3 and vulnerable_chance > 0:
		if randf() < vulnerable_chance:
			_apply_vulnerable_debuff(source)

	return amount

func _update_attack_damage():
	"""根据当前加成更新单位攻击力"""
	if not unit:
		return

	# 重新获取基础攻击力（以防reset_stats被调用）
	var stats = {}
	if unit.unit_data.has("levels") and unit.unit_data["levels"].has(str(unit.level)):
		stats = unit.unit_data["levels"][str(unit.level)]
	else:
		stats = unit.unit_data

	base_damage = stats.get("damage", unit.unit_data.get("damage", 0))

	# 计算加成后的伤害
	var bonus_multiplier = 1.0 + (current_attack_bonus / 100.0)
	unit.stats.damage = base_damage * bonus_multiplier

func _apply_vulnerable_debuff(attacker: Node2D):
	"""给攻击者叠加瘟疫易伤Debuff"""
	if not is_instance_valid(attacker):
		return

	# 检查攻击者是否有apply_debuff方法
	if attacker.has_method("apply_debuff"):
		attacker.apply_debuff("vulnerable", 1)

		# 日志输出
		print("[COW_GOLEM] 充能震荡触发，对 %s 施加瘟疫易伤" % attacker.name)

		# 显示视觉反馈
		GameManager.spawn_floating_text(attacker.global_position, "瘟疫易伤!", Color.PURPLE)
	elif attacker.has_method("apply_status"):
		# 备选：使用status效果系统
		var vulnerable_params = {
			"duration": 5.0,
			"stacks": 1,
			"source": unit
		}
		# 尝试加载易伤效果脚本
		var vulnerable_script = load("res://src/Scripts/Effects/VulnerableEffect.gd") if ResourceLoader.exists("res://src/Scripts/Effects/VulnerableEffect.gd") else null
		if vulnerable_script:
			attacker.apply_status(vulnerable_script, vulnerable_params)

			# 日志输出
			print("[COW_GOLEM] 充能震荡触发，对 %s 施加瘟疫易伤" % attacker.name)

			# 显示视觉反馈
			GameManager.spawn_floating_text(attacker.global_position, "瘟疫易伤!", Color.PURPLE)

func on_stats_updated():
	# 当单位升级或属性更新时，重新读取机制参数
	_update_mechanics()

func on_attack(target: Node2D) -> float:
	"""攻击时返回加成后的伤害"""
	if not is_instance_valid(target):
		return unit.stats.damage if unit else 0.0

	# 如果有怒火中烧加成，显示特效
	if current_attack_bonus > 0:
		unit.spawn_buff_effect("🔥")

	return unit.stats.damage if unit else 0.0

# 获取当前攻击加成百分比（用于UI显示）
func get_current_attack_bonus() -> int:
	return current_attack_bonus

# 获取最大攻击加成百分比（用于UI显示）
func get_max_attack_bonus() -> int:
	return max_attack_bonus
