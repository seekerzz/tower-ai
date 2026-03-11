extends Node

const TILE_SIZE = 64
const ANIM_WINDUP_TIME = 0.1
const ANIM_STRIKE_TIME = 0.1
const ANIM_RECOVERY_TIME = 0.1
const ANIM_WINDUP_DIST = 10.0
const ANIM_STRIKE_DIST = 20.0
const ANIM_WINDUP_SCALE = Vector2(0.9, 1.1)
const ANIM_STRIKE_SCALE = Vector2(1.1, 0.9)

const UNIT_TYPES = {
	"test_unit": {
		"hp": 100.0,
		"damage": 10.0,
		"range": 200.0,
		"atkSpeed": 1.5,
		"size": Vector2(1, 1),
		"attackType": "ranged"
	}
}
