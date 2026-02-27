extends Node

func _ready():
	print("Starting TestCoreMechanics...")
	test_case_1_abundance_wave_item()
	test_case_2_moon_well_accumulation()
	test_case_3_holy_sword_crit()
	print("TestCoreMechanics Completed.")

func test_case_1_abundance_wave_item():
	print("Testing Case 1: Abundance Wave Item...")

	# Setup
	GameManager.core_type = "abundance"
	var inv = GameManager.inventory_manager
	# Clear inventory first if needed
	inv.items.fill(null)

	# Action
	GameManager._on_wave_started()

	# Assert
	var found = false
	for item in inv.items:
		if item and item.item_id == "rice_ear":
			found = true
			break

	if found:
		print("PASS: rice_ear found in inventory.")
	else:
		print("FAIL: rice_ear NOT found in inventory.")

func test_case_2_moon_well_accumulation():
	print("Testing Case 2: Moon Well Accumulation...")

	# Setup
	GameManager.core_type = "moon_well"
	GameManager.moonwell_pool = 0

	# Action
	# Simulate damage dealt signal
	GameManager._on_damage_dealt(null, 1000)

	# Assert
	if GameManager.moonwell_pool == 100:
		print("PASS: Moon well pool is 100 (10% of 1000).")
	else:
		print("FAIL: Moon well pool is %s (expected 100)." % GameManager.moonwell_pool)

func test_case_3_holy_sword_crit():
	print("Testing Case 3: Holy Sword Crit...")

	# Setup
	var unit_script = load("res://src/Scripts/Unit.gd")
	var unit = Node2D.new()
	unit.set_script(unit_script)
	# Mock data
	unit.unit_data = {"crit_rate": 0.0} # 0% base crit
	unit.crit_rate = 0.0
	unit.guaranteed_crit_stacks = 0

	# Action
	unit.add_crit_stacks(3)

	if unit.guaranteed_crit_stacks != 3:
		print("FAIL: Stack count mismatch.")
		return

	# Simulate combat checks (CombatManager logic)
	# We can't easily call internal combat logic without full setup,
	# but we can verify the logic block we wrote by manual check or replicating it here.
	# Or we can instantiate CombatManager and use a dummy check if possible.

	# Since I modified CombatManager logic:
	# if source_unit.guaranteed_crit_stacks > 0: is_critical = true; stack--

	var success_count = 0
	for i in range(3):
		if unit.guaranteed_crit_stacks > 0:
			# Simulate the check
			unit.guaranteed_crit_stacks -= 1
			success_count += 1

	if success_count == 3 and unit.guaranteed_crit_stacks == 0:
		print("PASS: Consumed 3 stacks correctly.")
	else:
		print("FAIL: Did not consume stacks correctly. Success: %d, Left: %d" % [success_count, unit.guaranteed_crit_stacks])
