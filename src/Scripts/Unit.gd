class_name Unit
extends Node2D

const UnitBehavior = preload("res://src/Scripts/Units/UnitBehavior.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var is_summoned: bool = false
var type_key: String
var level: int = 1
var stats_multiplier: float = 1.0
var cooldown: float = 0.0
var skill_cooldown: float = 0.0
var active_buffs: Array = []
var buff_sources: Dictionary = {} # Key: buff_type, Value: source_unit (Node2D)
var temporary_buffs: Array = [] # Array of {stat, amount, duration, source}
var traits: Array = []
var unit_data: Dictionary

var behavior: UnitBehavior

var attachment: Node2D = null
var host: Node2D = null

# Stats
var damage: float
var range_val: float
var atk_speed: float
var attack_cost_mana: float = 0.0
var skill_mana_cost: float = 30.0

var max_hp: float = 0.0
var current_hp: float = 0.0

# Visual Holder for animations and structure
var visual_holder: Node2D = null

var is_no_mana: bool = false
var crit_rate: float = 0.0
var crit_dmg: float = 1.5
var bounce_count: int = 0
var split_count: int = 0

var guaranteed_crit_stacks: int = 0

# Grid
var grid_pos: Vector2i = Vector2i.ZERO
var start_position: Vector2 = Vector2.ZERO

# Interaction
var interaction_target_pos = null # Vector2i or null
var associated_traps: Array = [] # Stores references to traps placed by this unit

# Dragging
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var ghost_node: Node2D = null
var is_hovered: bool = false
var focus_target: Node2D = null
var focus_stacks: int = 0

# Highlighting
var _is_skill_highlight_active: bool = false
var _highlight_color: Color = Color.WHITE
var is_force_highlighted: bool = false

const MAX_LEVEL = 3
const DRAG_HANDLER_SCRIPT = preload("res://src/Scripts/UI/UnitDragHandler.gd")

signal unit_clicked(unit)
signal attack_performed(target_node)
signal merged(consumed_unit)
signal damage_blocked(damage: float, source: Node)

func _start_skill_cooldown(base_duration: float):
	if GameManager.cheat_fast_cooldown and base_duration > 1.0:
		skill_cooldown = 1.0
	else:
		skill_cooldown = base_duration * GameManager.get_stat_modifier("cooldown")

func _ready():
	_ensure_visual_hierarchy()
	tree_exiting.connect(_on_cleanup)

	if !unit_data.is_empty():
		update_visuals()

func _on_cleanup():
	if behavior:
		behavior.on_cleanup()

func setup(key: String):
	_ensure_visual_hierarchy()
	type_key = key
	unit_data = Constants.UNIT_TYPES[key].duplicate()

	_load_behavior()

	reset_stats()
	current_hp = max_hp
	behavior.on_setup()

	update_visuals()
	start_breathe_anim()

	var drag_handler = Control.new()
	drag_handler.set_script(DRAG_HANDLER_SCRIPT)
	add_child(drag_handler)
	drag_handler.setup(self)

func _load_behavior():
	var behavior_name = type_key.to_pascal_case()
	var path = "res://src/Scripts/Units/Behaviors/%s.gd" % behavior_name
	var script_res = null

	if ResourceLoader.exists(path):
		script_res = load(path)
	else:
		script_res = load("res://src/Scripts/Units/Behaviors/DefaultBehavior.gd")

	behavior = script_res.new(self)

func _ensure_visual_hierarchy():
	if visual_holder and is_instance_valid(visual_holder):
		return

	visual_holder = get_node_or_null("VisualHolder")
	if !visual_holder:
		visual_holder = Node2D.new()
		visual_holder.name = "VisualHolder"
		add_child(visual_holder)

		var visual_elements = ["Label", "StarLabel"]
		for child_name in visual_elements:
			var child = get_node_or_null(child_name)
			if child:
				remove_child(child)
				visual_holder.add_child(child)

	var highlight = visual_holder.get_node_or_null("HighlightBorder")
	if !highlight:
		highlight = ReferenceRect.new()
		highlight.name = "HighlightBorder"
		highlight.border_width = 4.0
		highlight.editor_only = false
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_holder.add_child(highlight)

	if unit_data and unit_data.has("size"):
		var size_val = unit_data["size"]
		var target_size = Vector2(size_val.x * Constants.TILE_SIZE - 4, size_val.y * Constants.TILE_SIZE - 4)
		highlight.size = target_size
		highlight.position = -(target_size / 2)

func take_damage(amount: float, source_enemy = null):
	var original_amount = amount

	# 检查是否有guardian_shield buff，应用减伤
	if "guardian_shield" in active_buffs:
		var source = buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			amount = amount * (1.0 - reduction)

	amount = behavior.on_damage_taken(amount, source_enemy)

	# 计算被阻挡的伤害（来自spore shield等机制）
	var blocked_amount = original_amount - amount
	if blocked_amount > 0:
		damage_blocked.emit(blocked_amount, source_enemy)

	current_hp = max(0, current_hp - amount)
	GameManager.damage_core(amount)

	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "position", Vector2(randf_range(-2,2), randf_range(-2,2)), 0.05).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(visual_holder, "position", Vector2.ZERO, 0.05)

