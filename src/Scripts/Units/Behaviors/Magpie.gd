extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Magpie - 喜鹊
# 攻击概率偷取敌人属性
# Lv3偷取成功给核心回复HP或金币

enum StealType { ATTACK_SPEED, MOVE_SPEED, DEFENSE }

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if not target.is_in_group("enemies"): return

	var chance = 0.15 if unit.level < 3 else 0.25
	if randf() >= chance:
		return

	var steal_type = randi() % 3
	var steal_amount = 0.0

	match steal_type:
		StealType.ATTACK_SPEED: steal_amount = 0.03
		StealType.MOVE_SPEED: steal_amount = 0.08
		StealType.DEFENSE: steal_amount = 0.03

	if unit.level >= 2:
		steal_amount *= 1.5

	_apply_steal_effect(steal_type, steal_amount)

func _apply_steal_effect(type: int, amount: float):
	var targets = [unit]
	if unit.level >= 3:
		targets.append_array(unit._get_neighbor_units())

	for t in targets:
		if not is_instance_valid(t): continue
		match type:
			StealType.ATTACK_SPEED:
				if t.has_method("add_stat_bonus"):
					t.add_stat_bonus("attack_speed", amount)
			StealType.DEFENSE:
				if t.has_method("add_stat_bonus"):
					t.add_stat_bonus("defense", amount)
			StealType.MOVE_SPEED:
				if t.has_method("add_stat_bonus"):
					t.add_stat_bonus("move_speed", amount)

		# Visual feedback
		var txt = ""
		match type:
			StealType.ATTACK_SPEED: txt = "+ASPD"
			StealType.DEFENSE: txt = "+DEF"
			StealType.MOVE_SPEED: txt = "+SPD"
		GameManager.spawn_floating_text(t.global_position, txt, Color.GREEN)

	if unit.level >= 3:
		_apply_bonus_on_steal()

func _apply_bonus_on_steal():
	if randf() < 0.5:
		GameManager.heal_core(10)
		GameManager.spawn_floating_text(unit.global_position, "+10 HP", Color.GREEN)
	else:
		GameManager.add_gold(10)
		GameManager.spawn_floating_text(unit.global_position, "+10 G", Color.YELLOW)
