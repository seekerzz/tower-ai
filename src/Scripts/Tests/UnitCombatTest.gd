extends SceneTree

const UnitCombat = preload("res://src/Scripts/Components/UnitCombat.gd")

class MockEnemy extends Node2D:
	func _init(p: Vector2):
		self.global_position = p
		self.name = "MockEnemy"

func _init():
	print("[UnitCombatTest] Starting tests...")
	var success = true

	success = success and test_find_nearest_enemy()
	success = success and test_no_enemies_in_range()
	success = success and test_cooldown_interception()
	success = success and test_skill_mana_cost()

	if success:
		print("[UnitCombatTest] ALL TESTS PASSED.")
		quit(0)
	else:
		print("[UnitCombatTest] SOME TESTS FAILED.")
		quit(1)

func test_find_nearest_enemy() -> bool:
	print("[Test] test_find_nearest_enemy")
	var combat = UnitCombat.new()
	combat.stats["range_val"] = 100.0

	var r = Node.new()
	self.root.add_child(r)

	var enemy1 = MockEnemy.new(Vector2(110, 0)) # Out of range
	var enemy2 = MockEnemy.new(Vector2(50, 0))  # Closest
	var enemy3 = MockEnemy.new(Vector2(80, 0))  # Further but in range

	r.add_child(enemy1)
	r.add_child(enemy2)
	r.add_child(enemy3)

	var enemies = [enemy1, enemy2, enemy3]
	var nearest = combat.find_nearest_enemy(Vector2.ZERO, combat.stats["range_val"], enemies)

	var passed = (nearest == enemy2)
	if !passed:
		printerr("Expected enemy2 as nearest, got ", nearest)

	r.queue_free()
	return passed

func test_no_enemies_in_range() -> bool:
	print("[Test] test_no_enemies_in_range")
	var combat = UnitCombat.new()
	combat.stats["range_val"] = 100.0
	combat.stats["atk_speed"] = 1.0
	combat.stats["attack_cost_mana"] = 10.0

	var enemies = []
	var initial_mana = 100.0

	var result = combat.process_combat(0.0, Vector2.ZERO, enemies, initial_mana)

	var passed = true
	if result["action"] != "none":
		printerr("Expected action to be 'none', got ", result["action"])
		passed = false
	if combat.cooldown != 0.0:
		printerr("Expected cooldown to be 0.0, got ", combat.cooldown)
		passed = false
	if combat.is_no_mana:
		printerr("Expected is_no_mana to be false")
		passed = false

	return passed

func test_cooldown_interception() -> bool:
	print("[Test] test_cooldown_interception")
	var combat = UnitCombat.new()
	combat.stats["range_val"] = 100.0
	combat.stats["atk_speed"] = 1.0
	combat.stats["attack_cost_mana"] = 0.0

	var r = Node.new()
	self.root.add_child(r)

	var enemy = MockEnemy.new(Vector2(50, 0))
	r.add_child(enemy)

	var enemies = [enemy]
	var initial_mana = 100.0

	# First attack
	var result1 = combat.process_combat(0.0, Vector2.ZERO, enemies, initial_mana)
	if result1["action"] != "attack":
		printerr("First process_combat should attack")
		return false
	if combat.cooldown != 1.0:
		printerr("First process_combat should set cooldown to 1.0, got ", combat.cooldown)
		return false

	# Second attack immediately
	var result2 = combat.process_combat(0.0, Vector2.ZERO, enemies, initial_mana)
	if result2["action"] != "none":
		printerr("Second process_combat should be intercepted by cooldown")
		return false

	r.queue_free()
	return true

# We will use an inner class as a generic Object for signal reception to avoid lambda/node errors
class DummyReceiver extends RefCounted:
	var received = false
	func _on_signal():
		received = true

func test_skill_mana_cost() -> bool:
	print("[Test] test_skill_mana_cost")
	var combat = UnitCombat.new()
	combat.stats["skill_mana_cost"] = 30.0
	combat.stats["skill_cost_reduction"] = 0.0
	combat.stats["skill_cd"] = 10.0

	var current_mana = 10.0

	var receiver = DummyReceiver.new()
	combat.on_no_mana.connect(receiver._on_signal)

	var success = combat.execute_skill(current_mana)

	if success:
		printerr("execute_skill should return false when out of mana")
		return false
	if not receiver.received:
		printerr("on_no_mana signal was not emitted")
		return false
	if not combat.is_no_mana:
		printerr("is_no_mana variable not set to true")
		return false

	return true
