extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

const PoisonEffect = preload("res://src/Scripts/Effects/PoisonEffect.gd")
const StatusEffect = preload("res://src/Scripts/Effects/StatusEffect.gd")

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	# 检查目标是否有效
	if !is_instance_valid(target) or target.is_queued_for_deletion():
		return

	# 确保目标有必要的接口
	if not target.has_method("die") or not target.has_method("apply_status"):
		return

	# 1. 获取当前攻击目标的 Debuff总层数
	var debuff_stacks = 0
	for child in target.get_children():
		# 使用 is 判断类型，这里StatusEffect是预加载的脚本资源
		if child is StatusEffect:
			debuff_stacks += child.stacks

	# 2. 判断斩杀
	# 阈值 = Debuff总层数 * 3
	var threshold = debuff_stacks * 3

	# 检查生命值是否低于阈值
	# 注意：此时 damage 已经造成，target.hp 是扣除伤害后的值
	if target.hp < threshold:
		# Execute!
		if GameManager.has_method("spawn_floating_text"):
			GameManager.spawn_floating_text(target.global_position, "Execute!", Color.RED)
		target.die(unit)
	else:
		# 3. 常规攻击：施加中毒
		# 如果未触发斩杀，则给目标施加1层中毒效果
		# 使用本次攻击的伤害作为中毒的基础伤害
		var poison_params = {
			"duration": 5.0,
			"damage": damage,
			"stacks": 1,
			"source": unit
		}
		target.apply_status(PoisonEffect, poison_params)
