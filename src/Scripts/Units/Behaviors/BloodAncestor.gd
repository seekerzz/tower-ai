extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 血祖 - 鲜血领域机制
# 场上每有1个受伤敌人，自身攻击+10%/15%/20%且吸血+20%(L3)

var current_bonus_damage: float = 0.0
var current_lifesteal: float = 0.0

func on_setup():
	super.on_setup()
	# 记录血祖单位激活日志
	if AILogger:
		var unit_name = unit.type_key if unit and "type_key" in unit else "血祖"
		AILogger.event("[SKILL] 血祖单位激活 | 单位: %s | 等级: %d" % [unit_name, unit.level])
		if AIManager:
			AIManager.broadcast_text("[SKILL] 血祖单位激活 | 单位: %s" % unit_name)

func on_stats_updated():
	_update_blood_domain_bonus()

func on_tick(delta: float):
	# 定期更新鲜血领域加成
	_update_blood_domain_bonus()

func _update_blood_domain_bonus():
	if not GameManager.combat_manager:
		return

	# 获取等级相关的加成参数
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var damage_per_enemy = mechanics.get("damage_per_injured_enemy", 0.1)  # 默认10%
	var lifesteal_bonus = mechanics.get("lifesteal_bonus", 0.0)  # L3时20%

	# 计算场上受伤敌人的数量
	var injured_count = _count_injured_enemies()

	# 计算加成
	var total_damage_bonus = 1.0 + (damage_per_enemy * injured_count)
	var total_lifesteal = lifesteal_bonus

	# 应用加成到单位
	if total_damage_bonus != current_bonus_damage or total_lifesteal != current_lifesteal:
		current_bonus_damage = total_damage_bonus
		current_lifesteal = total_lifesteal

		# 显示领域激活提示
		if injured_count > 0:
			var bonus_text = "+%d%%攻" % int((total_damage_bonus - 1.0) * 100)
			if total_lifesteal > 0:
				bonus_text += " +%d%%吸" % int(total_lifesteal * 100)

func _count_injured_enemies() -> int:
	var count = 0
	var enemies = GameManager.combat_manager.get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# 检查敌人是否受伤（生命值低于最大值）
		var stats = enemy.get_node("Stats")
		if stats.current_hp < stats.max_hp:
			count += 1

	return count

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	# 应用吸血效果（L3时）
	if current_lifesteal > 0:
		var heal_amt = damage * current_lifesteal
		if heal_amt > 0:
			GameManager.heal_core(heal_amt)
			GameManager.spawn_floating_text(unit.global_position, "+%d" % int(heal_amt), Color.GREEN)

	# 记录血祖鲜血领域日志
	if AILogger:
		var target_name = target.type_key if target.has("type_key") else str(target.get_instance_id())
		AILogger.event("[SKILL] 血祖鲜血领域攻击 | 目标: %s | 伤害: %.0f | 当前加成: %.0f%%" % [target_name, damage, (current_bonus_damage - 1.0) * 100])
		if AIManager:
			AIManager.broadcast_text("[SKILL] 血祖鲜血领域攻击 | 伤害: %.0f" % damage)

func calculate_modified_damage(base_damage: float) -> float:
	# 返回经过鲜血领域加成后的伤害
	return base_damage * current_bonus_damage