func reset_stats():
	var stats = {}
	if unit_data.has("levels") and unit_data["levels"].has(str(level)):
		stats = unit_data["levels"][str(level)]
	else:
		stats = unit_data

	damage = stats.get("damage", unit_data.get("damage", 0))
	max_hp = stats.get("hp", unit_data.get("hp", 0))
	# Note: current_hp is NOT reset here to avoid full heal on level up,
	# but usually max_hp changes, so maybe we should proportional update?
	# For simplicity, we assume heal on level up (merge) or just clamp.
	if current_hp > max_hp: current_hp = max_hp
	# If max_hp increased, we don't necessarily heal, but we could.
	# Standard behavior: Keep current_hp, unless we want to "heal on upgrade".
	# Let's simple clamp.

	range_val = unit_data.get("range", 0)
	atk_speed = unit_data.get("atkSpeed", 1.0)

	crit_rate = unit_data.get("crit_rate", 0.1)
	crit_dmg = unit_data.get("crit_dmg", 1.5)

	attack_cost_mana = unit_data.get("manaCost", 0.0)
	skill_mana_cost = unit_data.get("skillCost", 30.0)

	if stats.has("mechanics"):
		var mechs = stats["mechanics"]
		if mechs.has("crit_rate_bonus"):
			crit_rate += mechs["crit_rate_bonus"]

	bounce_count = 0
	split_count = 0
	active_buffs.clear()
	buff_sources.clear()

	if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
		range_val *= 1.2

	if behavior:
		behavior.on_stats_updated()

	update_visuals()

func capture_bullet(bullet_snapshot: Dictionary):
	if behavior.has_method("capture_bullet"):
		behavior.capture_bullet(bullet_snapshot)

func calculate_damage_against(target_node: Node2D) -> float:
	var final_damage = damage

	if GameManager.reward_manager and "focus_fire" in GameManager.reward_manager.acquired_artifacts:
		if target_node == focus_target:
			focus_stacks = min(focus_stacks + 1, 10)
		else:
			focus_target = target_node
			focus_stacks = 0

		final_damage *= (1.0 + 0.05 * focus_stacks)

	final_damage *= GameManager.get_stat_modifier("damage")

	return final_damage

func apply_buff(buff_type: String, source_unit: Node2D = null):
	if buff_type in active_buffs and buff_type != "bounce": return

	if not (buff_type in active_buffs):
		active_buffs.append(buff_type)

	if source_unit:
		buff_sources[buff_type] = source_unit

	# Emit buff_applied signal for test logging
	if GameManager.has_signal("buff_applied"):
		var amount = 0.0
		match buff_type:
			"range": amount = 1.25
			"speed": amount = 1.2
			"crit": amount = 0.25
			"bounce": amount = 1.0
			"split": amount = 1.0
			"forest_blessing": amount = 1.0
			"guardian_shield": amount = 1.0
		GameManager.buff_applied.emit(self, buff_type, source_unit, amount)

	match buff_type:
		"range":
			range_val *= 1.25
		"speed":
			atk_speed *= 1.2
		"crit":
			crit_rate += 0.25
		"bounce":
			bounce_count += 1
		"split":
			split_count += 1
		"guardian_shield":
			# 牦牛守护的减伤buff，效果在take_damage中处理
			pass

