extends Node2D

var TILE_SCENE = null
const UNIT_SCENE = preload("res://src/Scenes/Game/Unit.tscn")
const TREE_SCENE = preload("res://src/Scenes/Game/Tree.tscn")
const ENVIRONMENT_DECORATION_SCENE = preload("res://src/Scenes/Game/EnvironmentDecoration.tscn")
var BARRICADE_SCENE = null
const GHOST_TILE_SCRIPT = preload("res://src/Scripts/UI/GhostTile.gd")
const TILE_SIZE = 60

var tiles: Dictionary = {} # Key: "x,y", Value: Tile Instance
var obstacles: Dictionary = {} # Key: Vector2i, Value: Obstacle
var obstacle_map: Dictionary = {} # Key: Node, Value: Vector2i (Grid Pos)
var ghost_tiles: Array = []
var expansion_mode: bool = false
var expansion_cost: int = 50 # Base cost
var spawn_tiles: Array = [] # List of tiles (Vector2i) used as spawn points
var active_territory_tiles: Array = [] # List of Tile instances that are unlocked or core

@export var border_margin: float = 8.0

# Interaction / Skill Targeting
var placement_preview_cursor: Node2D = null
var last_preview_frame: int = 0

# Interaction System (Neighbor Buff Selection)
const STATE_IDLE = 0
const STATE_SELECTING_INTERACTION_TARGET = 1
const STATE_SKILL_TARGETING = 2
const STATE_SEQUENCE_TRAP_PLACEMENT = 3

var interaction_state: int = STATE_IDLE
var interaction_source_unit = null
var skill_source_unit: Node2D = null
var skill_preview_node: Node2D = null

var valid_interaction_targets: Array = [] # Array[Vector2i]
var interaction_highlights: Array = [] # Array[Node2D] (Visuals)

# Overlay for Provider Buff Icons
var provider_icon_overlay: Node2D = null
var selection_overlay: Node2D = null
var astar_grid: AStarGrid2D

signal grid_updated

func _ready():
	GameManager.grid_manager = self

	selection_overlay = Node2D.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.z_index = 100
	selection_overlay.draw.connect(_on_selection_overlay_draw)
	add_child(selection_overlay)

	provider_icon_overlay = Node2D.new()
	provider_icon_overlay.name = "ProviderIconOverlay"
	provider_icon_overlay.z_index = 99
	add_child(provider_icon_overlay)

	TILE_SCENE = load("res://src/Scenes/Game/Tile.tscn")
	if ResourceLoader.exists("res://src/Scenes/Game/Barricade.tscn"):
		BARRICADE_SCENE = load("res://src/Scenes/Game/Barricade.tscn")
	_init_astar()
	create_initial_grid()
	_create_map_boundaries()
	_setup_tree_border()
	_setup_border_visual()
	# _generate_random_obstacles()
	call_deferred("_setup_plant_decorations")

func grid_to_local(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)

func local_to_grid(local_pos: Vector2) -> Vector2i:
	return Vector2i(round(local_pos.x / TILE_SIZE), round(local_pos.y / TILE_SIZE))

func _setup_border_visual():
	var border_line = Line2D.new()
	border_line.name = "BorderLine"
	border_line.z_index = -10
	border_line.width = 3.0
	border_line.antialiased = true
	border_line.default_color = Constants.COLORS.border_line
	add_child(border_line)

	var half_grid_w = floor(Constants.MAP_WIDTH / 2.0)
	var half_grid_h = floor(Constants.MAP_HEIGHT / 2.0)
	var min_grid_pos = Vector2i(-half_grid_w, -half_grid_h)
	var max_grid_pos = Vector2i(half_grid_w, half_grid_h)
	var top_left = grid_to_local(min_grid_pos) - Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0) - Vector2(border_margin, border_margin)
	var bottom_right = grid_to_local(max_grid_pos) + Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0) + Vector2(border_margin, border_margin)

	var rect = Rect2(top_left, bottom_right - top_left)
	var radius = 15.0

	var points = _generate_rounded_rect_path(rect, radius)
	points = _subdivide_path(points, 10.0)
	points = _apply_jitter_to_path(points, 1.5)

	border_line.points = points

	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.25, 0.9))
	curve.add_point(Vector2(0.5, 1.2))
	curve.add_point(Vector2(0.75, 1.1))
	curve.add_point(Vector2(1, 1))
	border_line.width_curve = curve

func _generate_rounded_rect_path(rect: Rect2, r: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 8 # Number of segments for corner

	# Top Left Corner
	var c_tl = rect.position + Vector2(r, r)
	for i in range(steps + 1):
		var angle = PI + (PI / 2.0 * i / steps)
		points.append(c_tl + Vector2(cos(angle), sin(angle)) * r)

	# Top Right Corner
	var c_tr = rect.position + Vector2(rect.size.x - r, r)
	for i in range(steps + 1):
		var angle = 1.5 * PI + (PI / 2.0 * i / steps)
		points.append(c_tr + Vector2(cos(angle), sin(angle)) * r)

	# Bottom Right Corner
	var c_br = rect.position + Vector2(rect.size.x - r, rect.size.y - r)
	for i in range(steps + 1):
		var angle = 0.0 + (PI / 2.0 * i / steps)
		points.append(c_br + Vector2(cos(angle), sin(angle)) * r)

	# Bottom Left Corner
	var c_bl = rect.position + Vector2(r, rect.size.y - r)
	for i in range(steps + 1):
		var angle = 0.5 * PI + (PI / 2.0 * i / steps)
		points.append(c_bl + Vector2(cos(angle), sin(angle)) * r)

	# Close the loop
	points.append(points[0])

	return points

func _subdivide_path(points: PackedVector2Array, min_segment_len: float) -> PackedVector2Array:
	var new_points = PackedVector2Array()
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i+1]
		var dist = p1.distance_to(p2)
		var segments = ceil(dist / min_segment_len)

		for j in range(segments):
			var t = j / segments
			new_points.append(p1.lerp(p2, t))

	new_points.append(points[-1])
	return new_points

func _apply_jitter_to_path(points: PackedVector2Array, magnitude: float) -> PackedVector2Array:
	var new_points = PackedVector2Array()

	for i in range(points.size() - 1):
		var p = points[i]

		var prev = points[(i - 1 + points.size()) % points.size()]
		var next = points[(i + 1) % points.size()]
		var tangent = (next - prev).normalized()
		var normal = Vector2(-tangent.y, tangent.x)

		var offset = normal * randf_range(-magnitude, magnitude)
		new_points.append(p + offset)

	new_points.append(new_points[0])

	return new_points

