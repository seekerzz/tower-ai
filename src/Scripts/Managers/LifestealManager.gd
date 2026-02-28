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
	# Spawn blood particles flying to core
	_spawn_lifesteal_particles(pos, amount)

func _spawn_lifesteal_particles(start_pos: Vector2, amount: float):
	"""
	生成吸血粒子效果
	- 血滴粒子从敌人飞向核心
	- 粒子数量基于吸血量
	"""
	if not GameManager.grid_manager:
		return

	var core_pos = GameManager.grid_manager.global_position
	var particle_count = _calculate_particle_count(amount)

	for i in range(particle_count):
		var particle = _create_blood_particle(start_pos, core_pos, i, particle_count)
		if particle:
			# Add to scene
			var scene = Engine.get_main_loop().current_scene
			if scene:
				scene.add_child(particle)

func _calculate_particle_count(amount: float) -> int:
	"""
	计算粒子数量
	- 基础: 5个粒子
	- 每10点吸血: +2个粒子
	- 最大: 20个粒子
	"""
	var base_count = 5
	var bonus = int(amount / 10.0) * 2
	return min(base_count + bonus, 20)

func _create_blood_particle(start: Vector2, target: Vector2, index: int, total: int) -> Node2D:
	"""
	创建单个血滴粒子
	"""
	var particle = Node2D.new()
	particle.global_position = start

	# Create visual (blood drop shape using Polygon2D)
	var visual = Polygon2D.new()
	var size = randf_range(4, 8)
	# Create teardrop shape
	visual.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.7, size * 0.3),
		Vector2(0, size),
		Vector2(-size * 0.7, size * 0.3)
	])

	# Color gradient: dark red -> bright red
	var t = float(index) / max(total - 1, 1)
	visual.color = Color(0.5, 0.0, 0.0).lerp(Color(0.9, 0.1, 0.1), t)
	particle.add_child(visual)

	# Calculate flight path with arc
	var direction = (target - start).normalized()
	var distance = start.distance_to(target)
	var duration = 0.5  # 0.5 seconds flight time
	var speed = distance / duration

	# Add random arc offset
	var arc_offset = Vector2(-direction.y, direction.x) * randf_range(-50, 50)
	var mid_point = (start + target) / 2 + arc_offset

	# Animate along arc path
	var tween = particle.create_tween()
	tween.tween_property(particle, "global_position", mid_point, duration * 0.5)
	tween.tween_property(particle, "global_position", target, duration * 0.5)

	# Fade out and scale down at end
	tween.parallel().tween_property(visual, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	tween.parallel().tween_property(visual, "scale", Vector2.ZERO, duration * 0.2).set_delay(duration * 0.8)

	# Cleanup
	tween.tween_callback(particle.queue_free)

	# Core flash effect when particle arrives
	if index == 0:  # Only trigger once for the first particle
		tween.tween_callback(_trigger_core_heal_flash)

	return particle

func _trigger_core_heal_flash():
	"""
	核心受治疗时的闪烁效果
	"""
	if GameManager.grid_manager:
		var core = GameManager.grid_manager
		if core.has_method("flash_heal_effect"):
			core.flash_heal_effect()
		else:
			# Fallback: spawn floating text at core
			GameManager.spawn_floating_text(core.global_position, "❤", Color.GREEN, Vector2.UP)

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
