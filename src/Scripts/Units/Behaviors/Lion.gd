extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Lion - 狮子
# Circular shockwave attacks - all attacks hit ALL enemies in radius
# Lv2: Knockback chance
# Lv3: Every 3rd attack creates delayed secondary shockwave

var shockwave_radius: float = 150.0
var roar_counter: int = 0
var knockback_chance: float = 0.0
var secondary_shockwave_delay: float = 0.5

func on_setup():
	# Set level-based stats
	match unit.level:
		1:
			shockwave_radius = 150.0
			knockback_chance = 0.0
		2:
			shockwave_radius = 180.0
			knockback_chance = 0.20
		3:
			shockwave_radius = 200.0
			knockback_chance = 0.30

func on_combat_tick(delta: float) -> bool:
	# Take over attack logic - Lion uses circular shockwave instead of normal attacks
	if not is_instance_valid(unit):
		return false

	# Check if we can attack (attack speed cooldown)
	if unit.has_method("can_attack") and not unit.can_attack():
		return true  # We're handling combat, just not attacking yet

	# Find all enemies in shockwave radius
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var targets_in_range = []

	for enemy in enemies:
		if is_instance_valid(enemy) and unit.global_position.distance_to(enemy.global_position) <= shockwave_radius:
			targets_in_range.append(enemy)

	if targets_in_range.size() == 0:
		return true  # No targets, but we're handling combat

	# Perform shockwave attack on all targets
	_perform_shockwave(targets_in_range)

	return true  # Combat handled

func _perform_shockwave(targets: Array):
	roar_counter += 1
	var is_third_attack = (roar_counter % 3 == 0)

	# Deal damage to all targets
	for target in targets:
		if is_instance_valid(target):
			var damage = unit.damage
			target.take_damage(damage, unit, unit.unit_data.get("damageType", "physical"))

			# Knockback chance (Lv2+)
			if knockback_chance > 0 and randf() < knockback_chance:
				_apply_knockback(target)

	# Visual feedback
	_create_shockwave_visual()
	GameManager.spawn_floating_text(unit.global_position, "ROAR!", Color.ORANGE)
	unit.spawn_buff_effect("🦁")

	# Lv3: Every 3rd attack creates delayed secondary shockwave
	if unit.level >= 3 and is_third_attack:
		_create_delayed_secondary_shockwave()

func _apply_knockback(enemy: Node2D):
	# Push enemy away from lion
	var direction = (enemy.global_position - unit.global_position).normalized()
	var knockback_distance = 50.0

	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction * knockback_distance)
	else:
		# Fallback: manually adjust position
		enemy.global_position += direction * knockback_distance

	GameManager.spawn_floating_text(enemy.global_position, "KNOCKBACK!", Color.WHITE)

func _create_shockwave_visual():
	# Spawn expanding circle effect
	var shockwave = ColorRect.new()
	shockwave.color = Color(1.0, 0.6, 0.0, 0.4)
	shockwave.size = Vector2(20, 20)
	shockwave.position = unit.global_position - Vector2(10, 10)
	unit.get_tree().root.add_child(shockwave)

	# Animate expansion
	var tween = unit.create_tween()
	tween.tween_property(shockwave, "size", Vector2(shockwave_radius * 2, shockwave_radius * 2), 0.2)
	tween.parallel().tween_property(shockwave, "position", unit.global_position - Vector2(shockwave_radius, shockwave_radius), 0.2)
	tween.parallel().tween_property(shockwave, "color:a", 0.0, 0.2)
	tween.tween_callback(shockwave.queue_free)

func _create_delayed_secondary_shockwave():
	# Delayed secondary shockwave (Lv3)
	await unit.get_tree().create_timer(secondary_shockwave_delay).timeout

	if not is_instance_valid(unit):
		return

	# Find enemies in range again (they may have moved)
	var enemies = unit.get_tree().get_nodes_in_group("enemies")
	var targets_in_range = []

	for enemy in enemies:
		if is_instance_valid(enemy) and unit.global_position.distance_to(enemy.global_position) <= shockwave_radius:
			targets_in_range.append(enemy)

	# Deal 50% damage to all targets
	for target in targets_in_range:
		if is_instance_valid(target):
			var damage = unit.damage * 0.5
			target.take_damage(damage, unit, unit.unit_data.get("damageType", "physical"))

			# Secondary shockwave always has knockback
			_apply_knockback(target)

	# Visual feedback for secondary shockwave
	_create_secondary_shockwave_visual()
	GameManager.spawn_floating_text(unit.global_position, "ECHO!", Color.DARK_RED)

func _create_secondary_shockwave_visual():
	# Spawn darker expanding circle for secondary shockwave
	var shockwave = ColorRect.new()
	shockwave.color = Color(0.6, 0.2, 0.0, 0.5)
	shockwave.size = Vector2(20, 20)
	shockwave.position = unit.global_position - Vector2(10, 10)
	unit.get_tree().root.add_child(shockwave)

	# Animate expansion
	var tween = unit.create_tween()
	tween.tween_property(shockwave, "size", Vector2(shockwave_radius * 2, shockwave_radius * 2), 0.3)
	tween.parallel().tween_property(shockwave, "position", unit.global_position - Vector2(shockwave_radius, shockwave_radius), 0.3)
	tween.parallel().tween_property(shockwave, "color:a", 0.0, 0.3)
	tween.tween_callback(shockwave.queue_free)
