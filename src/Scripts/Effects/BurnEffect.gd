extends "res://src/Scripts/Effects/StatusEffect.gd"

var base_damage: float = 0.0
var explosion_damage: float = 0.0
var tick_timer: float = 0.0
const TICK_INTERVAL = 0.5

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)
	type_key = "burn"
	base_damage = params.get("damage", 10.0)
	explosion_damage = params.get("explosion_damage", base_damage * 3.0)

	# 记录[DEBUFF] Burn施加日志
	if AILogger:
		var source_name = "未知"
		if source:
			if source.has_method("get_unit_name"):
				source_name = source.get_unit_name()
			elif "type_key" in source:
				source_name = source.type_key
		var target_name = target.type_key if "type_key" in target else "目标"
		var debuff_msg = "[DEBUFF] %s 施加 Burn | 目标: %s | 层数: %d | 伤害: %.0f/秒 | 死亡爆炸: %.0f" % [source_name, target_name, stacks, base_damage * stacks, explosion_damage * stacks]
		AILogger.event(debuff_msg)
		# 同时通过AIManager广播，确保测试脚本能检测到
		if AIManager:
			AIManager.broadcast_text(debuff_msg)

func apply(delta: float):
	super.apply(delta)

	tick_timer += delta
	if tick_timer >= 1.0:
		tick_timer -= 1.0
		_deal_damage()

func stack(params: Dictionary):
	var old_stacks = stacks
	super.stack(params)

	# 记录[DEBUFF] Burn叠加日志
	if AILogger and stacks != old_stacks:
		var host = get_parent()
		if host:
			var target_name = host.type_key if "type_key" in host else "目标"
			var stack_msg = "[DEBUFF] Burn叠加 | 目标: %s | 当前层数: %d | 伤害: %.0f/秒 | 死亡爆炸: %.0f" % [target_name, stacks, base_damage * stacks, explosion_damage * stacks]
			AILogger.event(stack_msg)
			# 同时通过AIManager广播，确保测试脚本能检测到
			if AIManager:
				AIManager.broadcast_text(stack_msg)

func _deal_damage():
	var host = get_parent()
	if host and host.has_method("take_damage"):
		var dmg = base_damage * stacks
		host.take_damage(dmg, source_unit, "fire")

		# 记录[DEBUFF] Burn伤害日志
		if AILogger:
			var target_name = host.type_key if "type_key" in host else "目标"
			var damage_msg = "[DEBUFF] Burn伤害 | 目标: %s | 层数: %d | 伤害: %.0f" % [target_name, stacks, dmg]
			AILogger.event(damage_msg)
			# 同时通过AIManager广播，确保测试脚本能检测到
			if AIManager:
				AIManager.broadcast_text(damage_msg)

		# Emit signal for test logging
		if GameManager.has_signal("burn_damage"):
			GameManager.burn_damage.emit(host, dmg, stacks, source_unit)

func _on_host_died():
	# Explosion logic
	var host = get_parent()
	if not host: return

	var center = host.global_position
	var final_explosion_damage = explosion_damage * stacks

	# Visual
	var effect = load("res://src/Scripts/Effects/SlashEffect.gd").new()
	# Add visual to map/parent of host to persist
	host.get_parent().call_deferred("add_child", effect)
	effect.global_position = center
	effect.configure("cross", Color.ORANGE)
	effect.scale = Vector2(3, 3)
	effect.play()

	# Direct Explosion Logic
	var radius = 120.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var burn_script = load("res://src/Scripts/Effects/BurnEffect.gd")
	var affected_targets = []

	for enemy in enemies:
		if !is_instance_valid(enemy): continue

		var dist = center.distance_to(enemy.global_position)
		if dist <= radius:
			enemy.take_damage(final_explosion_damage, source_unit, "fire")
			affected_targets.append(enemy)
			# Chain reaction: Apply burn
			if enemy.has_method("apply_status"):
				enemy.apply_status(burn_script, {
					"duration": 5.0,
					"damage": final_explosion_damage,
					"stacks": 1
				})

	# Emit signal for test logging with affected targets
	if GameManager.has_signal("burn_explosion"):
		GameManager.burn_explosion.emit(center, final_explosion_damage, source_unit, affected_targets)
