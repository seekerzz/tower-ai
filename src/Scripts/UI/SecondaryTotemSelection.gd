extends Control

## 次级图腾选择界面
## 在击败第1个Boss（第6波）后显示，允许玩家选择次级图腾

const CoreCardScene = preload("res://src/Scenes/UI/CoreCard.tscn")

@onready var container = $ScrollContainer/HBoxContainer
@onready var title_label = $TitleLabel

# 可用图腾列表（排除主图腾）
var available_totems: Array = []

# 选择完成回调
var on_selection_completed: Callable

func _ready():
	# 设置标题
	if title_label:
		title_label.text = "选择次级图腾"

	# 获取主图腾
	var main_totem = GameManager.core_type if GameManager.core_type else ""

	# 构建可用图腾列表（排除主图腾）
	var all_totems = ["wolf_totem", "cow_totem", "bat_totem", "viper_totem", "butterfly_totem", "eagle_totem"]
	available_totems = all_totems.filter(func(totem): return totem != main_totem)

	print("[SecondaryTotemSelection] 主图腾: ", main_totem)
	print("[SecondaryTotemSelection] 可用次级图腾: ", available_totems)

	# 暂停游戏
	get_tree().paused = true

	# 创建图腾卡片
	_create_cards()

	# 广播消息给AI
	if AIManager:
		_send_selection_to_ai()

func _create_cards():
	var core_data = Constants.CORE_TYPES
	if core_data.is_empty():
		push_error("[SecondaryTotemSelection] CORE_TYPES not found in Constants!")
		return

	for totem_id in available_totems:
		if core_data.has(totem_id):
			var data = core_data[totem_id]
			var card = CoreCardScene.instantiate()

			container.add_child(card)
			card.setup(totem_id, data)
			card.card_selected.connect(_on_totem_selected)

func _on_totem_selected(totem_id: String):
	"""玩家选择了次级图腾"""
	print("[SecondaryTotemSelection] 选择了次级图腾: ", totem_id)

	# 设置次级图腾
	if GameManager.session_data:
		GameManager.session_data.secondary_totem = totem_id
		print("[SecondaryTotemSelection] 已设置 secondary_totem = ", totem_id)

		# 广播选择结果
		if AIManager:
			var totem_name = _get_totem_name(totem_id)
			AIManager.broadcast_text("【次级图腾】选择了 %s 作为次级图腾！商店现在会刷新该阵营的单位。" % totem_name)

		# 初始化次级图腾机制
		GameManager._initialize_secondary_mechanic()

	# 恢复游戏
	get_tree().paused = false

	# 触发选择完成回调
	if on_selection_completed.is_valid():
		on_selection_completed.call(totem_id)

	# 关闭选择界面
	queue_free()

func _send_selection_to_ai():
	"""发送选择信息给AI客户端"""
	var totem_info = _get_totem_info()
	var info_text = ""
	for totem_id in totem_info:
		info_text += "\n- %s (%s): %s" % [totem_info[totem_id]["name"], totem_id, totem_info[totem_id]["description"]]

	var main_totem_name = _get_totem_name(GameManager.core_type)
	var message = "【次级图腾选择】击败第1个Boss！请选择次级图腾（主图腾是 %s）。可选图腾：%s" % [main_totem_name, info_text]
	AIManager.broadcast_text(message)

func _get_totem_info() -> Dictionary:
	"""获取可用图腾信息"""
	var info = {}
	var core_data = Constants.CORE_TYPES
	for totem_id in available_totems:
		if core_data.has(totem_id):
			info[totem_id] = {
				"name": core_data[totem_id].get("name", totem_id),
				"description": core_data[totem_id].get("description", "")
			}
	return info

func _get_totem_name(totem_id: String) -> String:
	"""获取图腾显示名称"""
	var core_data = Constants.CORE_TYPES
	if core_data.has(totem_id):
		return core_data[totem_id].get("name", totem_id)
	return totem_id

## 静态方法：检查是否应该显示次级图腾选择
static func should_show_selection() -> bool:
	"""检查是否应该显示次级图腾选择界面"""
	if not GameManager.session_data:
		return false

	# 第6波击败后显示（第1个Boss）
	var current_wave = GameManager.session_data.wave
	var has_secondary = GameManager.session_data.has_secondary_totem

	# 在第7波开始时（即第6波结束后），且还没有次级图腾
	return current_wave == 7 and not has_secondary

## 静态方法：创建并显示选择界面
static func show_selection(parent: Node, callback: Callable = Callable()) -> Control:
	"""创建并显示次级图腾选择界面"""
	var scene = load("res://src/Scenes/UI/SecondaryTotemSelection.tscn")
	if not scene:
		push_error("[SecondaryTotemSelection] 无法加载场景文件")
		return null

	var instance = scene.instantiate()
	if callback.is_valid():
		instance.on_selection_completed = callback

	parent.add_child(instance)
	return instance
