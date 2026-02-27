extends Node2D

func update_visuals(type: String, stats: Dictionary):
	# Clear existing
	for c in get_children():
		c.queue_free()

	# Dispatch
	if type == "black_hole_field":
		_setup_black_hole_field(stats)
	elif type == "snowball":
		_setup_snowball()
	elif type == "web":
		_setup_web()
	elif type == "stinger":
		_setup_stinger()
	elif type == "roar":
		_setup_roar()
	elif type == "dragon_breath":
		_setup_dragon_breath()
	elif type == "pinecone":
		_setup_simple_visual(Color("8B4513"), "circle")
	elif type == "ink":
		_setup_simple_visual(Color.BLACK, "blob")
	elif type == "pollen":
		_setup_simple_visual(Color.PINK, "star")
	elif type == "feather":
		_setup_feather()
	elif type == "lightning":
		_setup_simple_visual(Color.CYAN, "line")
	elif type == "fireball":
		# Fireball falls back to dragon breath style or simple circle?
		# Original code: if type == "fireball": type = "dragon_breath" (logic in setup)
		# So we treat fireball as dragon_breath visually if requested
		_setup_dragon_breath()
	else:
		# Default fallback
		_setup_simple_visual(Color.WHITE, "circle")

	# Apply common stats
	if stats.get("hide_visuals", false):
		hide()

func _setup_black_hole_field(stats):
	var color_hex = stats.get("skillColor", "#330066")
	var color = Color(color_hex)
	modulate = color

	var poly = Polygon2D.new()
	var points = PackedVector2Array()
	var r = 20.0
	var steps = 16
	for i in range(steps):
		var angle = (i * TAU) / steps
		var rad = r + randf_range(-2, 2)
		points.append(Vector2(cos(angle), sin(angle)) * rad)

	poly.polygon = points
	poly.color = Color(1, 1, 1, 0.8)
	add_child(poly)

	var tween = create_tween().set_loops()
	tween.tween_property(poly, "rotation", TAU, 2.0).from(0.0)

func _setup_snowball():
	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	var radius = 8.0
	for i in range(16):
		var angle = (i * TAU) / 16
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = points
	circle.color = Color.WHITE
	add_child(circle)

	# Trail
	var trail = Line2D.new()
	trail.width = 4
	trail.default_color = Color(0.8, 0.9, 1.0, 0.5)
	if ResourceLoader.exists("res://src/Scripts/Effects/Trail.gd"):
		trail.set_script(load("res://src/Scripts/Effects/Trail.gd"))
	add_child(trail)

func _setup_web():
	var web = Line2D.new()
	web.width = 1.5
	web.default_color = Color.WEB_GRAY

	var points = []
	for i in range(5):
		var angle = i * (TAU / 5)
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
		points.append(Vector2.ZERO)
		points.append(Vector2(cos(angle), sin(angle)) * 5.0)

	web.points = PackedVector2Array(points)
	add_child(web)

func _setup_stinger():
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-5, -2), Vector2(10, 0), Vector2(-5, 2)])
	poly.color = Color.YELLOW

	var line = Line2D.new()
	line.points = PackedVector2Array([Vector2(-5, 0), Vector2(10, 0)])
	line.width = 1.0
	line.default_color = Color.BLACK

	add_child(poly)
	add_child(line)

func _setup_roar():
	var line = Line2D.new()
	var points = []
	var radius = 20.0
	var segments = 24
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	line.points = PackedVector2Array(points)
	line.width = 2.0
	line.default_color = Color(1.0, 1.0, 0.8, 0.4)
	line.closed = true
	add_child(line)

	var line2 = line.duplicate()
	line2.scale = Vector2(0.7, 0.7)
	add_child(line2)

func _setup_dragon_breath():
	var particles = GPUParticles2D.new()
	var material = ParticleProcessMaterial.new()

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 5.0
	material.gravity = Vector3.ZERO
	material.spread = 20.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.0))
	gradient.add_point(0.5, Color(1.0, 0.0, 0.0))
	gradient.set_color(1, Color(0.2, 0.0, 0.0, 0.0))

	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	material.color_ramp = grad_tex
	material.scale_min = 2.0
	material.scale_max = 4.0

	particles.process_material = material
	particles.lifetime = 0.5
	particles.amount = 30

	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex = ImageTexture.create_from_image(img)
	particles.texture = tex

	add_child(particles)

	var poly = Polygon2D.new()
	var pts = []
	for i in range(6):
		var angle = i * TAU / 6
		var r = randf_range(5.0, 10.0)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	poly.polygon = PackedVector2Array(pts)
	poly.color = Color(1.0, 0.4, 0.0, 0.7)
	add_child(poly)

func _setup_simple_visual(color, shape):
	var poly = Polygon2D.new()
	var points = PackedVector2Array()

	if shape == "circle":
		var radius = 6.0
		for i in range(12):
			var angle = (i * TAU) / 12
			points.append(Vector2(cos(angle), sin(angle)) * radius)
	elif shape == "blob":
		points = PackedVector2Array([
			Vector2(-4, -6), Vector2(4, -5),
			Vector2(7, 2), Vector2(2, 6),
			Vector2(-5, 5), Vector2(-7, 0)
		])
	elif shape == "triangle":
		points = PackedVector2Array([Vector2(8, 0), Vector2(-4, -4), Vector2(-4, 4)])
	elif shape == "star":
		points = PackedVector2Array([
			Vector2(6, 0), Vector2(2, 2),
			Vector2(0, 6), Vector2(-2, 2),
			Vector2(-6, 0), Vector2(-2, -2),
			Vector2(0, -6), Vector2(2, -2)
		])
	elif shape == "line":
		# Simple line visual
		var line = Line2D.new()
		line.points = PackedVector2Array([Vector2(-8, 0), Vector2(8, 0)])
		line.width = 2.0
		line.default_color = color
		add_child(line)
		return
	else:
		points = PackedVector2Array([Vector2(-4,-4), Vector2(4,-4), Vector2(4,4), Vector2(-4,4)])

	poly.polygon = points
	poly.color = color
	add_child(poly)

func _setup_feather():
	# Feather shape
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(12, 0),
		Vector2(4, -4),
		Vector2(-10, -3),
		Vector2(-8, 0),
		Vector2(-10, 3),
		Vector2(4, 4)
	])
	poly.color = Color("00CED1")

	var line = Line2D.new()
	line.points = PackedVector2Array([Vector2(-10, 0), Vector2(12, 0)])
	line.width = 1.5
	line.default_color = Color.GOLD

	var eye = Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(6, 0), Vector2(9, -2), Vector2(11, 0), Vector2(9, 2)
	])
	eye.color = Color("191970")

	add_child(poly)
	add_child(line)
	add_child(eye)
