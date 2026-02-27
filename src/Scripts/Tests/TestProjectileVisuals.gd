extends Node

func _ready():
	print("Starting TestProjectileVisuals...")
	test_projectile_visuals_visible()
	print("TestProjectileVisuals Completed.")
	get_tree().quit()

func test_projectile_visuals_visible():
	print("Testing Projectile Visuals Visibility...")

	# Mock Projectile
	var proj_script = load("res://src/Scripts/Projectile.gd")
	var proj = Area2D.new()
	proj.set_script(proj_script)

	# Call setup BEFORE adding to tree (simulating CombatManager)
	var stats = {}
	proj.setup(Vector2.ZERO, null, 10.0, 400.0, "pinecone", stats)

	add_child(proj)

	# Check if Visuals node exists
	var visuals = proj.get_node_or_null("Visuals")
	if visuals:
		print("PASS: Visuals node found.")
		if visuals.get_child_count() > 0:
			print("PASS: Visuals node has children (something is drawn).")
		else:
			print("FAIL: Visuals node has NO children.")
	else:
		print("FAIL: Visuals node NOT found.")

	proj.queue_free()
