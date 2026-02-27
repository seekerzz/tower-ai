extends Node

func _ready():
	print("Starting TestMeteorSource...")
	test_meteor_source_assignment()
	print("TestMeteorSource Completed.")
	get_tree().quit()

class MockMeteorSource extends RefCounted:
	var damage = 100.0

func test_meteor_source_assignment():
	print("Testing Meteor Source Assignment...")

	var proj_script = load("res://src/Scripts/Projectile.gd")
	var proj = Area2D.new()
	proj.set_script(proj_script)

	var source = MockMeteorSource.new()
	var stats = {"source": source}

	# This should NOT crash now
	proj.setup(Vector2.ZERO, null, 10.0, 400.0, "fireball", stats)

	if proj.source_unit == source:
		print("PASS: Source assigned correctly.")
	else:
		print("FAIL: Source assignment failed.")

	proj.queue_free()
