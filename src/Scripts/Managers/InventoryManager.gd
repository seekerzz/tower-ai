extends Node

class_name InventoryManager

# 1. 修改信号定义，增加 items 参数
signal inventory_updated(items)

const MAX_SLOTS = 8
const COLS = 4

# Schema: { "item_id": String, "icon": String, "skill_source": String (optional), "count": int }
var items: Array = []

func _init():
	items.resize(MAX_SLOTS)
	items.fill(null)

# 2. 添加缺失的接口方法，供 InventoryPanel 初始化调用
func get_inventory() -> Array:
	return items

func add_item(item_data: Dictionary) -> bool:
	# Try to stack first
	for i in range(MAX_SLOTS):
		if items[i] != null and items[i].get("item_id") == item_data.get("item_id"):
			items[i].count += item_data.get("count", 1)
			# 3. 发送信号时传递 items 数据
			inventory_updated.emit(items)
			return true

	# Find empty slot
	for i in range(MAX_SLOTS):
		if items[i] == null:
			items[i] = item_data.duplicate()
			if not items[i].has("count"):
				items[i]["count"] = 1
			# 3. 发送信号时传递 items 数据
			inventory_updated.emit(items)
			return true

	return false

func remove_item(index: int):
	if index >= 0 and index < MAX_SLOTS:
		if items[index] != null:
			items[index].count -= 1
			if items[index].count <= 0:
				items[index] = null
			# 3. 发送信号时传递 items 数据
			inventory_updated.emit(items)

func get_item(index: int):
	if index >= 0 and index < MAX_SLOTS:
		return items[index]
	return null

func get_item_count(index: int) -> int:
	var item = get_item(index)
	if item:
		return item.count
	return 0

func is_full() -> bool:
	for item in items:
		if item == null:
			return false
	return true
