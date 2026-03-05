extends Control

const AssetLoader = preload("res://src/Scripts/Utils/AssetLoader.gd")

var slot_index: int = -1
var item_data: Dictionary = {}

func _get_drag_data(at_position):
	if item_data.is_empty():
		return null

	# Create drag preview
	var preview = TextureRect.new()
	var item_id = item_data.get("item_id", "")
	var icon = AssetLoader.get_item_icon(item_id) if AssetLoader else null

	if icon:
		preview.texture = icon
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = Vector2(40, 40)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Center the preview on mouse
		var c = Control.new()
		c.add_child(preview)
		preview.position = -preview.size / 2
		set_drag_preview(c)

	return {
		"source": "inventory",
		"item": item_data,
		"slot_index": slot_index
	}

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if !item_data.is_empty():
				var id = item_data.get("item_id", "")
				if id != "":
					# Use item
					if GameManager.use_item_effect(id):
						# If used successfully, remove or decrease count
						# But wait, does 'use_item_effect' imply consumption?
						# Prompt: "触发“使用物品”，调用 GameManager.use_item_effect(id)。"
						# Usually items are consumed.
						# Item Types are "consumable" or "target_unit".
						# Let's assume we consume one.

						# Remove 1 from inventory
						if GameManager.inventory_manager:
							GameManager.inventory_manager.remove_item(slot_index)
