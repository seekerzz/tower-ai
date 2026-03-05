extends Control

## 狼单位吞噬选择UI
## 允许玩家选择要吞噬的单位

var wolf_unit: Unit = null
var unit_buttons: Array = []

@onready var unit_list = $Panel/ScrollContainer/UnitList

func _ready():
	# 确保可见
	visible = true
	z_index = 100

func show_for_wolf(wolf: Unit):
	wolf_unit = wolf
	_populate_unit_list()

func _populate_unit_list():
	# 清空现有按钮
	for child in unit_list.get_children():
		child.queue_free()
	unit_buttons.clear()

	# 获取所有玩家单位
	if not GameManager.grid_manager:
		_auto_select_and_close()
		return

	var found_units = false
	for key in GameManager.grid_manager.tiles:
		var tile = GameManager.grid_manager.tiles[key]
		var unit = tile.unit
		if unit and unit != wolf_unit and is_instance_valid(unit):
			found_units = true
			_create_unit_button(unit)

	if not found_units:
		_auto_select_and_close()

func _create_unit_button(unit: Unit):
	var button = Button.new()
	var unit_name = unit.unit_data.get("name", unit.type_key.capitalize())
	button.text = "%s (Lv.%d)" % [unit_name, unit.level]
	button.custom_minimum_size = Vector2(0, 40)

	# 连接点击事件
	button.pressed.connect(_on_unit_selected.bind(unit))

	unit_list.add_child(button)
	unit_buttons.append(button)

func _on_unit_selected(unit: Unit):
	if wolf_unit and is_instance_valid(wolf_unit):
		wolf_unit.devour_target(unit)
	queue_free()

func _auto_select_and_close():
	# 没有可选单位，自动选择最近的
	if wolf_unit and is_instance_valid(wolf_unit):
		wolf_unit._auto_devour()
	queue_free()

func _on_cancel_pressed():
	# 取消选择，自动选择
	_auto_select_and_close()