func set_highlight(active: bool, color: Color = Color.WHITE):
	_is_skill_highlight_active = active
	_highlight_color = color
	queue_redraw()

func set_force_highlight(active: bool):
	is_force_highlighted = active
	queue_redraw()

func execute_skill_at(grid_pos: Vector2i):
	if skill_cooldown > 0: return
	if not unit_data.has("skill"): return

	var final_cost = skill_mana_cost
	var cost_reduction = GameManager.get_global_buff("skill_mana_cost_reduction", 0.0)
	if cost_reduction > 0:
		final_cost *= (1.0 - cost_reduction)

	if GameManager.consume_resource("mana", final_cost):
		is_no_mana = false
		_start_skill_cooldown(unit_data.get("skillCd", 10.0))

		var skill_name = unit_data.skill
		GameManager.spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(self)

		behavior.on_skill_executed_at(grid_pos)

	else:
		is_no_mana = true
		GameManager.spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func add_crit_stacks(amount: int):
	guaranteed_crit_stacks += amount
	GameManager.spawn_floating_text(global_position, "Crit Ready!", Color.ORANGE)

func _on_skill_ended():
	set_highlight(false)

func activate_skill():
	if !unit_data.has("skill"): return
	if skill_cooldown > 0: return

	behavior.on_skill_activated()

	if unit_data.get("skillType") == "point":
		# Behavior handles targeting initiation
		return

	var final_cost = skill_mana_cost
	if GameManager.skill_cost_reduction > 0:
		final_cost *= (1.0 - GameManager.skill_cost_reduction)

	if GameManager.consume_resource("mana", final_cost):
		is_no_mana = false
		_start_skill_cooldown(unit_data.get("skillCd", 10.0))

		var skill_name = unit_data.skill
		GameManager.spawn_floating_text(global_position, skill_name.capitalize() + "!", Color.CYAN)
		GameManager.skill_activated.emit(self)
		# 中文技能日志
		if AILogger:
			AILogger.action("[技能] %s(Lv%d) 使用了技能: %s (消耗%.0f法力)" % [type_key, level, skill_name, final_cost])

		if visual_holder:
			var tween = create_tween()
			tween.tween_property(visual_holder, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1)

	else:
		is_no_mana = true
		GameManager.spawn_floating_text(global_position, "No Mana!", Color.BLUE)

func update_visuals():
	_ensure_visual_hierarchy()
	var label = visual_holder.get_node_or_null("Label")
	var star_label = visual_holder.get_node_or_null("StarLabel")

	var icon_texture = AssetLoader.get_unit_icon(type_key)

	var tex_rect = visual_holder.get_node_or_null("TextureRect")
	if !tex_rect:
		tex_rect = TextureRect.new()
		tex_rect.name = "TextureRect"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_holder.add_child(tex_rect)
		if label: visual_holder.move_child(tex_rect, label.get_index())

	if icon_texture:
		tex_rect.texture = icon_texture
		tex_rect.show()
		if label: label.hide()
	else:
		tex_rect.hide()
		if label:
			label.text = unit_data.icon
			label.show()
	
	var size = unit_data["size"]
	var target_size = Vector2(size.x * Constants.TILE_SIZE - 4, size.y * Constants.TILE_SIZE - 4)
	var target_pos = -(target_size / 2)

	if tex_rect:
		tex_rect.size = target_size
		tex_rect.position = target_pos
		tex_rect.pivot_offset = tex_rect.size / 2

	if label:
		label.size = target_size
		label.position = target_pos
		label.pivot_offset = label.size / 2

	if level > 1:
		if star_label:
			star_label.text = "⭐%d" % level
			star_label.show()
	else:
		if star_label:
			star_label.hide()

	_update_buff_icons()

