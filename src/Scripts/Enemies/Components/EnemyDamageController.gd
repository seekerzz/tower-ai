extends RefCounted
class_name EnemyDamageController

var enemy: CharacterBody2D

func _init(target_enemy: CharacterBody2D):
	enemy = target_enemy

func heal(amount: float):
	if enemy.hp <= 0:
		return
	enemy.hp = min(enemy.hp + amount, enemy.max_hp)
	enemy.queue_redraw()

func add_bleed_stacks(stacks: int, source_unit = null):
	var old_stacks = enemy.bleed_stacks
	enemy.bleed_stacks = min(enemy.bleed_stacks + stacks, enemy.max_bleed_stacks)
	if enemy.bleed_stacks != old_stacks:
		enemy.bleed_stack_changed.emit(enemy.bleed_stacks)
		enemy.queue_redraw()
	if source_unit and enemy._bleed_source_unit == null:
		enemy._bleed_source_unit = source_unit

func process_bleed_damage(delta: float):
	if enemy.bleed_stacks <= 0:
		return
	var damage = enemy.bleed_stacks * enemy.bleed_damage_per_stack * delta
	enemy._bleed_display_timer -= delta
	var should_show_text = enemy._bleed_display_timer <= 0
	if should_show_text:
		enemy._bleed_display_timer = enemy.BLEED_DISPLAY_INTERVAL
	take_damage(damage, enemy._bleed_source_unit, "bleed", null, 0.0, should_show_text)

func take_damage(amount: float, source_unit = null, damage_type: String = "physical", hit_source: Node2D = null, kb_force: float = 0.0, show_text: bool = true):
	if source_unit == GameManager:
		print("[Enemy] Taking global damage from GameManager: ", amount)
	if enemy.invincible_timer > 0:
		return

	if enemy.behavior:
		var handled = enemy.behavior.on_hit({
			"amount": amount,
			"source_unit": source_unit,
			"damage_type": damage_type,
			"hit_source": hit_source,
			"kb_force": kb_force
		})
		if handled:
			return

	for child in enemy.get_children():
		if child.has_method("get_damage_multiplier"):
			amount *= child.get_damage_multiplier()

	enemy.hp -= amount
	enemy.hit_flash_timer = 0.1
	enemy.queue_redraw()

	var hit_dir = Vector2.ZERO
	if hit_source and is_instance_valid(hit_source) and "speed" in hit_source:
		hit_dir = Vector2.RIGHT.rotated(hit_source.rotation)
	enemy.last_hit_direction = hit_dir

	if enemy.enemy_data.get("shape") == "rect":
		var hit_pos = hit_source.global_position if hit_source and "global_position" in hit_source else enemy.global_position
		var r = hit_pos - enemy.global_position
		var force_dir = hit_dir
		if force_dir == Vector2.ZERO and hit_source:
			force_dir = (enemy.global_position - hit_source.global_position).normalized()
		var torque = r.x * force_dir.y - r.y * force_dir.x
		enemy.angular_velocity += torque * 0.05

	if kb_force > 0:
		var applied_force = kb_force / max(0.1, enemy.knockback_resistance)
		enemy.knockback_velocity += hit_dir * applied_force

	if show_text:
		var display_val = max(1, int(amount))
		GameManager.spawn_floating_text(enemy.global_position, str(display_val), damage_type, hit_dir if damage_type != "bleed" else Vector2.ZERO)

	GameManager.enemy_hit.emit(enemy, source_unit, amount)
	if GameManager.has_signal("bleed_damage") and damage_type == "bleed":
		GameManager.bleed_damage.emit(enemy, amount, enemy.bleed_stacks, source_unit)
	if source_unit:
		GameManager.damage_dealt.emit(source_unit, amount)
	if enemy.hp <= 0:
		enemy.die(source_unit)
