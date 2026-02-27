extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Pigeon - 鸽子
# 闪避敌人攻击
# Lv2闪避后0.3秒无敌
# Lv3闪避时反击并给友方加暴击

var dodge_chance: float = 0.12
var is_invulnerable: bool = false
var invuln_timer: float = 0.0

func _init(target_unit: Node2D):
	super._init(target_unit)

func on_tick(delta: float):
	if invuln_timer > 0:
		invuln_timer -= delta
		if invuln_timer <= 0:
			is_invulnerable = false

func on_damage_taken(amount: float, source: Node2D) -> float:
	if is_invulnerable:
		return 0.0

	var chance = dodge_chance
	if unit.level >= 2:
		chance = 0.20

	if randf() < chance:
		_on_dodge_success(source)
		return 0.0

	return amount

func _on_dodge_success(attacker: Node2D):
	GameManager.spawn_floating_text(unit.global_position, "DODGE!", Color.CYAN)

	if unit.level >= 2:
		is_invulnerable = true
		invuln_timer = 0.3

	if unit.level >= 3 and attacker and attacker.is_in_group("enemies"):
		_counter_attack(attacker)
		_apply_dodge_buff_to_allies()

func _counter_attack(enemy: Node2D):
	if not is_instance_valid(enemy): return
	var counter_damage = unit.damage * 0.6

	enemy.take_damage(counter_damage, unit, "physical")

	# Trigger Echo manually if crit
	if randf() < unit.crit_rate:
		GameManager.projectile_crit.emit(unit, enemy, counter_damage)

func _apply_dodge_buff_to_allies():
	var allies = _get_units_in_radius(150.0)
	for ally in allies:
		if ally.has_method("add_temporary_buff"):
			ally.add_temporary_buff("crit_chance", 0.08, 3.0)

func _get_units_in_radius(radius: float) -> Array:
	if not GameManager.grid_manager: return []
	var list = []

	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		if tile.unit and is_instance_valid(tile.unit):
			if tile.unit.global_position.distance_to(unit.global_position) <= radius:
				list.append(tile.unit)
	return list
