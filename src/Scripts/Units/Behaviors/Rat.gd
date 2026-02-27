extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Rat - 老鼠
# 机制: 瘟疫传播 - 攻击使敌人中毒，中毒敌人死亡时传播毒素
# L1: 传播2层中毒
# L2: 传播4层中毒
# L3: 额外传播随机Debuff (burn, bleed, slow)

var plague_duration: float = 4.0

func on_setup():
	if not GameManager.debuff_applied.is_connected(_on_debuff_applied):
		GameManager.debuff_applied.connect(_on_debuff_applied)

func on_cleanup():
	if GameManager.debuff_applied.is_connected(_on_debuff_applied):
		GameManager.debuff_applied.disconnect(_on_debuff_applied)

func _on_debuff_applied(enemy, debuff_type: String, stacks: int):
	# Check if the debuff is poison
	if debuff_type == "poison":
		enemy.set_meta("plague_infected", true)
		enemy.set_meta("plague_duration", plague_duration)

		# Connect to death signal if not already connected
		if enemy.has_signal("died") and not enemy.is_connected("died", _on_plagued_enemy_died):
			enemy.died.connect(_on_plagued_enemy_died.bind(enemy))

func _on_plagued_enemy_died(enemy):
	if not is_instance_valid(enemy):
		return

	if not enemy.has_meta("plague_infected"):
		return

	var level = unit.level
	var spread_stacks = 2 if level < 2 else 4
	var nearby = _get_enemies_in_radius(enemy.global_position, 120.0)

	for e in nearby:
		if e == enemy: continue

		if e.has_method("add_poison_stacks"):
			e.add_poison_stacks(spread_stacks)

		if level >= 3:
			_spread_additional_debuff(e)

func _spread_additional_debuff(enemy):
	var debuffs = ["burn", "bleed", "slow"]
	var random_debuff = debuffs.pick_random()

	if random_debuff == "burn":
		enemy.apply_status(load("res://src/Scripts/Effects/BurnEffect.gd"), {"duration": 5.0, "damage": 10.0, "stacks": 1})
	elif random_debuff == "bleed":
		# Bleed usually handled by stacks logic in Enemy.gd
		if enemy.has_method("add_bleed_stacks"):
			enemy.add_bleed_stacks(1, unit)
		else:
			enemy.apply_status(load("res://src/Scripts/Effects/BleedEffect.gd"), {"duration": 5.0, "stack_count": 1, "source": unit})
	elif random_debuff == "slow":
		enemy.apply_status(load("res://src/Scripts/Effects/SlowEffect.gd"), {"duration": 3.0, "slow_factor": 0.5})

func _get_enemies_in_radius(pos: Vector2, radius: float) -> Array:
	var result = []
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) <= radius:
			result.append(enemy)
	return result
