extends Node
class_name MeteorShower

var center_pos: Vector2
var damage: float

func setup(pos: Vector2, dmg: float):
	center_pos = pos
	damage = dmg

func _ready():
	_run_meteor_shower()

func _run_meteor_shower():
	if not GameManager.combat_manager:
		queue_free()
		return

	# Wave Loop: 5 Waves, 0.1s interval (using async/await)
	for w in range(5):
		# Spawn Loop: 8 projectiles per wave
		for i in range(8):
			# land_pos: Random point within 1.5 * TILE_SIZE (3x3 grid)
			var spread = 1.5 * Constants.TILE_SIZE
			var offset = Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			var land_pos = center_pos + offset

			# start_pos: land_pos + Vector2(-300, -800) (Angle from top-left)
			var start_pos = land_pos + Vector2(-300, -800)

			var stats = {
				"is_meteor": true,
				"ground_pos": land_pos,
				"pierce": 2,
				"bounce": 0,
				"damage": damage,
				"proj_override": "fireball",
				"damageType": "fire",
				"effects": {}
			}

			# Pass self as source so stats dictionary can be merged smoothly
			# using extra_stats dictionary
			GameManager.combat_manager._spawn_single_projectile(self, start_pos, null, stats)

		await get_tree().create_timer(0.1).timeout

	# Once completed, clean up
	queue_free()

# Properties required by _spawn_single_projectile
var crit_rate: float = 0.0
var crit_dmg: float = 1.5
var guaranteed_crit_stacks: int = 0
var type_key = "phoenix"
var unit_data = {
	"proj": "fireball",
	"damageType": "fire"
}
