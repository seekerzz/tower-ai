extends "res://src/Scripts/Units/UnitBehavior.gd"

# Woodpecker - 啄木鸟
# 对同一目标连续攻击伤害增加
# Lv3: 叠满层数进入钻头大师模式（必定暴击，攻速增加）

var drill_target: WeakRef = null
var drill_stacks: int = 0
var max_drill_stacks: int = 8

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_combat_tick(delta: float) -> bool:
	if unit.cooldown > 0:
		unit.cooldown -= delta
		return true

	if not GameManager.combat_manager: return true

	var target = null
	# Stick to current target if valid and in range
	if drill_target and drill_target.get_ref() and is_instance_valid(drill_target.get_ref()) and drill_target.get_ref().hp > 0:
		if drill_target.get_ref().global_position.distance_to(unit.global_position) <= unit.range_val:
			target = drill_target.get_ref()

	if not target:
		target = GameManager.combat_manager.find_nearest_enemy(unit.global_position, unit.range_val)
		# New target found (or null), so logic below handles stack reset

	if target:
		var prev_target = drill_target.get_ref() if drill_target else null
		if target != prev_target:
			drill_stacks = 0 # Reset stack on switch
			drill_target = weakref(target)
		else:
			drill_stacks = min(drill_stacks + 1, max_drill_stacks)

		_perform_attack(target)
	else:
		if drill_stacks > 0:
			drill_stacks = 0
			drill_target = null

	return true

func _perform_attack(target):
	var bonus = 1.0 + (drill_stacks * 0.08)
	var final_damage = unit.damage * bonus

	if unit.level >= 3 and drill_stacks >= max_drill_stacks:
		_enter_drill_master_mode()

	var stats = { "damage": final_damage }
	if unit.guaranteed_crit_stacks > 0:
		stats["is_critical"] = true
		unit.guaranteed_crit_stacks -= 1

	GameManager.combat_manager.spawn_projectile(unit, unit.global_position, target, stats)

	unit.cooldown = unit.atk_speed
	if unit.has_method("play_attack_anim"):
		unit.play_attack_anim("ranged", target.global_position)

func _enter_drill_master_mode():
	# prevent multiple triggers if already fast?
	# Actually stacks stay at max, so it triggers every shot at max stack.
	# But atk_speed modification stacks? Yes.
	# We should only trigger if not already in mode?
	# Or the snippet implies it triggers ONCE when reaching max?
	# "if level >= 3 and drill_stacks >= max_drill_stacks"
	# It says "enter mode".
	# If I keep shooting at max stacks, it triggers every time.
	# That would exponentially decrease atk_speed (0.75 * 0.75...).
	# So I should check if mode is active.
	# But I don't have a state variable easily.
	# I can check `unit.guaranteed_crit_stacks`.

	if unit.guaranteed_crit_stacks > 0: return

	unit.add_crit_stacks(3)
	unit.atk_speed *= 0.75
	GameManager.spawn_floating_text(unit.global_position, "DRILL MODE!", Color.ORANGE)

	await unit.get_tree().create_timer(unit.atk_speed * 3.0).timeout # Use current (fast) speed for duration estimation

	if is_instance_valid(unit):
		unit.atk_speed /= 0.75
