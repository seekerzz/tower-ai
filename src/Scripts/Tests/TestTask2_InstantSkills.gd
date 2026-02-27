extends Node

# Test script for verifying Instant Skills logic (Task 2)
# Since GameManager is an Autoload, we can access it directly.
# However, we need to setup a basic environment.

var unit_script = preload("res://src/Scripts/Unit.gd")
var enemy_script = preload("res://src/Scripts/Enemy.gd")

func _ready():
	print("Starting TestTask2_InstantSkills...")

	# Mock GameManager state
	GameManager.is_wave_active = true
	GameManager.core_health = 500
	GameManager.max_core_health = 1000
	GameManager.mana = 1000 # Plenty of mana for skills

	# Create a temporary container for units/enemies so they can find each other via group
	# But Enemy finds enemies via get_tree().get_nodes_in_group("enemies")
	# Unit finds enemies for stun similarly.

	test_cow_skill()
	test_dog_skill()
	test_bear_skill()

	print("Task 2 Verification Passed")
	get_tree().quit()

func test_cow_skill():
	print("Testing Cow Skill...")
	var cow = Node2D.new()
	cow.set_script(unit_script)
	add_child(cow)

	# Setup Cow
	cow.setup("cow") # Assuming "cow" exists in Constants
	cow.skill_cooldown = 0
	GameManager.mana = 1000

	var initial_core_hp = GameManager.core_health

	# Activate Skill
	cow.activate_skill()

	assert(cow.skill_active_timer > 0, "Cow skill timer should be active")
	assert(cow._is_skill_highlight_active == true, "Cow should be highlighted")
	assert(cow._highlight_color == Color.GREEN, "Cow highlight should be green")

	# Simulate 1 second
	var delta = 1.0
	cow._process(delta)

	# Cow regens 200 * delta per second when active
	# plus the passive 50 every 5 seconds (which might trigger if timer hits)

	var expected_hp_increase = 200 * delta
	# Passive might have triggered if production_timer <= 0, but it starts at 5.0

	var current_hp = GameManager.core_health

	assert(current_hp > initial_core_hp, "Core health should increase")
	assert(abs((current_hp - initial_core_hp) - expected_hp_increase) < 1.0, "HP increase mismatch. Expected ~200, Got: " + str(current_hp - initial_core_hp))

	print("Cow Skill Verified.")
	cow.queue_free()

func test_dog_skill():
	print("Testing Dog Skill...")
	var dog = Node2D.new()
	dog.set_script(unit_script)
	add_child(dog)

	dog.setup("dog")
	dog.skill_cooldown = 0
	GameManager.mana = 1000

	var base_atk_speed = dog.atk_speed

	# Activate Skill
	dog.activate_skill()

	assert(dog.skill_active_timer > 0, "Dog skill timer active")
	assert(dog._is_skill_highlight_active == true, "Dog highlighted")
	assert(dog._highlight_color == Color.RED, "Dog red highlight")

	# Check speed acceleration (atk_speed *= 0.3)
	assert(dog.atk_speed < base_atk_speed, "Attack speed (interval) should be smaller (faster)")
	assert(abs(dog.atk_speed - (base_atk_speed * 0.3)) < 0.001, "Attack speed multiplier incorrect")

	# Simulate 5.1 seconds to expire
	dog._process(5.1)

	assert(dog.skill_active_timer <= 0, "Skill should expire")
	assert(dog._is_skill_highlight_active == false, "Highlight should turn off")
	assert(abs(dog.atk_speed - base_atk_speed) < 0.001, "Attack speed should revert. Got: " + str(dog.atk_speed) + ", Expected: " + str(base_atk_speed))

	print("Dog Skill Verified.")
	dog.queue_free()

func test_bear_skill():
	print("Testing Bear Skill...")
	var bear = Node2D.new()
	bear.set_script(unit_script)
	add_child(bear)

	bear.setup("bear")
	bear.skill_cooldown = 0
	GameManager.mana = 1000

	# Create an enemy nearby
	var enemy = Area2D.new()
	enemy.set_script(enemy_script)
	add_child(enemy)
	# Need to call ready to add to group
	# Manually add to group if not in tree, but add_child puts it in tree.
	# Enemy.gd adds to "enemies" in _ready.

	# Setup enemy minimal data
	enemy.setup("slime", 1)

	# Position
	bear.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(10, 0) # Within range (Bear range is 80)

	# Activate Skill
	bear.activate_skill()

	assert(enemy.stun_timer > 0, "Enemy should be stunned")
	assert(enemy.stun_timer == 2.0, "Stun duration should be 2.0")

	# Test enemy process skips logic
	var pos_before = enemy.position
	enemy._process(0.1)
	var pos_after = enemy.position

	# Should not move
	assert(pos_before == pos_after, "Stunned enemy should not move")

	print("Bear Skill Verified.")

	bear.queue_free()
	enemy.queue_free()
