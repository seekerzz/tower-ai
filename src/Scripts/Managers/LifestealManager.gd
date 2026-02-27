class_name LifestealManager
extends Node

signal lifesteal_occurred(source, amount)

@export var lifesteal_ratio: float = 0.8

func _ready():
	# Connect to GameManager signals for lifesteal
	# Signal signature: enemy_hit(enemy, source, amount)
	GameManager.enemy_hit.connect(_on_damage_dealt)
	# Signal signature: bleed_damage(target, damage, stacks, source)
	GameManager.bleed_damage.connect(_on_bleed_damage)

func _on_damage_dealt(target, source, damage: float):
	# Only process if source is valid (skip bleed damage without source)
	if !is_instance_valid(target) or !is_instance_valid(source):
		return

	# Check if target is an Enemy and has bleed stacks
	if not "bleed_stacks" in target:
		return

	if target.bleed_stacks <= 0:
		return

	# Check if source is a Bat Totem unit
	if not _is_bat_totem_unit(source):
		return

	# Calculate lifesteal amount
	var multiplier = GameManager.get_global_buff("lifesteal_multiplier", 1.0)

	# Risk-reward mechanism: lower core HP = stronger lifesteal
	var risk_reward_multiplier = _calculate_risk_reward_multiplier()

	var lifesteal_amount = target.bleed_stacks * 1.5 * lifesteal_ratio * multiplier * risk_reward_multiplier

	# Cap lifesteal amount to 5% of max core health per hit
	var max_heal = GameManager.max_core_health * 0.05
	lifesteal_amount = min(lifesteal_amount, max_heal)

	if lifesteal_amount > 0:
		if GameManager.has_method("heal_core"):
			GameManager.heal_core(lifesteal_amount)
		else:
			GameManager.damage_core(-lifesteal_amount)

		lifesteal_occurred.emit(source, lifesteal_amount)
		_show_lifesteal_effect(target.global_position, lifesteal_amount)
		print("[LifestealManager] Bleed stacks: ", target.bleed_stacks, ", Lifesteal: ", lifesteal_amount)

func _is_bat_totem_unit(source: Node) -> bool:
	# Check if source is a Unit and has type_key or faction
	if not is_instance_valid(source):
		return false

	# Check by type_key (Bat Totem unit IDs)
	if source.get("type_key"):
		var bat_unit_types = ["mosquito", "blood_mage", "vampire_bat", "plague_spreader", "blood_ancestor"]
		if source.type_key in bat_unit_types:
			return true

	# Check by faction (alternative way to identify)
	if source.get("unit_data") and source.unit_data.get("faction") == "bat_totem":
		return true

	return false

func _show_lifesteal_effect(pos: Vector2, amount: float):
	# Green floating text
	GameManager.spawn_floating_text(pos, "+" + str(int(amount)), Color.GREEN, Vector2.UP)

func _calculate_risk_reward_multiplier() -> float:
	"""
	Risk-reward mechanism:
	- Core HP > 35%: normal (1.0x)
	- Core HP <= 35%: doubled (2.0x)
	"""
	var core_health_percent = GameManager.core_health / GameManager.max_core_health
	if core_health_percent <= 0.35:
		return 2.0  # Critical state: lifesteal doubled
	return 1.0  # Normal state

func _on_bleed_damage(target, damage, stacks, source):
	"""
	Handle bleed damage event for lifesteal.
	Called when bleed damage is applied to an enemy.
	"""
	if !is_instance_valid(target) or !is_instance_valid(source):
		return

	# Check if source is a Bat Totem unit
	if not _is_bat_totem_unit(source):
		return

	# Calculate lifesteal amount based on bleed stacks
	var multiplier = GameManager.get_global_buff("lifesteal_multiplier", 1.0)
	var risk_reward_multiplier = _calculate_risk_reward_multiplier()
	var lifesteal_amount = stacks * 1.5 * lifesteal_ratio * multiplier * risk_reward_multiplier

	# Cap lifesteal amount to 5% of max core health per hit
	var max_heal = GameManager.max_core_health * 0.05
	lifesteal_amount = min(lifesteal_amount, max_heal)

	if lifesteal_amount > 0:
		var old_hp = GameManager.core_health
		print("[LifestealManager] About to heal: ", lifesteal_amount, " current HP: ", old_hp)
		# Directly modify core_health if heal_core fails
		if GameManager.has_method("heal_core"):
			GameManager.heal_core(lifesteal_amount)
		else:
			GameManager.core_health = min(GameManager.max_core_health, GameManager.core_health + lifesteal_amount)
		print("[LifestealManager] After heal HP: ", GameManager.core_health)

		lifesteal_occurred.emit(source, lifesteal_amount)
		_show_lifesteal_effect(target.global_position, lifesteal_amount)
		print("[LifestealManager] Bleed stacks: ", stacks, ", Lifesteal: ", lifesteal_amount)