func _setup_plant_decorations(texture_path: String = Constants.PLANT_CONFIG.texture_path):
	var plant_container = Node2D.new()
	plant_container.name = "PlantContainer"
	plant_container.z_index = -50
	plant_container.y_sort_enabled = true
	add_child(plant_container)

	if not ResourceLoader.exists(texture_path):
		return

	var tex = load(texture_path)
	if not tex:
		print("Warning: Plant texture not found at ", texture_path)
		return

	var min_count = Constants.PLANT_CONFIG.min_count
	var max_count = Constants.PLANT_CONFIG.max_count
	var count = randi_range(min_count, max_count)

	var exclusion_zone = Constants.PLANT_CONFIG.exclusion_zone

	var bounds_rect = Rect2()
	var bg_found = false

	if GameManager.main_game and is_instance_valid(GameManager.main_game) and GameManager.main_game.background:
		var bg = GameManager.main_game.background
		if bg.texture:
			var bg_size = bg.texture.get_size() * bg.scale
			var half_w = bg_size.x / 2.0
			var half_h = bg_size.y / 2.0
			bounds_rect = Rect2(-half_w, -half_h, bg_size.x, bg_size.y)
			bg_found = true

	if not bg_found:
		var map_w = Constants.MAP_WIDTH * Constants.TILE_SIZE
		var map_h = Constants.MAP_HEIGHT * Constants.TILE_SIZE
		var size_mult = 2.0
		var w = map_w * size_mult
		var h = map_h * size_mult
		bounds_rect = Rect2(-w/2.0, -h/2.0, w, h)

	for i in range(count):
		var valid_pos = false
		var pos = Vector2.ZERO
		var attempts = 0
		while not valid_pos and attempts < 50:
			attempts += 1
			var x = randf_range(bounds_rect.position.x, bounds_rect.end.x)
			var y = randf_range(bounds_rect.position.y, bounds_rect.end.y)

			if abs(x) < exclusion_zone and abs(y) < exclusion_zone:
				continue

			pos = Vector2(x, y)
			valid_pos = true

		if valid_pos:
			var decoration = ENVIRONMENT_DECORATION_SCENE.instantiate()
			plant_container.add_child(decoration)

			decoration.position = pos

			var hframes = Constants.PLANT_CONFIG.columns
			var vframes = Constants.PLANT_CONFIG.rows
			var frame = randi() % (hframes * vframes)
			var flip_h = randf() > 0.5

			var target_size = randf_range(Constants.PLANT_CONFIG.min_size, Constants.PLANT_CONFIG.max_size)
			var frame_width = tex.get_width() / float(hframes)
			var scale_val = 1.0
			if frame_width > 0:
				scale_val = target_size / frame_width

			decoration.setup_visuals(tex, hframes, vframes, frame, flip_h, scale_val)

func _setup_tree_border():
	print("Generating tree border (Refactored)...")

	var T = float(Constants.TILE_SIZE)
	var Ex = (Constants.MAP_WIDTH * T) / 2.0
	var Ey = (Constants.MAP_HEIGHT * T) / 2.0
	var Omax = T / 2.0
	var Gmax = T
	var Rmargin = T / 6.0

	var N = randi_range(4, 6)
	var sides = ["Top", "Bottom", "Left", "Right"]
	var extra = N - 4
	for i in range(extra):
		sides.append(["Top", "Bottom", "Left", "Right"].pick_random())

	var placed_trees = []
	var occupied_grid_cells = {}

	for side in sides:
		var tree = TREE_SCENE.instantiate()
		var w_factor = randi_range(2, 4)
		tree.setup(w_factor)
		var size = tree.get_pixel_size()
		var W = size.x
		var H = size.y

		var attempts = 0
		var success = false
		var pos = Vector2.ZERO

		var corner_limit_x = Ex - T
		var corner_limit_y = Ey - T

		while attempts < 10 and not success:
			attempts += 1

			var x_cand = 0.0
			var y_cand = 0.0

			if side == "Top":
				y_cand = randf_range(-Ey - Gmax, -Ey - Rmargin)
				x_cand = randf_range(-corner_limit_x, corner_limit_x)
			elif side == "Bottom":
				y_cand = randf_range(Ey + H - Omax, Ey + H + Gmax)
				x_cand = randf_range(-corner_limit_x, corner_limit_x)
			elif side == "Left":
				x_cand = randf_range(-Ex - W/2 - Gmax, -Ex - W/2 + Omax)
				y_cand = randf_range(-corner_limit_y, corner_limit_y)
			elif side == "Right":
				x_cand = randf_range(Ex + W/2 - Omax, Ex + W/2 + Gmax)
				y_cand = randf_range(-corner_limit_y, corner_limit_y)

			pos = Vector2(x_cand, y_cand)

			if abs(pos.x) > corner_limit_x and abs(pos.y) > corner_limit_y:
				continue

			var grid_pos = local_to_grid(pos)
			if occupied_grid_cells.has(grid_pos):
				continue

			var new_rect = Rect2(pos.x - W/2, pos.y - H, W, H)
			var overlap_fail = false

			for p_tree in placed_trees:
				var old_rect = p_tree.rect
				if new_rect.intersects(old_rect):
					var intersection = new_rect.intersection(old_rect)
					var area_int = intersection.get_area()
					var area_new = new_rect.get_area()
					if area_int > (area_new / 3.0):
						overlap_fail = true
						break

			if overlap_fail:
				continue

			success = true

		if success:
			add_child(tree)
			tree.position = pos
			if tree.has_method("update_z_index"):
				tree.update_z_index()

			var rect = Rect2(pos.x - W/2, pos.y - H, W, H)
			placed_trees.append({"rect": rect, "node": tree})
			occupied_grid_cells[local_to_grid(pos)] = true
		else:
			tree.queue_free()

func _create_map_boundaries():
	var border_body = StaticBody2D.new()
	border_body.name = "MapBorder"
	border_body.collision_layer = 1
	border_body.collision_mask = 0
	add_child(border_body)

	var map_w_pixels = Constants.MAP_WIDTH * TILE_SIZE
	var map_h_pixels = Constants.MAP_HEIGHT * TILE_SIZE
	var wall_thickness = 100.0

	var top_shape = CollisionShape2D.new()
	var top_rect = RectangleShape2D.new()
	top_rect.size = Vector2(map_w_pixels + wall_thickness * 2, wall_thickness)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0, -map_h_pixels/2.0 - wall_thickness/2.0)
	border_body.add_child(top_shape)

	var bot_shape = CollisionShape2D.new()
	var bot_rect = RectangleShape2D.new()
	bot_rect.size = Vector2(map_w_pixels + wall_thickness * 2, wall_thickness)
	bot_shape.shape = bot_rect
	bot_shape.position = Vector2(0, map_h_pixels/2.0 + wall_thickness/2.0)
	border_body.add_child(bot_shape)

	var left_shape = CollisionShape2D.new()
	var left_rect = RectangleShape2D.new()
	left_rect.size = Vector2(wall_thickness, map_h_pixels + wall_thickness * 2)
	left_shape.shape = left_rect
	left_shape.position = Vector2(-map_w_pixels/2.0 - wall_thickness/2.0, 0)
	border_body.add_child(left_shape)

	var right_shape = CollisionShape2D.new()
	var right_rect = RectangleShape2D.new()
	right_rect.size = Vector2(wall_thickness, map_h_pixels + wall_thickness * 2)
	right_shape.shape = right_rect
	right_shape.position = Vector2(map_w_pixels/2.0 + wall_thickness/2.0, 0)
	border_body.add_child(right_shape)

func _process(_delta):
	_update_environment_shader_globals()

	if placement_preview_cursor and placement_preview_cursor.visible:
		var dist = get_global_mouse_position().distance_to(placement_preview_cursor.global_position)
		var frame_diff = Engine.get_process_frames() - last_preview_frame

		if dist > 50.0 and frame_diff > 10:
			print("[Debug] Hiding preview cursor. Dist: ", dist, " Frames: ", frame_diff)
			placement_preview_cursor.visible = false

	if interaction_state == STATE_SELECTING_INTERACTION_TARGET:
		selection_overlay.queue_redraw()

	if interaction_state == STATE_SEQUENCE_TRAP_PLACEMENT:
		_process_trap_placement_preview()

	if interaction_state == STATE_SKILL_TARGETING and skill_preview_node and is_instance_valid(skill_preview_node):
		var mouse_pos = get_local_mouse_position()
		var gx = round(mouse_pos.x / TILE_SIZE)
		var gy = round(mouse_pos.y / TILE_SIZE)
		skill_preview_node.position = grid_to_local(Vector2i(gx, gy))

