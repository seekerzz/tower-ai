extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var echo_chance: float = 0.3
var echo_mult: float = 1.0

func _ready():
	if Constants.CORE_TYPES.has("eagle_totem"):
		var config = Constants.CORE_TYPES["eagle_totem"]
		echo_chance = config.get("crit_echo_chance", 0.3)
		echo_mult = config.get("crit_echo_mult", 1.0)

func on_projectile_crit(projectile, target):
	if randf() < echo_chance:
		if projectile.has_method("trigger_eagle_echo"):
			var echo_damage = projectile.damage * echo_mult
			# 播放暴击回响视觉特效
			_play_crit_echo_effect(projectile, target)
			projectile.trigger_eagle_echo(target, echo_mult)
			if projectile.source_unit:
				GameManager.totem_echo_triggered.emit(projectile.source_unit, echo_damage)
				# Emit echo_triggered signal for test logging
				if GameManager.has_signal("echo_triggered"):
					GameManager.echo_triggered.emit(projectile.source_unit, target, projectile.damage, echo_damage)

func _play_crit_echo_effect(projectile, target):
	# 延迟0.1秒后触发回响效果
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(target):
		return

	var pos = target.global_position if target is Node2D else Vector2.ZERO
	var parent = target.get_parent() if target else null
	if not parent:
		return

	# 金色残影效果
	_create_gold_afterimage(pos, parent)

	# 闪电特效
	_create_lightning_effect(pos, parent)

	# "回响!"文字提示
	_show_echo_text(pos)

func _create_gold_afterimage(pos: Vector2, parent: Node):
	# 创建金色残影
	var afterimage = Node2D.new()
	afterimage.global_position = pos

	# 创建残影视觉 - 金色圆环
	var ring = Polygon2D.new()
	var points = PackedVector2Array()
	var radius = 40
	var segments = 16
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.polygon = points
	ring.color = Color(1.0, 0.84, 0.0, 0.6)  # 金色半透明
	afterimage.add_child(ring)

	parent.add_child(afterimage)

	# 动画: 放大并淡出
	var tween = afterimage.create_tween()
	tween.tween_property(afterimage, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(afterimage.queue_free)

func _create_lightning_effect(pos: Vector2, parent: Node):
	# 创建闪电状粒子
	var lightning = Node2D.new()
	lightning.global_position = pos

	# 创建多条闪电线
	for i in range(4):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = Color(1.0, 0.84, 0.0, 0.9)  # 金色

		# 生成闪电路径
		var points = PackedVector2Array()
		points.append(Vector2.ZERO)
		var segments = 5
		var length = 60
		var angle = (float(i) / 4) * TAU + randf_range(-0.3, 0.3)
		for j in range(1, segments + 1):
			var t = float(j) / segments
			var seg_pos = Vector2(cos(angle), sin(angle)) * length * t
			seg_pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
			points.append(seg_pos)
		line.points = points
		lightning.add_child(line)

	parent.add_child(lightning)

	# 动画: 快速闪烁后消失
	var tween = lightning.create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.2)
	tween.tween_callback(lightning.queue_free)

func _show_echo_text(pos: Vector2):
	# 创建"回响!"文字提示
	var label = Label.new()
	label.text = "回响!"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # 金色 #ffd700
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-25, -40)  # 居中偏移，位于伤害数字上方

	var container = Node2D.new()
	container.global_position = pos
	container.add_child(label)
	container.z_index = 150

	var scene_root = get_tree().root
	scene_root.add_child(container)

	# 动画: 上浮并淡出
	var tween = container.create_tween()
	tween.tween_property(container, "position:y", pos.y - 60, 0.8)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.8)
	tween.tween_callback(container.queue_free)
