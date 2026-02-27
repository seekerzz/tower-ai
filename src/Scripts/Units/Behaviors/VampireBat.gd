extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# 吸血蝠 - 鲜血狂噬机制
# 生命值越低，吸血比例越高

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	# 获取核心当前生命值比例
	var hp_percent = GameManager.core_health / GameManager.max_core_health if GameManager.max_core_health > 0 else 1.0

	# 从mechanics获取等级相关的吸血加成
	var mechanics = unit.unit_data.get("levels", {}).get(str(unit.level), {}).get("mechanics", {})
	var base_lifesteal = mechanics.get("base_lifesteal", 0.0)
	var low_hp_bonus = mechanics.get("low_hp_bonus", 0.0)

	# 计算吸血比例：生命值越低，吸血越高
	# 基础吸血 + 根据生命损失比例的额外吸血
	var lifesteal_pct = base_lifesteal
	if low_hp_bonus > 0:
		# 当生命值为0时获得最大加成，生命值为100%时获得0加成
		var missing_hp_percent = 1.0 - hp_percent
		lifesteal_pct += low_hp_bonus * missing_hp_percent

	var heal_amt = damage * lifesteal_pct
	if heal_amt > 0:
		GameManager.damage_core(-heal_amt)
		GameManager.spawn_floating_text(unit.global_position, "+%d" % int(heal_amt), Color.GREEN)