func _update_environment_shader_globals():
	var plant_container = get_node_or_null("PlantContainer")
	if plant_container and plant_container.get_child_count() > 0:
		var first_deco = plant_container.get_child(0)
		if first_deco.has_node("Sprite2D"):
			var sprite = first_deco.get_node("Sprite2D")
			var mat = sprite.material as ShaderMaterial
			if mat:
				var cam_pos = Vector2.ZERO
				var cam = get_viewport().get_camera_2d()
				if cam:
					cam_pos = cam.global_position
				mat.set_shader_parameter("camera_global_pos", cam_pos)

func _input(event):
	match interaction_state:
		STATE_SKILL_TARGETING:
			_handle_input_skill_targeting(event)
		STATE_SELECTING_INTERACTION_TARGET:
			_handle_input_interaction_selection(event)
		STATE_SEQUENCE_TRAP_PLACEMENT:
			_handle_input_trap_placement(event)
		STATE_IDLE:
			_handle_input_idle(event)
		_:
			_handle_input_idle(event)

func _handle_input_skill_targeting(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos_global = get_global_mouse_position()
			var mouse_pos = get_local_mouse_position()
			var gx = int(round(mouse_pos.x / TILE_SIZE))
			var gy = int(round(mouse_pos.y / TILE_SIZE))

			if skill_source_unit and is_instance_valid(skill_source_unit):
				skill_source_unit.execute_skill_at(Vector2i(gx, gy))

			exit_skill_targeting()
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			exit_skill_targeting()
			get_viewport().set_input_as_handled()

func _handle_input_interaction_selection(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_local_mouse_position()
			var gx = int(round(mouse_pos.x / TILE_SIZE))
			var gy = int(round(mouse_pos.y / TILE_SIZE))
			var grid_pos = Vector2i(gx, gy)

			if grid_pos in valid_interaction_targets:
				if interaction_source_unit and is_instance_valid(interaction_source_unit):
					interaction_source_unit.interaction_target_pos = grid_pos
					recalculate_buffs()

					# Interaction Feedback
					var targets = [grid_pos]
					if interaction_source_unit.unit_data.get("interaction_pattern") == "neighbor_pair":
						var neighbors = _get_clockwise_neighbors(interaction_source_unit.grid_pos)
						var idx = neighbors.find(grid_pos)
						if idx != -1:
							var next_idx = (idx + 1) % neighbors.size()
							targets.append(neighbors[next_idx])

					for target_pos in targets:
						var key = get_tile_key(target_pos.x, target_pos.y)
						if tiles.has(key):
							var tile = tiles[key]
							var u = tile.unit
							if u == null and tile.occupied_by != Vector2i.ZERO:
								var origin_key = get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
								if tiles.has(origin_key):
									u = tiles[origin_key].unit

							if u and is_instance_valid(u):
								u.play_buff_receive_anim()
								var buff_icon = interaction_source_unit._get_buff_icon(interaction_source_unit.get_interaction_info().buff_id)
								u.spawn_buff_effect(buff_icon)

				end_interaction_selection()
				get_viewport().set_input_as_handled()
			else:
				end_interaction_selection()
				get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_deployment_sequence()
			get_viewport().set_input_as_handled()

func _handle_input_idle(event):
	pass

func update_placement_preview(grid_pos: Vector2i, world_pos: Vector2, item_id: String):
	if not placement_preview_cursor:
		placement_preview_cursor = Node2D.new()
		placement_preview_cursor.name = "PlacementPreviewCursor"
		var visual = ColorRect.new()
		visual.name = "Visual"
		visual.size = Vector2(TILE_SIZE, TILE_SIZE)
		visual.position = -visual.size / 2
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placement_preview_cursor.add_child(visual)
		add_child(placement_preview_cursor)

	placement_preview_cursor.global_position = world_pos
	placement_preview_cursor.visible = true

	var is_valid = can_place_item_at(grid_pos, item_id)
	var visual = placement_preview_cursor.get_node("Visual")
	if is_valid:
		visual.color = Color(0, 1, 0, 0.4)
	else:
		visual.color = Color(1, 0, 0, 0.4)

	last_preview_frame = Engine.get_process_frames()

func can_place_item_at(grid_pos: Vector2i, item_id: String) -> bool:
	var key = get_tile_key(grid_pos.x, grid_pos.y)
	if !tiles.has(key): return false

	var tile = tiles[key]

	if "trap" in item_id or item_id == "poison" or item_id == "fang" or Constants.BARRICADE_TYPES.has(item_id):
		if obstacles.has(grid_pos): return false
		if tile.unit != null: return false
		if tile.occupied_by != Vector2i.ZERO: return false

		return true

	return false

func spawn_trap_custom(grid_pos: Vector2i, type_key: String):
	var key = get_tile_key(grid_pos.x, grid_pos.y)
	if !tiles.has(key): return
	var tile = tiles[key]
	_spawn_barricade(tile, type_key)

func try_spawn_trap(world_pos: Vector2, type_key: String):
	var gx = int(round(world_pos.x / TILE_SIZE))
	var gy = int(round(world_pos.y / TILE_SIZE))
	var grid_pos = Vector2i(gx, gy)
	var key = get_tile_key(gx, gy)

	if not tiles.has(key):
		return

	var tile = tiles[key]
	if tile.unit != null: return
	if tile.occupied_by != Vector2i.ZERO: return
	if tile.type == "core": return
	if obstacles.has(grid_pos): return

	var data = Constants.BARRICADE_TYPES[type_key]
	var obstacle

	if BARRICADE_SCENE:
		obstacle = BARRICADE_SCENE.instantiate()
	else:
		obstacle = Node2D.new()
		obstacle.name = "Obstacle_" + type_key
		var visual = ColorRect.new()
		visual.size = Vector2(40, 40)
		visual.position = Vector2(-20, -20)
		if "color" in data:
			visual.color = data["color"]
		else:
			visual.color = Color.DARK_SLATE_GRAY
		obstacle.add_child(visual)

	add_child(obstacle)
	obstacle.position = tile.position

	if obstacle.has_method("init"):
		obstacle.init(Vector2i(tile.x, tile.y), type_key)

	register_obstacle(Vector2i(tile.x, tile.y), obstacle)

func _init_astar():
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(
		-Constants.MAP_WIDTH / 2,
		-Constants.MAP_HEIGHT / 2,
		Constants.MAP_WIDTH,
		Constants.MAP_HEIGHT
	)
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()

	if GameManager.has_signal("wave_started"):
		GameManager.wave_started.connect(func():
			expansion_mode = false
			clear_ghosts()
		)

func create_initial_grid():
	for key in tiles:
		tiles[key].queue_free()
	tiles.clear()
	spawn_tiles.clear()
	active_territory_tiles.clear()

	var half_w = Constants.MAP_WIDTH / 2
	var half_h = Constants.MAP_HEIGHT / 2

	var chosen_spawns = []
	var corners = [
		Vector2i(-half_w, -half_h),
		Vector2i(half_w, -half_h),
		Vector2i(-half_w, half_h),
		Vector2i(half_w, half_h)
	]

	for corner in corners:
		chosen_spawns.append(corner)
		var dx = 1 if corner.x < 0 else -1
		var dy = 1 if corner.y < 0 else -1
		chosen_spawns.append(Vector2i(corner.x + dx, corner.y))
		chosen_spawns.append(Vector2i(corner.x + dx * 2, corner.y))
		chosen_spawns.append(Vector2i(corner.x, corner.y + dy))
		chosen_spawns.append(Vector2i(corner.x, corner.y + dy * 2))

	for x in range(-half_w, half_w + 1):
		for y in range(-half_h, half_h + 1):
			var type = "wilderness"
			var state = "locked_inner"

			if abs(x) <= Constants.CORE_ZONE_RADIUS and abs(y) <= Constants.CORE_ZONE_RADIUS:
				type = "core_zone"
				state = "locked_inner"
				if x == 0 and y == 0:
					type = "core"
					state = "unlocked"
			else:
				type = "wilderness"
				state = "locked_outer"

			if (x == 0 and y == 0) or \
			   (x == 0 and abs(y) == 1) or \
			   (y == 0 and abs(x) == 1):
				state = "unlocked"
				if type == "wilderness":
					type = "normal"
				elif type == "core_zone":
					type = "normal"
				if x == 0 and y == 0:
					type = "core"

			if Vector2i(x,y) in chosen_spawns:
				state = "spawn"
				spawn_tiles.append(Vector2i(x,y))

			create_tile(x, y, type, state)

	print("Total Spawn Tiles: ", spawn_tiles.size())

func create_tile(x: int, y: int, type: String = "normal", state: String = "locked_inner"):
	var key = get_tile_key(x, y)
	if tiles.has(key): return

	var tile = TILE_SCENE.instantiate()
	tile.setup(x, y, type)
	tile.set_state(state)

	tile.position = grid_to_local(Vector2i(x, y))
	add_child(tile)
	tiles[key] = tile

	if state == "unlocked" or type == "core":
		if not active_territory_tiles.has(tile):
			active_territory_tiles.append(tile)

	tile.tile_clicked.connect(_on_tile_clicked)

	var grid_pos = Vector2i(x, y)
	if astar_grid.is_in_boundsv(grid_pos):
		astar_grid.set_point_weight_scale(grid_pos, 1.0)

func _generate_random_obstacles():
	var candidate_tiles = []
	for key in tiles:
		var tile = tiles[key]
		if tile.state == "locked_outer":
			candidate_tiles.append(tile)

	var obstacle_count = randi_range(10, 15)
	obstacle_count = min(obstacle_count, candidate_tiles.size())
	candidate_tiles.shuffle()

	var placed_count = 0
	for i in range(candidate_tiles.size()):
		if placed_count >= obstacle_count: break

		var tile = candidate_tiles[i]
		var type_keys = Constants.BARRICADE_TYPES.keys()
		var type_key = type_keys.pick_random()

		_spawn_barricade(tile, type_key)
		placed_count += 1

func is_path_clear_from_spawns_to_core() -> bool:
	var core_pos = Vector2i(0, 0)
	if obstacles.has(core_pos): return false

	for spawn_pos in spawn_tiles:
		var path = astar_grid.get_id_path(spawn_pos, core_pos)
		if path.size() == 0:
			return false
	return true

func _spawn_barricade(tile, type_key):
	var data = Constants.BARRICADE_TYPES[type_key]
	var obstacle

	if BARRICADE_SCENE:
		obstacle = BARRICADE_SCENE.instantiate()
	else:
		obstacle = Node2D.new()
		obstacle.name = "Obstacle_" + type_key
		var visual = ColorRect.new()
		visual.size = Vector2(40, 40)
		visual.position = Vector2(-20, -20)
		if "color" in data:
			visual.color = data["color"]
		else:
			visual.color = Color.DARK_SLATE_GRAY
		obstacle.add_child(visual)

	add_child(obstacle)
	obstacle.position = tile.position

	if obstacle.has_method("init"):
		obstacle.init(Vector2i(tile.x, tile.y), type_key)

	register_obstacle(Vector2i(tile.x, tile.y), obstacle)

func register_obstacle(grid_pos: Vector2i, node: Node):
	if astar_grid.is_in_boundsv(grid_pos):
		astar_grid.set_point_solid(grid_pos, false)
		astar_grid.set_point_weight_scale(grid_pos, 1.0)

	obstacle_map[node] = grid_pos
	obstacles[grid_pos] = node

func remove_obstacle(node: Node):
	if not obstacle_map.has(node):
		return
	var grid_pos = obstacle_map[node]
	obstacles.erase(grid_pos)
	obstacle_map.erase(node)

func get_nav_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var start_grid = Vector2i(round(start_pos.x / TILE_SIZE), round(start_pos.y / TILE_SIZE))
	var end_grid = Vector2i(round(end_pos.x / TILE_SIZE), round(end_pos.y / TILE_SIZE))

	if not astar_grid.is_in_boundsv(start_grid) or not astar_grid.is_in_boundsv(end_grid):
		return PackedVector2Array()

	return astar_grid.get_point_path(start_grid, end_grid)

func get_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for tile_pos in spawn_tiles:
		var local_pos = grid_to_local(tile_pos)
		points.append(to_global(local_pos))
	return points

func get_tile_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func get_world_pos_from_grid(grid_pos: Vector2i) -> Vector2:
	return to_global(grid_to_local(grid_pos))

# --- Unit Logic ---

func place_unit(unit_key: String, x: int, y: int) -> bool:
	var key = get_tile_key(x, y)
	if !tiles.has(key): return false

	var tile = tiles[key]

	# Instantiate unit first to check behavior capabilities
	var unit = UNIT_SCENE.instantiate()
	if unit_key == "wolf":
		unit.set_script(load("res://src/Scripts/Units/Wolf/UnitWolf.gd"))
	unit.setup(unit_key)

	# Check overlapping unit for Attachment (e.g. Oxpecker)
	var target_unit = tile.unit
	if target_unit == null and tile.occupied_by != Vector2i.ZERO:
		var origin_key = get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
		if tiles.has(origin_key):
			target_unit = tiles[origin_key].unit

	if target_unit:
		if unit.behavior.has_method("can_attach_to") and unit.behavior.can_attach_to(target_unit):
			unit.behavior.perform_attach(target_unit)
			recalculate_buffs()
			return true

		# Failed overlap
		unit.queue_free()
		return false

	if tile.unit != null or tile.occupied_by != Vector2i.ZERO:
		unit.queue_free()
		return false

	var w = unit.unit_data.size.x
	var h = unit.unit_data.size.y

	if !can_place_unit(x, y, w, h):
		unit.queue_free()
		return false

	add_child(unit)
	unit.position = grid_to_local(Vector2i(x,y)) + Vector2((w-1) * TILE_SIZE * 0.5, (h-1) * TILE_SIZE * 0.5)

	unit.start_position = unit.position
	unit.grid_pos = Vector2i(x, y)

	_set_tiles_occupied(x, y, w, h, unit)

	if unit.unit_data.get("trait") in ["reflect", "flat_reduce"]:
		register_obstacle(Vector2i(x, y), unit)

	recalculate_buffs()
	GameManager.recalculate_max_health()

	var info = unit.get_interaction_info()

	# If trap placement sequence started by on_setup, interaction_state will be set.
	# Only start interaction selection if idle.
	if interaction_state == STATE_IDLE and info.has_interaction:
		start_interaction_selection(unit)

	return true

func _set_tiles_occupied(x: int, y: int, w: int, h: int, unit):
	for dx in range(w):
		for dy in range(h):
			var t_key = get_tile_key(x + dx, y + dy)
			if tiles.has(t_key):
				var t = tiles[t_key]
				if dx == 0 and dy == 0:
					t.unit = unit
				else:
					t.occupied_by = Vector2i(x, y)

func _clear_tiles_occupied(x: int, y: int, w: int, h: int):
	for dx in range(w):
		for dy in range(h):
			var t_key = get_tile_key(x + dx, y + dy)
			if tiles.has(t_key):
				var t = tiles[t_key]
				t.unit = null
				t.occupied_by = Vector2i.ZERO

func is_in_core_zone(pos: Vector2i) -> bool:
	return abs(pos.x) <= Constants.CORE_ZONE_RADIUS and abs(pos.y) <= Constants.CORE_ZONE_RADIUS

# --- Skill Targeting ---

func enter_skill_targeting(unit: Node2D):
	exit_skill_targeting()

	interaction_state = STATE_SKILL_TARGETING
	skill_source_unit = unit

	skill_preview_node = Node2D.new()
	skill_preview_node.name = "SkillPreview"
	skill_preview_node.z_index = 100

	for x in range(-1, 2):
		for y in range(-1, 2):
			var rect = ColorRect.new()
			rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			rect.position = Vector2(x * TILE_SIZE, y * TILE_SIZE) - Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)
			rect.color = Color(0, 1, 0, 0.4)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skill_preview_node.add_child(rect)

	add_child(skill_preview_node)

func exit_skill_targeting():
	if skill_preview_node:
		skill_preview_node.queue_free()
		skill_preview_node = null

	interaction_state = STATE_IDLE
	skill_source_unit = null

# --- Interaction System Implementation ---

func _get_clockwise_neighbors(center_pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	# Clockwise order: Up, Up-Right, Right, Down-Right, Down, Down-Left, Left, Up-Left
	var offsets = [
		Vector2i(0, -1),   # Up
		Vector2i(1, -1),   # Up-Right
		Vector2i(1, 0),    # Right
		Vector2i(1, 1),    # Down-Right
		Vector2i(0, 1),    # Down
		Vector2i(-1, 1),   # Down-Left
		Vector2i(-1, 0),   # Left
		Vector2i(-1, -1)   # Up-Left
	]

	for offset in offsets:
		neighbors.append(center_pos + offset)

	return neighbors

func is_neighbor(unit, target_pos: Vector2i) -> bool:
	var cx = unit.grid_pos.x
	var cy = unit.grid_pos.y
	var w = unit.unit_data.size.x
	var h = unit.unit_data.size.y

	if target_pos.x >= cx - 1 and target_pos.x < cx + w + 1:
		if target_pos.y >= cy - 1 and target_pos.y < cy + h + 1:
			if target_pos.x >= cx and target_pos.x < cx + w and target_pos.y >= cy and target_pos.y < cy + h:
				return false
			return true
	return false

func start_interaction_selection(unit):
	interaction_state = STATE_SELECTING_INTERACTION_TARGET
	interaction_source_unit = unit
	valid_interaction_targets.clear()

	var cx = unit.grid_pos.x
	var cy = unit.grid_pos.y

	var neighbors = []
	var w = unit.unit_data.size.x
	var h = unit.unit_data.size.y

	for dx in range(-1, w + 1):
		neighbors.append(Vector2i(cx + dx, cy - 1))
		neighbors.append(Vector2i(cx + dx, cy + h))

	for dy in range(0, h):
		neighbors.append(Vector2i(cx - 1, cy + dy))
		neighbors.append(Vector2i(cx + w, cy + dy))

	for pos in neighbors:
		if is_valid_interaction_target(unit, pos):
			valid_interaction_targets.append(pos)
			var color = Color.GREEN
			if unit.unit_data.get("buff_id") == "multishot":
				color = Color(0, 1, 1, 0.4)
			_spawn_interaction_highlight(pos, color)
		else:
			_spawn_interaction_highlight(pos, Color.RED)

func is_valid_interaction_target(origin_unit, target_pos: Vector2i) -> bool:
	var key = get_tile_key(target_pos.x, target_pos.y)
	if !tiles.has(key): return false
	var tile = tiles[key]

	if !is_in_core_zone(target_pos): return false
	if tile.state != "unlocked" and tile.type != "core": return false

	return true

func end_interaction_selection():
	interaction_state = STATE_IDLE
	interaction_source_unit = null
	valid_interaction_targets.clear()
	for node in interaction_highlights:
		node.queue_free()
	interaction_highlights.clear()
	selection_overlay.queue_redraw()

func _spawn_interaction_highlight(grid_pos: Vector2i, color: Color = Color(1, 0.84, 0, 0.4)):
	var highlight = ColorRect.new()
	highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
	highlight.color = color
	highlight.color.a = 0.4

	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(highlight)

	var local_pos = grid_to_local(grid_pos)
	highlight.position = local_pos - Vector2(TILE_SIZE, TILE_SIZE) / 2
	interaction_highlights.append(highlight)

func _on_selection_overlay_draw():
	if interaction_state == STATE_SELECTING_INTERACTION_TARGET and interaction_source_unit and is_instance_valid(interaction_source_unit):
		# Dynamic Cursor Logic
		var mouse_pos = get_local_mouse_position()
		var gx = int(round(mouse_pos.x / TILE_SIZE))
		var gy = int(round(mouse_pos.y / TILE_SIZE))
		var grid_pos = Vector2i(gx, gy)

		var buff_id = interaction_source_unit.get_interaction_info().buff_id
		var icon_char = interaction_source_unit._get_buff_icon(buff_id)
		var font = ThemeDB.fallback_font
		var font_size = 24

		var draw_positions = []
		var is_valid = grid_pos in valid_interaction_targets
		var color = Color.WHITE

		if is_valid:
			draw_positions.append(grid_pos)
			if interaction_source_unit.unit_data.get("interaction_pattern") == "neighbor_pair":
				var neighbors = _get_clockwise_neighbors(interaction_source_unit.grid_pos)
				var idx = neighbors.find(grid_pos)
				if idx != -1:
					var next_idx = (idx + 1) % neighbors.size()
					draw_positions.append(neighbors[next_idx])
		else:
			draw_positions.append(grid_pos)
			color = Color(0.5, 0.5, 0.5, 0.5)

		for pos in draw_positions:
			var snap_pos = grid_to_local(pos)
			selection_overlay.draw_string(font, snap_pos + Vector2(-10, 10), icon_char, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func show_provider_icons(provider_unit: Node2D):
	hide_provider_icons()
	if !provider_unit: return

	# Determine receivers logic (same as _apply_buff_to_neighbors or specific)
	var buff_type = ""
	if "buffProvider" in provider_unit.unit_data:
		buff_type = provider_unit.unit_data["buffProvider"]

	# If provider is interactive type, it gives buff to specific target
	var info = provider_unit.get_interaction_info()
	if info.has_interaction:
		if provider_unit.interaction_target_pos != null:
			# Single target
			_spawn_provider_icon_at(provider_unit.interaction_target_pos, info.buff_id, provider_unit)
			return

	if buff_type == "": return

	# Default neighbor logic
	var cx = provider_unit.grid_pos.x
	var cy = provider_unit.grid_pos.y
	var w = provider_unit.unit_data.size.x
	var h = provider_unit.unit_data.size.y

	var neighbors = []
	for dx in range(w):
		neighbors.append(Vector2i(cx + dx, cy - 1))
		neighbors.append(Vector2i(cx + dx, cy + h))
	for dy in range(h):
		neighbors.append(Vector2i(cx - 1, cy + dy))
		neighbors.append(Vector2i(cx + w, cy + dy))

	for n_pos in neighbors:
		_spawn_provider_icon_at(n_pos, buff_type, provider_unit)

func _spawn_provider_icon_at(grid_pos: Vector2i, buff_type: String, provider_unit: Node2D):
	var key = get_tile_key(grid_pos.x, grid_pos.y)
	if tiles.has(key):
		var tile = tiles[key]
		var target_unit = tile.unit
		if target_unit == null and tile.occupied_by != Vector2i.ZERO:
			var origin_key = get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
			if tiles.has(origin_key):
				target_unit = tiles[origin_key].unit

		if target_unit and target_unit != provider_unit:
			# Validate that target actually received the buff from this provider
			var received = false
			if target_unit.buff_sources.has(buff_type):
				if target_unit.buff_sources[buff_type] == provider_unit:
					received = true

			if not received: return

			# Draw icon
			var lbl = Label.new()
			lbl.text = provider_unit._get_buff_icon(buff_type)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			lbl.position = grid_to_local(grid_pos) - Vector2(20, 20) # Center
			lbl.size = Vector2(40, 40)

			provider_icon_overlay.add_child(lbl)

func hide_provider_icons():
	for child in provider_icon_overlay.get_children():
		child.queue_free()

func can_place_unit(x: int, y: int, w: int, h: int, exclude_unit = null) -> bool:
	for dx in range(w):
		for dy in range(h):
			var pos = Vector2i(x + dx, y + dy)
			var key = get_tile_key(x + dx, y + dy)
			if !tiles.has(key): return false
			var tile = tiles[key]
			if tile.state != "unlocked": return false
			if tile.type == "core": return false
			if tile.unit and tile.unit != exclude_unit: return false
			if obstacles.has(pos): return false
			if tile.occupied_by != Vector2i.ZERO:
				if exclude_unit and tile.occupied_by == exclude_unit.grid_pos:
					continue
				return false
	return true

func _on_tile_clicked(tile):
	if GameManager.is_wave_active: return
	# print("Clicked tile: ", tile.x, ",", tile.y)

func remove_unit_from_grid(unit):
	if unit == null: return
	var w = unit.unit_data.size.x
	var h = unit.unit_data.size.y

	if unit.unit_data.get("trait") in ["reflect", "flat_reduce"]:
		remove_obstacle(unit)

	# Clean up associated traps
	if "associated_traps" in unit and unit.associated_traps:
		for trap in unit.associated_traps:
			if is_instance_valid(trap):
				remove_obstacle(trap)
				trap.queue_free()
		unit.associated_traps.clear()

	# Clean up attachment
	if "attachment" in unit and unit.attachment and is_instance_valid(unit.attachment):
		unit.attachment.queue_free()
		unit.attachment = null

	_clear_tiles_occupied(unit.grid_pos.x, unit.grid_pos.y, w, h)
	unit.queue_free()
	recalculate_buffs()
	GameManager.recalculate_max_health()

# Drag and Drop Implementation
func handle_bench_drop_at(target_tile, data):
	var unit_key = data.key
	var bench_index = data.index

	# Try to place
	if place_unit(unit_key, target_tile.x, target_tile.y):
		# Success, remove from bench via SessionData
		if GameManager.session_data:
			GameManager.session_data.set_bench_unit(bench_index, null)
		else:
			print("GridManager: GameManager.session_data is null during bench drop!")
		return

	# If place_unit failed, check for interactions (Devour/Merge)
	var target_unit = target_tile.unit
	if target_unit == null and target_tile.occupied_by != Vector2i.ZERO:
		var origin_key = get_tile_key(target_tile.occupied_by.x, target_tile.occupied_by.y)
		if tiles.has(origin_key):
			target_unit = tiles[origin_key].unit

	if target_unit:
		# Create a temporary unit to pass to interactions
		var temp_unit = UNIT_SCENE.instantiate()
		temp_unit.setup(unit_key)

		# Check Merge
		if target_unit.can_merge_with(temp_unit):
			target_unit.merge_with(temp_unit)
			if GameManager.session_data:
				GameManager.session_data.set_bench_unit(bench_index, null)
			recalculate_buffs()
			temp_unit.queue_free()
			GameManager.recalculate_max_health()
			return

		# Check Devour
		if can_devour(target_unit, temp_unit):
			target_unit.devour(temp_unit)
			if GameManager.session_data:
				GameManager.session_data.set_bench_unit(bench_index, null)
			recalculate_buffs()
			temp_unit.queue_free()
			GameManager.recalculate_max_health()
			return

		temp_unit.queue_free()

func handle_grid_move_at(target_tile, data):
	var unit = data.unit
	if !unit: return

	try_move_unit(unit, tiles[get_tile_key(unit.grid_pos.x, unit.grid_pos.y)], target_tile)

func try_move_unit(unit, from_tile, to_tile) -> bool:
	if unit == null or from_tile == null or to_tile == null: return false
	if from_tile == to_tile: return true

	var x = to_tile.x
	var y = to_tile.y
	var w = unit.unit_data.size.x
	var h = unit.unit_data.size.y

	# Case 1: Empty Target
	if can_place_unit(x, y, w, h, unit):
		_move_unit_internal(unit, x, y)
		return true

	# Case 2: Interaction (Merge, Devour, Swap)
	var target_unit = to_tile.unit
	if target_unit == null and to_tile.occupied_by != Vector2i.ZERO:
		var origin_key = get_tile_key(to_tile.occupied_by.x, to_tile.occupied_by.y)
		if tiles.has(origin_key):
			target_unit = tiles[origin_key].unit

	if target_unit == null: return false
	if target_unit == unit: return false

	if target_unit.can_merge_with(unit):
		target_unit.merge_with(unit)
		_clear_tiles_occupied(unit.grid_pos.x, unit.grid_pos.y, w, h)
		unit.queue_free()
		recalculate_buffs()
		return true

	if can_devour(target_unit, unit):
		target_unit.devour(unit)
		_clear_tiles_occupied(unit.grid_pos.x, unit.grid_pos.y, w, h)
		unit.queue_free()
		recalculate_buffs()
		return true

	if can_swap(unit, target_unit):
		_perform_swap(unit, target_unit)
		return true

	# Oxpecker Attachment (Grid to Grid)
	if unit.type_key == "oxpecker":
		if target_unit.type_key != "oxpecker" and target_unit.attachment == null:
			# We are moving an oxpecker from grid onto a host
			# Remove oxpecker from its old grid position
			var old_w = unit.unit_data.size.x
			var old_h = unit.unit_data.size.y
			_clear_tiles_occupied(unit.grid_pos.x, unit.grid_pos.y, old_w, old_h)

			# Attach
			unit.attach_to_host(target_unit)

			# It is no longer on the grid as an independent unit
			recalculate_buffs()
			return true

	return false

func _move_unit_internal(unit, new_x, new_y):
	var w = unit.unit_data.size.x
	var h = unit.unit_data.size.y
	_clear_tiles_occupied(unit.grid_pos.x, unit.grid_pos.y, w, h)
	unit.grid_pos = Vector2i(new_x, new_y)
	_set_tiles_occupied(new_x, new_y, w, h, unit)

	var tile = tiles[get_tile_key(new_x, new_y)]
	# Use grid_to_local for unit position update
	unit.position = grid_to_local(Vector2i(new_x, new_y)) + Vector2((w-1) * TILE_SIZE * 0.5, (h-1) * TILE_SIZE * 0.5)

	unit.start_position = unit.position

	# Clear old interaction target when moved
	unit.interaction_target_pos = null

	recalculate_buffs()

	# Trigger new selection if needed
	var info = unit.get_interaction_info()
	if info.has_interaction:
		start_interaction_selection(unit)

func can_devour(eater, food) -> bool:
	if food.unit_data.has("isFood") and food.unit_data.isFood:
		return true
	return false

func can_swap(unit_a, unit_b) -> bool:
	var pos_a = unit_a.grid_pos
	var size_a = unit_a.unit_data.size
	var pos_b = unit_b.grid_pos
	var size_b = unit_b.unit_data.size

	if size_a == size_b: return true
	if !can_place_unit_custom(pos_b.x, pos_b.y, size_a.x, size_a.y, [unit_a, unit_b]): return false
	if !can_place_unit_custom(pos_a.x, pos_a.y, size_b.x, size_b.y, [unit_a, unit_b]): return false
	return true

func can_place_unit_custom(x: int, y: int, w: int, h: int, ignore_units: Array) -> bool:
	for dx in range(w):
		for dy in range(h):
			var key = get_tile_key(x + dx, y + dy)
			if !tiles.has(key): return false
			var tile = tiles[key]
			if tile.type == "core": return false
			if tile.unit and not (tile.unit in ignore_units): return false
			if tile.occupied_by != Vector2i.ZERO:
				var origin_key = get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if tiles.has(origin_key):
					var occupant = tiles[origin_key].unit
					if occupant and not (occupant in ignore_units):
						return false
	return true

func _perform_swap(unit_a, unit_b):
	var pos_a = unit_a.grid_pos
	var pos_b = unit_b.grid_pos
	var size_a = unit_a.unit_data.size
	var size_b = unit_b.unit_data.size

	_clear_tiles_occupied(pos_a.x, pos_a.y, size_a.x, size_a.y)
	_clear_tiles_occupied(pos_b.x, pos_b.y, size_b.x, size_b.y)

	unit_a.grid_pos = pos_b
	_set_tiles_occupied(pos_b.x, pos_b.y, size_a.x, size_a.y, unit_a)

	unit_b.grid_pos = pos_a
	_set_tiles_occupied(pos_a.x, pos_a.y, size_b.x, size_b.y, unit_b)

	var tile_for_a = tiles[get_tile_key(pos_b.x, pos_b.y)]
	unit_a.position = tile_for_a.position + Vector2((size_a.x-1) * TILE_SIZE * 0.5, (size_a.y-1) * TILE_SIZE * 0.5)
	unit_a.start_position = unit_a.position

	var tile_for_b = tiles[get_tile_key(pos_a.x, pos_a.y)]
	unit_b.position = tile_for_b.position + Vector2((size_b.x-1) * TILE_SIZE * 0.5, (size_b.y-1) * TILE_SIZE * 0.5)
	unit_b.start_position = unit_b.position

	recalculate_buffs()

func recalculate_buffs():
	var processed_units = []
	for key in tiles:
		var tile = tiles[key]
		if tile.unit and not (tile.unit in processed_units):
			tile.unit.reset_stats()
			processed_units.append(tile.unit)

	for unit in processed_units:
		if unit.behavior:
			unit.behavior.broadcast_buffs()

		# Interaction Buffs
		var info = unit.get_interaction_info()
		if info.has_interaction and unit.interaction_target_pos != null:
			if is_neighbor(unit, unit.interaction_target_pos):
				_apply_buff_to_specific_pos(unit.interaction_target_pos, info.buff_id, unit)

				if unit.unit_data.get("interaction_pattern") == "neighbor_pair":
					var neighbors = _get_clockwise_neighbors(unit.grid_pos)
					var idx = neighbors.find(unit.interaction_target_pos)
					if idx != -1:
						var next_idx = (idx + 1) % neighbors.size()
						_apply_buff_to_specific_pos(neighbors[next_idx], info.buff_id, unit)

	for unit in processed_units:
		unit.update_visuals()

	grid_updated.emit()

func _apply_buff_to_specific_pos(target_pos: Vector2i, buff_id: String, provider_unit: Node2D = null):
	var key = get_tile_key(target_pos.x, target_pos.y)
	if tiles.has(key):
		var tile = tiles[key]
		var target_unit = tile.unit
		# Handle occupied_by if needed (though usually we buff the main unit)
		if target_unit == null and tile.occupied_by != Vector2i.ZERO:
			var origin_key = get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
			if tiles.has(origin_key):
				target_unit = tiles[origin_key].unit

		if target_unit:
			target_unit.apply_buff(buff_id, provider_unit)

func _apply_buff_to_neighbors(provider_unit, buff_type):
	var cx = provider_unit.grid_pos.x
	var cy = provider_unit.grid_pos.y
	var w = provider_unit.unit_data.size.x
	var h = provider_unit.unit_data.size.y
	var neighbors = []

	for dx in range(w):
		neighbors.append(Vector2i(cx + dx, cy - 1))
		neighbors.append(Vector2i(cx + dx, cy + h))

	for dy in range(h):
		neighbors.append(Vector2i(cx - 1, cy + dy))
		neighbors.append(Vector2i(cx + w, cy + dy))

	for n_pos in neighbors:
		var n_key = get_tile_key(n_pos.x, n_pos.y)
		if tiles.has(n_key):
			var tile = tiles[n_key]
			var target_unit = tile.unit
			if target_unit == null and tile.occupied_by != Vector2i.ZERO:
				var origin_key = get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if tiles.has(origin_key):
					target_unit = tiles[origin_key].unit
			if target_unit and target_unit != provider_unit:
				target_unit.apply_buff(buff_type, provider_unit)

func toggle_expansion_mode():
	expansion_mode = !expansion_mode

	# Toggle grid lines on all tiles
	for key in tiles:
		if tiles[key].has_method("set_grid_visible"):
			tiles[key].set_grid_visible(expansion_mode)

	if expansion_mode:
		spawn_expansion_ghosts()
	else:
		clear_ghosts()

func spawn_expansion_ghosts():
	clear_ghosts()

	for key in tiles:
		var tile = tiles[key]

		# Limit expansion ghost tiles to center 5x5 area (plus minus 2 from center)
		if abs(tile.x) > 2 or abs(tile.y) > 2:
			continue

		# Find locked tiles that can be unlocked
		if tile.state == "locked_inner" or tile.state == "locked_outer":
			# Check neighbors
			var x = tile.x
			var y = tile.y
			var neighbors = [
				Vector2i(x+1, y), Vector2i(x-1, y),
				Vector2i(x, y+1), Vector2i(x, y-1)
			]

			var can_expand = false
			for n_pos in neighbors:
				var n_key = get_tile_key(n_pos.x, n_pos.y)
				if tiles.has(n_key):
					var n_tile = tiles[n_key]
					# If neighbor is unlocked or core (which is unlocked), we can expand
					if n_tile.state == "unlocked":
						can_expand = true
						break

			if can_expand:
				var ghost = GHOST_TILE_SCRIPT.new()
				add_child(ghost)
				ghost.setup(tile.x, tile.y)

				# Use grid_to_local for ghost position
				var local_pos = grid_to_local(Vector2i(tile.x, tile.y))
				ghost.position = local_pos - (ghost.custom_minimum_size / 2)

				# ghost.clicked.connect(on_ghost_clicked) # GhostTile calls grid_manager.on_ghost_clicked directly
				ghost_tiles.append(ghost)

func clear_ghosts():
	for ghost in ghost_tiles:
		ghost.queue_free()
	ghost_tiles.clear()

func on_ghost_clicked(x, y):
	var cost = expansion_cost
	if GameManager.reward_manager and "rapid_expansion" in GameManager.reward_manager.acquired_artifacts:
		cost = int(cost * 0.7)

	if GameManager.gold >= cost:
		if GameManager.spend_gold(cost):
			expansion_cost += 10
			var key = get_tile_key(x, y)
			if tiles.has(key):
				var tile = tiles[key]
				tile.set_state("unlocked")
				if not active_territory_tiles.has(tile):
					active_territory_tiles.append(tile)

				# Artifact: Rapid Expansion Bonus
				if GameManager.reward_manager and "rapid_expansion" in GameManager.reward_manager.acquired_artifacts:
					GameManager.permanent_health_bonus += 50.0
					GameManager.max_core_health += 50.0
					GameManager.core_health += 50.0 # Heal by the added amount
					GameManager.resource_changed.emit()

			# Refresh ghosts to show new expansion options
			# Must use call_deferred or just call it?
			# The prompt says: "call clear_ghosts() then immediately re-spawn_expansion_ghosts()"
			clear_ghosts()
			spawn_expansion_ghosts()
	else:
		# Feedback for not enough gold?
		# Use grid_to_local
		var world_pos = get_world_pos_from_grid(Vector2i(x,y))
		GameManager.spawn_floating_text(world_pos, "Need Gold!", Color.RED)

func get_closest_unlocked_tile(world_pos: Vector2) -> Node2D:
	if active_territory_tiles.is_empty():
		# Fallback to core if exists
		var core_key = get_tile_key(0, 0)
		if tiles.has(core_key):
			return tiles[core_key]
		return null

	var closest_tile = null
	var min_dist_sq = INF

	for tile in active_territory_tiles:
		# Check if valid instance
		if not is_instance_valid(tile): continue

		var dist_sq = tile.global_position.distance_squared_to(world_pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_tile = tile

	return closest_tile

# --- Trap Placement Sequence ---

func start_trap_placement_sequence(unit):
	interaction_state = STATE_SEQUENCE_TRAP_PLACEMENT
	interaction_source_unit = unit

	valid_interaction_targets.clear()
	# No global highlight, just follow mouse

func _handle_input_trap_placement(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_local_mouse_position()
			var gx = int(round(mouse_pos.x / TILE_SIZE))
			var gy = int(round(mouse_pos.y / TILE_SIZE))
			var grid_pos = Vector2i(gx, gy)

			if can_place_trap_at(grid_pos):
				# Place Trap
				var trap_type = "poison"
				if interaction_source_unit and interaction_source_unit.behavior.has_method("get_trap_type"):
					var t = interaction_source_unit.behavior.get_trap_type()
					if t != "": trap_type = t

				spawn_trap_custom(grid_pos, trap_type)

				# Register trap to unit
				var trap_node = obstacles.get(grid_pos)
				if trap_node and interaction_source_unit:
					if "associated_traps" in interaction_source_unit:
						interaction_source_unit.associated_traps.append(trap_node)

				# End Trap Step
				end_trap_placement_sequence()

				# Determine next step
				var next_step_started = false
				if interaction_source_unit and is_instance_valid(interaction_source_unit):
					var info = interaction_source_unit.get_interaction_info()
					if info.has_interaction:
						start_interaction_selection(interaction_source_unit)
						next_step_started = true

				if not next_step_started:
					interaction_state = STATE_IDLE
					interaction_source_unit = null

				get_viewport().set_input_as_handled()
			else:
				# Invalid click
				get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_deployment_sequence()
			get_viewport().set_input_as_handled()

func _process_trap_placement_preview():
	# Mimic dragging trap
	var trap_type = "poison_trap"
	if interaction_source_unit and interaction_source_unit.behavior.has_method("get_trap_type"):
		var t = interaction_source_unit.behavior.get_trap_type()
		if t != "": trap_type = t

	var local_mouse = get_local_mouse_position()
	var gx = int(round(local_mouse.x / TILE_SIZE))
	var gy = int(round(local_mouse.y / TILE_SIZE))
	var grid_pos = Vector2i(gx, gy)

	# Snap to grid: Calculate world position of the tile center
	var snapped_local_pos = grid_to_local(grid_pos)
	var snapped_world_pos = to_global(snapped_local_pos)

	update_placement_preview(grid_pos, snapped_world_pos, trap_type)

func can_place_trap_at(grid_pos: Vector2i) -> bool:
	var key = get_tile_key(grid_pos.x, grid_pos.y)
	if !tiles.has(key): return false
	var tile = tiles[key]

	if obstacles.has(grid_pos): return false
	if tile.unit != null: return false
	if tile.occupied_by != Vector2i.ZERO: return false
	if tile.type == "core": return false

	return true

func end_trap_placement_sequence():
	# Clear highlights
	for node in interaction_highlights:
		node.queue_free()
	interaction_highlights.clear()

	if placement_preview_cursor:
		placement_preview_cursor.visible = false

func _cancel_deployment_sequence():
	# Rollback: Remove the unit and return it to inventory/bench
	# The unit was already placed in place_unit.
	# We need to remove it.

	end_trap_placement_sequence()
	end_interaction_selection() # Just in case

	if interaction_source_unit and is_instance_valid(interaction_source_unit):
		# If unit came from bench, we should ideally put it back.
		# But `place_unit` is called by `handle_bench_drop_at`.
		# We don't have direct reference to where it came from here easily unless we stored it.
		# However, typically rollback implies destruction + refund or return to bench.
		# For this task, "Rollback entire operation, remove unit from grid and return to original place".
		# Since `handle_bench_drop_at` removes it from bench upon success of `place_unit`.
		# We need to re-add it to bench.

		var u_key = interaction_source_unit.type_key
		var u_cost = interaction_source_unit.unit_data.get("cost", 0)
		remove_unit_from_grid(interaction_source_unit)

		if GameManager.main_game:
			# Try to add back to bench
			if !GameManager.main_game.add_unit_to_bench(u_key):
				# If bench full (unlikely if we just dragged from it), refund?
				GameManager.add_gold(u_cost)
		else:
			print("MainGame not found, cannot return to bench.")

	interaction_state = STATE_IDLE
	interaction_source_unit = null
