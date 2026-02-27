class_name CharmedEnemyBehavior
extends EnemyBehavior

var charm_duration: float = 3.0
var charm_timer: float = 0.0
var charm_source: Node = null
var target_enemy: Node2D = null

func init(enemy_node: CharacterBody2D, enemy_data: Dictionary):
	super.init(enemy_node, enemy_data)
	charm_timer = charm_duration
	_find_target()

func _find_target():
	# 寻找最近的非魅惑敌人作为目标
	var min_dist = 9999.0
	var nearest = null

	for e in enemy.get_tree().get_nodes_in_group("enemies"):
		if e == enemy or not is_instance_valid(e):
			continue
		if e.get("faction") == "player":  # 跳过其他被魅惑的敌人
			continue
		var dist = enemy.global_position.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = e

	target_enemy = nearest

func physics_process(delta: float) -> bool:
	charm_timer -= delta

	if charm_timer <= 0:
		_end_charm()
		return false  # 让默认行为接管

	if not is_instance_valid(target_enemy) or (target_enemy.has_method("is_dying") and target_enemy.is_dying):
		_find_target()

	if target_enemy and is_instance_valid(target_enemy):
		# 向目标移动
		var dir = (target_enemy.global_position - enemy.global_position).normalized()
		enemy.velocity = dir * enemy.speed * 1.2  # 魅惑时移速+20%
		enemy.move_and_slide()

		# 攻击检测
		var attack_range = 40.0 # Default melee range
		if enemy.global_position.distance_to(target_enemy.global_position) < attack_range:
			_attack_target(delta)
	else:
		# 没有目标时向核心反方向移动
		var core_pos = Vector2.ZERO
		if GameManager.grid_manager:
			core_pos = GameManager.grid_manager.global_position

		var away_from_core = (enemy.global_position - core_pos).normalized()
		enemy.velocity = away_from_core * enemy.speed
		enemy.move_and_slide()

	return true

var attack_cooldown: float = 0.0

func _attack_target(delta: float):
	attack_cooldown -= delta
	if attack_cooldown <= 0:
		if target_enemy and is_instance_valid(target_enemy):
			var damage = enemy.enemy_data.get("damage", 10)
			if target_enemy.has_method("take_damage"):
				target_enemy.take_damage(damage, enemy)
				# Simple attack animation via wobble if available
				if enemy.visual_controller:
					enemy.visual_controller.wobble_scale = Vector2(1.2, 0.8)
					var tween = enemy.create_tween()
					tween.tween_property(enemy.visual_controller, "wobble_scale", Vector2.ONE, 0.2)

			attack_cooldown = 1.0 # Standard 1s cooldown for charmed attacks

func _end_charm():
	enemy.set("faction", "enemy")
	enemy.modulate = Color.WHITE

	if charm_source and is_instance_valid(charm_source):
		if charm_source.has_method("_on_charmed_enemy_died"): # Or specific method to remove from list
			if "charmed_enemies" in charm_source:
				charm_source.charmed_enemies.erase(enemy)

	# 切换回默认行为
	enemy._init_behavior()
	queue_free()
