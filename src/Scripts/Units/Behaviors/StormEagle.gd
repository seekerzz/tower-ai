extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Storm Eagle - 雷暴召唤
# 友方暴击时积累电荷，满N层召唤全场雷击

var charge_stacks: int = 0
var charges_needed: int = 5
var lightning_damage: float = 0.0
var can_crit: bool = false

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_setup():
	# 连接到GameManager的暴击信号
	if GameManager.has_signal("projectile_crit"):
		GameManager.projectile_crit.connect(_on_global_crit)
	_update_mechanics()

func _update_mechanics():
	var lvl_stats = unit.unit_data.get("levels", {}).get(str(unit.level), {})
	var mechanics = lvl_stats.get("mechanics", {})

	# 根据等级设置需要的电荷层数
	charges_needed = mechanics.get("charges_needed", 5)
	can_crit = mechanics.get("lightning_can_crit", false)

	# 雷击伤害基于单位攻击力
	lightning_damage = unit.stats.damage * 2.0

func on_stats_updated():
	_update_mechanics()

func _on_global_crit(source_unit, target, damage):
	# 只有友方单位暴击时才积累电荷
	if not is_instance_valid(source_unit): return
	if not source_unit.is_in_group("units"): return

	charge_stacks += 1

	# 显示电荷积累
	GameManager.spawn_floating_text(unit.global_position, "⚡%d/%d" % [charge_stacks, charges_needed], Color.YELLOW)

	# 达到所需层数，触发全场雷击
	if charge_stacks >= charges_needed:
		_trigger_lightning_storm()
		charge_stacks = 0

func _trigger_lightning_storm():
	# 获取所有敌人
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty(): return

	var total_dmg: float = 0.0

	# 对每个敌人降下雷击
	for enemy in enemies:
		if not is_instance_valid(enemy): continue

		# 创建闪电效果
		total_dmg += _spawn_lightning_on_enemy(enemy)

	# 显示雷暴特效文字
	GameManager.spawn_floating_text(unit.global_position, "THUNDER STORM!", Color.CYAN)

	if AILogger:
		var unit_name = unit.name if unit and "name" in unit else "未知"
		if unit and "type_key" in unit:
			unit_name = unit.type_key
		pass
		# 记录[SKILL]雷暴召唤技能日志
		AILogger.broadcast_log("事件", "[SKILL] 风暴鹰 %s 触发雷暴召唤 | 范围: 5格 | 影响敌人: %d个 | 总伤害: %.0f" % [unit_name, enemies.size(), total_dmg])
		if AIManager:
			AIManager.broadcast_text("[SKILL] 风暴鹰 %s 触发雷暴召唤 | 范围: 5格 | 影响敌人: %d个 | 总伤害: %.0f" % [unit_name, enemies.size(), total_dmg])

func _spawn_lightning_on_enemy(enemy: Node2D) -> float:
	if not is_instance_valid(enemy): return 0.0

	# 使用CombatManager的闪电攻击
	if GameManager.combat_manager:
		var start_pos = enemy.global_position + Vector2(0, -200)
		var dmg = lightning_damage

		# L3雷击可暴击
		if can_crit and randf() < unit.stats.crit_rate:
			dmg *= unit.stats.crit_dmg

		# 创建闪电弧效果
		var lightning_scene = load("res://src/Scenes/Game/LightningArc.tscn")
		if lightning_scene:
			var arc = lightning_scene.instantiate()
			unit.get_parent().add_child(arc)
			arc.setup(start_pos, enemy.global_position)

		# 造成伤害
		enemy.take_damage(dmg, unit, "lightning")
		return dmg

	return 0.0

func on_cleanup():
	# 断开信号连接
	if GameManager.has_signal("projectile_crit"):
		if GameManager.projectile_crit.is_connected(_on_global_crit):
			GameManager.projectile_crit.disconnect(_on_global_crit)
