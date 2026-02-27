extends Node

func _ready():
	print("Starting TestProjectileRefactor...")
	test_burn_application()
	print("TestProjectileRefactor Completed.")
	get_tree().quit()

func test_burn_application():
	print("Testing Burn Application...")

	# Mock Enemy
	var enemy_script = load("res://src/Scripts/Enemy.gd")
	var enemy = CharacterBody2D.new()
	enemy.set_script(enemy_script)
	enemy.name = "TestEnemy"
	# Need minimal setup for Enemy
	enemy.type_key = "slime"
	enemy.enemy_data = {"hpMod": 1.0, "spdMod": 1.0, "color": Color.GREEN, "radius": 10.0}
	enemy.hp = 100
	enemy.max_hp = 100

	add_child(enemy)
	enemy.setup("slime", 1) # Depends on Constants, Assets... hope they exist or fail gracefully

	# Mock Projectile
	var proj_script = load("res://src/Scripts/Projectile.gd")
	var proj = Area2D.new()
	proj.set_script(proj_script)
	add_child(proj)

	# Setup Projectile with Burn
	var stats = {
		"effects": {"burn": 5.0} # 5s burn
	}
	proj.setup(Vector2.ZERO, enemy, 10.0, 400.0, "fireball", stats)

	# Force Collision/Hit
	# Since physics collision takes time/setup, we can call _handle_hit directly if public or exposed.
	# _handle_hit is semi-private but accessible in GDScript.
	proj._handle_hit(enemy)

	# Check Result
	var burn_effect = null
	for c in enemy.get_children():
		if c.get("type_key") == "burn":
			burn_effect = c
			break

	if burn_effect:
		print("PASS: BurnEffect found on enemy.")
		if burn_effect.duration == 5.0:
			print("PASS: Burn duration is 5.0.")
		else:
			print("FAIL: Burn duration is %s" % burn_effect.duration)
	else:
		print("FAIL: BurnEffect NOT found on enemy.")

	# Clean up
	enemy.queue_free()
	proj.queue_free()
