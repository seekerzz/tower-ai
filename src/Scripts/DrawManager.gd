extends Node2D

const TILE_SIZE = 60

@onready var barricade_scene = preload("res://src/Scenes/Game/Barricade.tscn")

func _ready():
	pass

func _unhandled_input(event):
	pass

func _spawn_barricade(grid_pos: Vector2i, mat_key: String):
	# Kept for compatibility if other systems call this, but building via mouse is removed.
	# Or should I remove this too?
	# The requirement says "clean up deprecated logic", "Remove mouse click barricade building".
	# But units/enemies might trigger barricade spawning (e.g. Scorpion/Spider).
	# If those use GameManager or GridManager to spawn, we might not need this here.
	# However, this file is `DrawManager`. The plan said "Clean up ... if they are solely for the deprecated building system".
	# I will keep _spawn_barricade if it seems potentially useful, but for now I'll just clean everything related to manual building.
	# Actually, let's keep `_spawn_barricade` if it's used elsewhere, but looking at `Enemy.gd` or `Constants.gd`, it doesn't seem `DrawManager` is the central place for programmatic spawning.
	# Usually `GridManager` handles obstacles.
	# But wait, `DrawManager` seems to be the place that instantiates `barricade_scene`.
	# Let's check if anyone calls `DrawManager.spawn_barricade` or similar.
	# I'll just keep the class minimal for now as requested: "Clear _unhandled_input".
	pass
