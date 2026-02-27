extends Control

const StyleMaker = preload("res://src/Scripts/Utils/StyleMaker.gd")
const UIConstants = preload("res://src/Scripts/Constants/UIConstants.gd")
const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

const SLOT_COUNT = 9

@onready var slots_container = $PanelContainer/SlotsContainer

func _ready():
	print("[InventoryPanel] UI Ready initialized.") # 调试日志
	
	if slots_container:
		slots_container.add_theme_constant_override("h_separation", 10)
		slots_container.add_theme_constant_override("v_separation", 10)

		# Set Columns
		if slots_container is GridContainer:
			slots_container.columns = 3

		var parent = slots_container.get_parent()

		# Dynamic ScrollContainer Check
		if not parent is ScrollContainer:
			print("[InventoryPanel] Creating dynamic ScrollContainer.")
			var scroll = ScrollContainer.new()
			scroll.name = "InvScrollContainer"
			scroll.layout_mode = 1
			scroll.anchors_preset = Control.PRESET_FULL_RECT
			scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

			# Min height for scrolling to be useful
			scroll.custom_minimum_size.y = 200 # Adjust as needed

			var grandparent = parent.get_parent()
			# Move slots_container into scroll
			slots_container.reparent(scroll)

			# Replace parent (likely just a PanelContainer logic wrapper) logic
			# Actually, the hierarchy is likely: InventoryPanel (Control) -> PanelContainer -> SlotsContainer
			# We want: InventoryPanel -> PanelContainer -> ScrollContainer -> SlotsContainer

			parent.add_child(scroll)

			# Ensure Scroll fills parent
			scroll.set_anchors_preset(Control.PRESET_FULL_RECT)

		if parent is PanelContainer:
			var style = StyleBoxEmpty.new()
			parent.add_theme_stylebox_override("panel", style)
	else:
		push_error("[InventoryPanel] Error: SlotsContainer not found!")

	_init_slots()

	# 连接信号
	if GameManager.get("inventory_manager") and GameManager.inventory_manager:
		var inv_mgr = GameManager.inventory_manager
		if !inv_mgr.is_connected("inventory_updated", update_inventory):
			inv_mgr.connect("inventory_updated", update_inventory)
			print("[InventoryPanel] Connected to inventory_manager signal.")
		
		# 初始加载
		if inv_mgr.has_method("get_inventory"):
			update_inventory(inv_mgr.get_inventory())
		else:
			push_error("[InventoryPanel] InventoryManager missing get_inventory() method.")

func _init_slots():
	if !slots_container: return
	for child in slots_container.get_children():
		child.queue_free()

	var drag_handler_script = preload("res://src/Scripts/UI/ItemDragHandler.gd")

	for i in range(SLOT_COUNT):
		var slot = Control.new()
		slot.set_script(drag_handler_script)
		slot.custom_minimum_size = UIConstants.CARD_SIZE.medium
		slot.name = "Slot_%d" % i

		var panel = Panel.new()
		panel.layout_mode = 1
		panel.anchors_preset = 15
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		var style = StyleMaker.get_slot_style()
		panel.add_theme_stylebox_override("panel", style)
		slot.add_child(panel)

		slots_container.add_child(slot)

func update_inventory(data: Array):
	# 调试日志：打印接收到的数据
	print("[InventoryPanel] update_inventory called with data: ", data)
	
	if !slots_container: return

	var slots = slots_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		# 清理旧图标（保留背景 Panel）
		for child in slot.get_children():
			if child is Panel: continue
			child.queue_free()

		if i < data.size() and data[i] != null:
			var item = data[i]

			if slot.get_script() == preload("res://src/Scripts/UI/ItemDragHandler.gd"):
				slot.slot_index = i
				slot.item_data = item

			var item_id = item.get("item_id", "unknown")
			
			# 尝试加载图标
			var icon_rect = TextureRect.new()
			var icon = AssetLoader.get_item_icon(item_id) if item_id else null
			
			if icon:
				icon_rect.texture = icon
			else:
				# --- 关键修改：如果图片缺失，显示红色文字 ---
				print("[InventoryPanel] Warning: Missing icon for item: ", item_id)
				var text_fallback = Label.new()
				text_fallback.text = str(item_id)
				text_fallback.modulate = Color(1, 0, 0, 1) # 红色
				text_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				text_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				text_fallback.layout_mode = 1
				text_fallback.anchors_preset = 15
				slot.add_child(text_fallback)

			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.layout_mode = 1
			icon_rect.anchors_preset = 15
			icon_rect.offset_left = 5
			icon_rect.offset_top = 5
			icon_rect.offset_right = -5
			icon_rect.offset_bottom = -5
			slot.add_child(icon_rect)

			# 显示数量
			if item.get("count", 0) > 1:
				var count_lbl = Label.new()
				count_lbl.text = str(item.count)
				count_lbl.add_theme_font_size_override("font_size", 14)
				count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				count_lbl.layout_mode = 1
				count_lbl.anchors_preset = 15
				count_lbl.offset_right = -4
				count_lbl.offset_bottom = 0
				slot.add_child(count_lbl)
		else:
			# Slot is empty, clear data
			if slot.get_script() == preload("res://src/Scripts/UI/ItemDragHandler.gd"):
				slot.slot_index = -1
				slot.item_data = {}
