extends Control

const UIConstants = preload("res://src/Scripts/Constants/UIConstants.gd")
const StyleMaker = preload("res://src/Scripts/Utils/StyleMaker.gd")

var bench_data = []

@onready var slots_container = $PanelContainer/SlotsContainer

const BENCH_UNIT_SCRIPT = preload("res://src/Scripts/UI/BenchUnit.gd")
const BENCH_SLOT_SCRIPT = preload("res://src/Scripts/UI/BenchSlot.gd")

func _ready():
	if slots_container:
		slots_container.add_theme_constant_override("h_separation", 10)
		slots_container.add_theme_constant_override("v_separation", 10)
		var parent = slots_container.get_parent()
		if parent is PanelContainer:
			var style = StyleBoxEmpty.new()
			parent.add_theme_stylebox_override("panel", style)

	# 连接 SessionData 信号
	if GameManager.session_data:
		GameManager.session_data.bench_updated.connect(_on_bench_updated)
		# 初始化时立即刷新一次暂存区显示
		_on_bench_updated(GameManager.session_data.bench_units)
	else:
		# 如果 session_data 还没初始化，延迟连接
		var _timer = get_tree().create_timer(0.1)
		_timer.timeout.connect(func():
			if GameManager.session_data:
				GameManager.session_data.bench_updated.connect(_on_bench_updated)
				_on_bench_updated(GameManager.session_data.bench_units)
		)

func _on_bench_updated(bench_units: Dictionary):
	# 转换为数组格式
	var bench_array = _bench_dict_to_array(bench_units)
	update_bench_ui(bench_array)

func _bench_dict_to_array(bench_units: Dictionary) -> Array:
	var bench_array = []
	bench_array.resize(Constants.BENCH_SIZE)
	bench_array.fill(null)
	for index in bench_units.keys():
		if index >= 0 and index < Constants.BENCH_SIZE:
			bench_array[index] = bench_units[index]
	return bench_array

func refresh_from_session_data():
	"""从 SessionData 刷新 UI，用于初始化"""
	if GameManager.session_data:
		var bench_array = _bench_dict_to_array(GameManager.session_data.bench_units)
		update_bench_ui(bench_array)

func update_bench_ui(data):
	if !slots_container: return

	bench_data = data

	# Clear existing slots
	for child in slots_container.get_children():
		slots_container.remove_child(child)
		child.queue_free()

	# Create slots using Constants.BENCH_SIZE (should be 8)
	var slot_count = Constants.BENCH_SIZE

	for i in range(slot_count):
		var slot = Control.new()
		slot.custom_minimum_size = UIConstants.CARD_SIZE.medium
		slot.set_script(BENCH_SLOT_SCRIPT)
		slot.slot_index = i

		# Visual style: Panel child
		# To make sure it is visible, we add a Panel node with StyleBoxFlat
		# and ensure it expands to fill the Control.
		var panel = Panel.new()
		panel.layout_mode = 1 # Anchors
		panel.anchors_preset = 15 # Full Rect
		panel.mouse_filter = MOUSE_FILTER_IGNORE # Let the slot handle events

		var style = StyleMaker.get_slot_style()

		panel.add_theme_stylebox_override("panel", style)
		slot.add_child(panel)

		# Add Unit if data exists
		if i < bench_data.size() and bench_data[i] != null:
			var unit_data = bench_data[i]
			var unit_display = Control.new()
			unit_display.set_script(BENCH_UNIT_SCRIPT)
			unit_display.setup(unit_data.key, i)

			# Ensure unit display fills slot but respects logic
			unit_display.layout_mode = 1
			unit_display.anchors_preset = 15

			slot.add_child(unit_display)

		slots_container.add_child(slot)
