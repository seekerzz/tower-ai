extends Node

class MockCombatManager:
	func spawn_projectile(source, pos, target, stats):
		# Return a dummy object that behaves like a Projectile for our needs
		var proj = Node2D.new()
		# Add hit_list property
		proj.set_meta("hit_list", []) # Since we can't easily add var to instance without script
		# Wait, MechanicButterflyTotem accesses `orb.hit_list`.
		# Node2D doesn't have hit_list.
		# We need to set a script or use a dictionary/inner class.
		proj.set_script(DummyProjectile)
		return proj

class DummyProjectile:
	extends Node2D
	var hit_list = []
	var life = 9999.0

func _ready():
	print("Starting TestButterflyTotem...")
	test_loading_mechanic()
	test_mana_gain_on_hit()
	test_spawn_orbs()
	print("TestButterflyTotem Completed.")
	get_tree().quit()

func test_loading_mechanic():
	print("Testing Loading Mechanic...")
	GameManager.core_type = "butterfly_totem"

	if GameManager.current_mechanic and GameManager.current_mechanic.get_script().resource_path.ends_with("MechanicButterflyTotem.gd"):
		print("PASS: MechanicButterflyTotem loaded.")
	else:
		print("FAIL: Failed to load MechanicButterflyTotem.")

func test_mana_gain_on_hit():
	print("Testing Mana Gain on Hit...")

	# Setup
	GameManager.core_type = "butterfly_totem"
	var mechanic = GameManager.current_mechanic

	var initial_mana = 0.0
	GameManager.mana = initial_mana

	# Action
	mechanic.on_projectile_hit(null, 10, null)

	# Assert
	if GameManager.mana == initial_mana + mechanic.MANA_GAIN:
		print("PASS: Mana increased by %s." % mechanic.MANA_GAIN)
	else:
		print("FAIL: Mana is %s (expected %s)." % [GameManager.mana, initial_mana + mechanic.MANA_GAIN])

func test_spawn_orbs():
	print("Testing Spawn Orbs...")
	GameManager.core_type = "butterfly_totem"
	var mechanic = GameManager.current_mechanic

	# Mock CombatManager
	var old_cm = GameManager.combat_manager
	GameManager.combat_manager = MockCombatManager.new()

	mechanic._spawn_orbs()

	if mechanic.orbs.size() == mechanic.ORB_COUNT:
		print("PASS: %d orbs spawned." % mechanic.ORB_COUNT)
	else:
		print("FAIL: %d orbs spawned (expected %d)." % [mechanic.orbs.size(), mechanic.ORB_COUNT])

	# Verify rehit reset works (simulation)
	mechanic.orbs[0].hit_list.append("enemy1")
	mechanic._reset_orb_hits()
	if mechanic.orbs[0].hit_list.is_empty():
		print("PASS: Orb hits reset.")
	else:
		print("FAIL: Orb hits NOT reset.")

	# Cleanup
	GameManager.combat_manager = old_cm