func _update_buff_icons():
	var buff_container = get_node_or_null("BuffContainer")
	if !buff_container:
		buff_container = HBoxContainer.new()
		buff_container.name = "BuffContainer"
		buff_container.alignment = BoxContainer.ALIGNMENT_CENTER

		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit_data and unit_data.has("size"):
			size = Vector2(unit_data["size"].x * Constants.TILE_SIZE, unit_data["size"].y * Constants.TILE_SIZE)

		buff_container.position = Vector2(-size.x/2, size.y/2 - 20)
		buff_container.size = Vector2(size.x, 15)

		buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(buff_container)

	for child in buff_container.get_children():
		child.queue_free()

	for buff in active_buffs:
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		lbl.text = _get_buff_icon(buff)
		buff_container.add_child(lbl)

func _get_buff_icon(buff_type: String) -> String:
	match buff_type:
		"fire": return "🔥"
		"poison": return "🧪"
		"range": return "🔭"
		"speed": return "⚡"
		"crit": return "💥"
		"bounce": return "🪞"
		"split": return "💠"
		"multishot": return "📶"
		"wealth": return "💰"
	return "?"

func _process(delta):
	if !GameManager.is_wave_active: return
	if not behavior: return

	behavior.on_tick(delta)

	_update_temporary_buffs(delta)

	if !behavior.on_combat_tick(delta):
		_process_combat(delta)

	if skill_cooldown > 0:
		skill_cooldown -= delta

	if is_no_mana and unit_data.has("skill"):
		modulate = Color(0.7, 0.7, 1.0, 1.0)
	else:
		modulate = Color.WHITE

func _process_combat(delta):
	if !unit_data.has("attackType") or unit_data.attackType == "none":
		return

	if cooldown > 0:
		cooldown -= delta
		return

	if attack_cost_mana > 0:
		if !GameManager.check_resource("mana", attack_cost_mana):
			is_no_mana = true
			return
		else:
			is_no_mana = false

	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	var target = combat_manager.find_nearest_enemy(global_position, range_val)
	if !target: return

	if unit_data.attackType == "melee":
		_do_melee_attack(target)
	else:
		_do_standard_ranged_attack(target)

func _do_melee_attack(target):
	var target_last_pos = target.global_position

	if attack_cost_mana > 0:
		GameManager.consume_resource("mana", attack_cost_mana)

	cooldown = atk_speed * GameManager.get_stat_modifier("attack_interval")

	play_attack_anim("melee", target_last_pos)

	await get_tree().create_timer(Constants.ANIM_WINDUP_TIME).timeout
	if !is_instance_valid(self): return

	if is_instance_valid(target):
		_spawn_melee_projectiles(target)
		attack_performed.emit(target)
	else:
		_spawn_melee_projectiles_blind(target_last_pos)
		attack_performed.emit(null)

func _spawn_melee_projectiles_blind(target_pos: Vector2):
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	var swing_hit_list = []
	var attack_dir = (target_pos - global_position).normalized()

	var proj_speed = 600.0
	var proj_life = (range_val + 30.0) / proj_speed
	var count = 5
	var spread = PI / 2.0

	var base_angle = attack_dir.angle()
	var start_angle = base_angle - spread / 2.0
	var step = spread / max(1, count - 1)

	for i in range(count):
		var angle = start_angle + (i * step)
		var stats = {
			"pierce": 100,
			"hide_visuals": true,
			"life": proj_life,
			"angle": angle,
			"speed": proj_speed,
			"shared_hit_list": swing_hit_list
		}
		combat_manager.spawn_projectile(self, global_position, null, stats)

func _spawn_melee_projectiles(target: Node2D):
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	var swing_hit_list = []
	var attack_dir = (target.global_position - global_position).normalized()

	var proj_speed = 600.0
	var proj_life = (range_val + 30.0) / proj_speed
	var count = 5
	var spread = PI / 2.0

	var base_angle = attack_dir.angle()
	var start_angle = base_angle - spread / 2.0
	var step = spread / max(1, count - 1)

	for i in range(count):
		var angle = start_angle + (i * step)
		var stats = {
			"pierce": 100,
			"hide_visuals": true,
			"life": proj_life,
			"angle": angle,
			"speed": proj_speed,
			"shared_hit_list": swing_hit_list
		}
		combat_manager.spawn_projectile(self, global_position, null, stats)

