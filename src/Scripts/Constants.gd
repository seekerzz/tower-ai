extends Node

const TILE_SIZE = 60
const BENCH_SIZE = 8

const MAP_WIDTH = 9
const MAP_HEIGHT = 9
const CORE_ZONE_RADIUS = 2

const BASE_CORE_HP = 500

const POISON_TICK_INTERVAL = 0.5
const POISON_DAMAGE_RATIO = 0.1
const POISON_MAX_STACKS = 9999
const POISON_TRAP_MULTIPLIER = 1.1
const POISON_TRAP_INTERVAL = 1.0
const POISON_VISUAL_SATURATION_STACKS = 50

# Animation Constants
const ANIM_WINDUP_TIME: float = 0.15
const ANIM_STRIKE_TIME: float = 0.05
const ANIM_RECOVERY_TIME: float = 0.2
const ANIM_WINDUP_DIST: float = 8.0
const ANIM_STRIKE_DIST: float = 20.0
const ANIM_WINDUP_SCALE: Vector2 = Vector2(1.15, 0.85)
const ANIM_STRIKE_SCALE: Vector2 = Vector2(0.85, 1.15)

const COLORS = {
	"bg": Color("#1a1a2e"),
	"grid": Color("#303045"),
	"enemy": Color("#e74c3c"),
	"projectile": Color("#f1c40f"),
	"enemyProjectile": Color("#e91e63"),
	"unlocked": Color("#303045"),
	"locked_inner": Color("#252535"),
	"locked_outer": Color("#151520"),
	"spawn_point": Color("#451515"),
	"core": Color("#4a3045"),
	"border_line": Color("#4a4a58")
}

var CORE_TYPES = {}
var BARRICADE_TYPES = {}
var UNIT_TYPES = {}
var TRAITS = []
var ENEMY_VARIANTS = {}

const ENVIRONMENT_CONFIG = {
	"tree_tile_set": "res://assets/images/UI/tile_trees.png",
	"tree_columns": 3,
	"tree_rows": 3
}

const PLANT_CONFIG = {
	"texture_path": "res://assets/images/UI/tile_flowers.png",
	"rows": 4,
	"columns": 6,
	"min_count": 10,
	"max_count": 20,
	"exclusion_zone": (MAP_WIDTH * TILE_SIZE) / 2.0,
	"min_size": TILE_SIZE * 0.25,
	"max_size": TILE_SIZE * 0.5
}
