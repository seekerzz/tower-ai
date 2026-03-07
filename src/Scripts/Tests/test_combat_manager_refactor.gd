extends SceneTree

# We extend SceneTree to run as a standalone script via `--script`
var exit_code = 0

# Dummy classes for testing
class DummyUnit extends Node2D:
	var type_key = "dummy"
	var max_hp = 100
	var hp = 100
	var is_dead = false
	var enemy_data = {"radius": 10.0}

	func take_damage(amount, source, type):
		hp -= amount
		if hp <= 0:
			is_dead = true

	func apply_status(script, params):
		pass

class DummyGameManager extends Node:
	signal poison_explosion
	signal burn_explosion
	var combat_manager = null

	func _ready():
		name = "GameManager"

func _init():
	# Wait for first frame to initialize properly
	call_deferred("_run_tests")

func _run_tests():
	print("[TEST] Starting CombatManager refactor boundary tests...")

	# Create dummy GameManager
	var gm = DummyGameManager.new()
	root.add_child(gm)

	# Using autoloads logic roughly for test
	Engine.register_singleton("GameManager", gm)

	# Create CombatManager
	var cm = load("res://src/Scripts/CombatManager.gd").new()
	cm.name = "CombatManager"
	root.add_child(cm)
	gm.combat_manager = cm

	# Run tests
	test_meteor_shower_removed(cm)
	test_explosion_methods_removed(cm)
	await test_poison_explosion_independence(cm, gm)

	print("[TEST] All tests completed with exit code: ", exit_code)
	quit(exit_code)

func test_meteor_shower_removed(cm):
	if cm.has_method("start_meteor_shower"):
		print("❌ FAILED: CombatManager still has start_meteor_shower")
		exit_code = 1
	else:
		print("✅ PASSED: CombatManager does not have start_meteor_shower")

func test_explosion_methods_removed(cm):
	if cm.has_method("trigger_burn_explosion") or cm.has_method("_process_burn_explosion_logic"):
		print("❌ FAILED: CombatManager still has burn explosion logic")
		exit_code = 1
	else:
		print("✅ PASSED: CombatManager does not have burn explosion logic")

	if cm.has_method("trigger_poison_explosion") or cm.has_method("_process_poison_explosion_logic"):
		print("❌ FAILED: CombatManager still has poison explosion logic")
		exit_code = 1
	else:
		print("✅ PASSED: CombatManager does not have poison explosion logic")

func test_poison_explosion_independence(cm, gm):
	# Create an enemy to be affected by explosion
	var enemy = DummyUnit.new()
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(100, 100)
	root.add_child(enemy)

	# Create host for poison effect
	var host = DummyUnit.new()
	host.global_position = Vector2(100, 100)
	root.add_child(host)

	# Add poison effect
	var poison_script = load("res://src/Scripts/Effects/PoisonEffect.gd")
	var poison = poison_script.new()
	host.add_child(poison)

	# Wait one frame for the tree to be ready
	await process_frame

	# Trigger death callback which should explode
	if poison.has_method("_on_host_died"):
		poison.stacks = 5
		poison.base_damage = 10.0
		poison._on_host_died()

		# Now enemy should have taken damage
		if enemy.hp < enemy.max_hp:
			print("✅ PASSED: PoisonEffect explosion independently damaged enemy")
		else:
			print("❌ FAILED: PoisonEffect explosion failed to damage enemy directly")
			exit_code = 1
	else:
		print("❌ FAILED: PoisonEffect missing _on_host_died")
		exit_code = 1

	enemy.queue_free()
	host.queue_free()