func _do_standard_ranged_attack(target):
	var combat_manager = GameManager.combat_manager
	if !combat_manager: return

	if attack_cost_mana > 0:
		GameManager.consume_resource("mana", attack_cost_mana)

	cooldown = atk_speed * GameManager.get_stat_modifier("attack_interval")

	if unit_data.get("proj") == "lightning":
		play_attack_anim("lightning", target.global_position)
		combat_manager.perform_lightning_attack(self, global_position, target, unit_data.get("chain", 0))
		return

	play_attack_anim("ranged", target.global_position)

	var proj_count = unit_data.get("projCount", 1)
	var spread = unit_data.get("spread", 0.5)

	if "multishot" in active_buffs:
		proj_count += 2
		spread = max(spread, 0.5)

	if proj_count == 1:
		combat_manager.spawn_projectile(self, global_position, target)
		attack_performed.emit(target)
	else:
		var base_angle = (target.global_position - global_position).angle()
		var start_angle = base_angle - spread / 2.0
		var step = spread / max(1, proj_count - 1)

		for i in range(proj_count):
			var angle = start_angle + (i * step)
			combat_manager.spawn_projectile(self, global_position, target, {"angle": angle})

	attack_performed.emit(target)

func play_attack_anim(attack_type: String, target_pos: Vector2, duration: float = -1.0):
	if !visual_holder: return

	if breathe_tween: breathe_tween.kill()
	if attack_tween: attack_tween.kill()

	attack_tween = create_tween()

	if attack_type == "melee":
		var dir = (target_pos - global_position).normalized()
		var original_pos = Vector2.ZERO

		attack_tween.tween_property(visual_holder, "position", -dir * Constants.ANIM_WINDUP_DIST, Constants.ANIM_WINDUP_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(visual_holder, "scale", Constants.ANIM_WINDUP_SCALE, Constants.ANIM_WINDUP_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		attack_tween.tween_property(visual_holder, "position", dir * Constants.ANIM_STRIKE_DIST, Constants.ANIM_STRIKE_TIME)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		attack_tween.parallel().tween_property(visual_holder, "scale", Constants.ANIM_STRIKE_SCALE, Constants.ANIM_STRIKE_TIME)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		attack_tween.tween_property(visual_holder, "position", original_pos, Constants.ANIM_RECOVERY_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(visual_holder, "scale", Vector2.ONE, Constants.ANIM_RECOVERY_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	elif attack_type == "bow":
		var total_time = duration if duration > 0 else 0.5
		var pull_time = total_time * 0.6
		var recover_time = total_time * 0.3

		var dir = (target_pos - global_position).normalized()

		attack_tween.tween_property(visual_holder, "position", -dir * 10.0, pull_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		attack_tween.parallel().tween_property(visual_holder, "scale", Vector2(0.8, 1.2), pull_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		attack_tween.tween_callback(func():
			visual_holder.position = Vector2.ZERO
			visual_holder.scale = Vector2.ONE
		)

		attack_tween.tween_property(visual_holder, "scale", Vector2(1.1, 0.9), recover_time * 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.tween_property(visual_holder, "scale", Vector2.ONE, recover_time * 0.5)

	elif attack_type == "ranged" or attack_type == "lightning":
		attack_tween.tween_property(visual_holder, "scale", Vector2(0.8, 0.8), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		attack_tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)
		attack_tween.parallel().tween_property(visual_holder, "position", Vector2.ZERO, 0.3)

	attack_tween.finished.connect(func(): start_breathe_anim())

var breathe_tween: Tween = null
var attack_tween: Tween = null

func get_interaction_info() -> Dictionary:
	var info = { "has_interaction": false, "buff_id": "" }
	if unit_data.has("has_interaction") and unit_data.has_interaction:
		info.has_interaction = true
		info.buff_id = unit_data.get("buff_id", "")
	return info

func start_breathe_anim():
	if !visual_holder: return

	if breathe_tween: breathe_tween.kill()

	breathe_tween = create_tween().set_loops()
	breathe_tween.tween_property(visual_holder, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE)
	breathe_tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func can_merge_with(other_unit) -> bool:
	if other_unit == null: return false
	if other_unit == self: return false
	if other_unit.type_key != type_key: return false
	if other_unit.level != level: return false
	if level >= MAX_LEVEL: return false
	return true

func merge_with(other_unit):
	var old_level = level
	merged.emit(other_unit)
	level += 1
	reset_stats()
	current_hp = max_hp # Full heal on level up

	GameManager.unit_upgraded.emit(self, old_level, level)
	GameManager.spawn_floating_text(global_position, "Level Up!", Color.GOLD)
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.2)

func devour(food_unit):
	var old_level = level
	level += 1
	damage += 5
	stats_multiplier += 0.2
	update_visuals()
	GameManager.unit_upgraded.emit(self, old_level, level)

func _on_area_2d_input_event(viewport, event, shape_idx):
	if !GameManager.is_wave_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unit_clicked.emit(self)

func _on_area_2d_mouse_entered():
	is_hovered = true
	queue_redraw()

	for buff_type in buff_sources:
		var source = buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(true)

	if GameManager.grid_manager and GameManager.grid_manager.has_method("show_provider_icons"):
		GameManager.grid_manager.show_provider_icons(self)

	var current_stats = {
		"level": level,
		"damage": damage,
		"range": range_val,
		"atk_speed": atk_speed,
		"crit_rate": crit_rate,
		"crit_dmg": crit_dmg
	}
	GameManager.show_tooltip.emit(unit_data, current_stats, active_buffs, global_position)

func _on_area_2d_mouse_exited():
	is_hovered = false
	queue_redraw()

	for buff_type in buff_sources:
		var source = buff_sources[buff_type]
		if is_instance_valid(source) and source.has_method("set_force_highlight"):
			source.set_force_highlight(false)

	if GameManager.grid_manager and GameManager.grid_manager.has_method("hide_provider_icons"):
		GameManager.grid_manager.hide_provider_icons()

	GameManager.hide_tooltip.emit()

func _draw():
	if is_hovered:
		var draw_radius = range_val
		if unit_data.get("attackType") == "melee":
			draw_radius = max(range_val, 100.0)

		draw_circle(Vector2.ZERO, draw_radius, Color(1, 1, 1, 0.1))
		draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 64, Color(1, 1, 1, 0.3), 1.0)

	if _is_skill_highlight_active:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit_data and unit_data.has("size"):
			size = Vector2(unit_data.size.x * Constants.TILE_SIZE, unit_data.size.y * Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		draw_rect(rect, _highlight_color, false, 4.0)

	if is_force_highlighted:
		var size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		if unit_data and unit_data.has("size"):
			size = Vector2(unit_data.size.x * Constants.TILE_SIZE, unit_data.size.y * Constants.TILE_SIZE)

		var rect = Rect2(-size / 2, size)
		draw_rect(rect, Color.WHITE, false, 4.0)

func _get_neighbor_units() -> Array:
	var list = []
	if !GameManager.grid_manager: return list

	var cx = grid_pos.x
	var cy = grid_pos.y
	var w = unit_data.size.x
	var h = unit_data.size.y

	var neighbors_pos = []
	for dx in range(-1, w + 1):
		neighbors_pos.append(Vector2i(cx + dx, cy - 1))
		neighbors_pos.append(Vector2i(cx + dx, cy + h))
	for dy in range(0, h):
		neighbors_pos.append(Vector2i(cx - 1, cy + dy))
		neighbors_pos.append(Vector2i(cx + w, cy + dy))

	for n_pos in neighbors_pos:
		var key = GameManager.grid_manager.get_tile_key(n_pos.x, n_pos.y)
		if GameManager.grid_manager.tiles.has(key):
			var tile = GameManager.grid_manager.tiles[key]
			var u = tile.unit
			if u == null and tile.occupied_by != Vector2i.ZERO:
				var origin_key = GameManager.grid_manager.get_tile_key(tile.occupied_by.x, tile.occupied_by.y)
				if GameManager.grid_manager.tiles.has(origin_key):
					u = GameManager.grid_manager.tiles[origin_key].unit

			if u and is_instance_valid(u) and not (u in list):
				list.append(u)
	return list

func _input(event):
	if is_dragging:
		if event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			end_drag()

func start_drag(mouse_pos_global):
	is_dragging = true
	start_position = position
	drag_offset = global_position - mouse_pos_global
	z_index = 100
	create_ghost()

func end_drag():
	is_dragging = false
	z_index = 0
	remove_ghost()

	if GameManager.grid_manager:
		if GameManager.grid_manager.handle_unit_drop(self):
			return

		if GameManager.main_game:
			var viewport_rect = get_viewport_rect()
			var mouse_pos = get_global_mouse_position()
			if mouse_pos.y > (viewport_rect.size.y - 200):
				if GameManager.main_game.try_add_to_bench_from_grid(self):
					return

	return_to_start()

func create_ghost():
	if ghost_node: return
	ghost_node = Node2D.new()

	if visual_holder:
		var dup_visual = visual_holder.duplicate(7)
		ghost_node.add_child(dup_visual)

	get_parent().add_child(ghost_node)
	ghost_node.position = start_position
	ghost_node.modulate.a = 0.5
	ghost_node.z_index = -1

func remove_ghost():
	if ghost_node:
		ghost_node.queue_free()
		ghost_node = null

func return_to_start():
	position = start_position

func heal(amount: float):
	current_hp = min(current_hp + amount, max_hp)
	GameManager.spawn_floating_text(global_position, "+%d" % int(amount), Color.GREEN)

func play_buff_receive_anim():
	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual_holder, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func spawn_buff_effect(icon_char: String):
	var effect_node = Node2D.new()
	effect_node.name = "BuffEffect"
	effect_node.z_index = 101

	var lbl = Label.new()
	lbl.text = icon_char
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.position = Vector2(-20, -20)
	lbl.size = Vector2(40, 40)

	effect_node.add_child(lbl)
	add_child(effect_node)

	effect_node.position = Vector2.ZERO

	var tween = create_tween()
	tween.tween_property(effect_node, "scale", Vector2(2.5, 2.5), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(effect_node, "modulate:a", 0.0, 0.6)

	tween.finished.connect(effect_node.queue_free)

func add_stat_bonus(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"defense":
			# No defense stat on unit currently?
			pass
		"move_speed":
			# Units don't move.
			pass
		"crit_chance":
			crit_rate += amount

func add_temporary_buff(stat: String, amount: float, duration: float):
	temporary_buffs.append({
		"stat": stat,
		"amount": amount,
		"duration": duration
	})
	_apply_temp_buff_effect(stat, amount)

func _update_temporary_buffs(delta: float):
	for i in range(temporary_buffs.size() - 1, -1, -1):
		var buff = temporary_buffs[i]
		buff["duration"] -= delta
		if buff["duration"] <= 0:
			_remove_temp_buff_effect(buff["stat"], buff["amount"])
			temporary_buffs.remove_at(i)

func _apply_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed *= (1.0 + amount)
		"crit_chance":
			crit_rate += amount

func _remove_temp_buff_effect(stat: String, amount: float):
	match stat:
		"attack_speed":
			atk_speed /= (1.0 + amount)
		"crit_chance":
			crit_rate -= amount

# 获取指定范围内的友方单位
# center_unit: 中心单位（通常是self）
# cell_range: 格子范围（曼哈顿距离）
# returns: 范围内友方单位数组（不包含自己）
func get_units_in_cell_range(center_unit: Node2D, cell_range: int) -> Array:
	var result = []
	if not GameManager.grid_manager:
		return result

	var center_x = 0
	var center_y = 0

	if "grid_pos" in center_unit:
		center_x = center_unit.grid_pos.x
		center_y = center_unit.grid_pos.y
	else:
		return result

	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		if tile.unit and is_instance_valid(tile.unit) and tile.unit != self:
			# 计算曼哈顿距离
			var dist = abs(tile.x - center_x) + abs(tile.y - center_y)
			if dist <= cell_range:
				result.append(tile.unit)

	return result
