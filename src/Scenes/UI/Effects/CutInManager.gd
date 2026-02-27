extends Control

const CutInItemScene = preload("res://src/Scenes/UI/Effects/CutInItem.tscn")
const ITEM_HEIGHT = 120.0
const SPACING_DEFAULT = 5.0

# Available area for items
var available_height: float = 0.0

func _ready():
	# Default initial height if not set by MainGUI yet
	available_height = size.y

func update_area(rect: Rect2):
	# Optimize: only reorganize if changed
	if position == rect.position and size == rect.size:
		return

	# Update own position and size
	position = rect.position
	size = rect.size
	available_height = rect.size.y

	# Trigger reorganize
	reorganize_items()

func trigger_cutin(unit):
	var item = CutInItemScene.instantiate()
	add_child(item)
	item.setup(unit)

	# Connect to finished signal or queue_free to reorganize when item leaves?
	# Usually item calls queue_free() in animate_exit.
	# We want to reorganize when items are added OR removed.
	# But queue_free happens at end of frame.
	# We can use tree_exited signal, but that might be too late for visual smoothness if many items?
	# Actually, animate_exit moves the item out, then frees it.
	# So strictly speaking, it's still in the list until freed.
	# If we filter out items that are "exiting"?
	# For simplicity, we reorganize immediately on add.
	item.tree_exited.connect(reorganize_items)

	reorganize_items()

func reorganize_items():
	var children = []
	for child in get_children():
		if child.is_queued_for_deletion(): continue
		# If child is exiting (animate_exit called), do we still count it?
		# Usually yes, until it's gone.
		children.append(child)

	var count = children.size()
	if count == 0: return

	# We want Newest (last in list) at the BOTTOM.
	# Oldest (first in list) at the TOP (if compressed) or stacked above.

	# Calculate step (vertical distance between items)
	# Default step is ITEM_HEIGHT + SPACING
	# If we have limited space, we compress.

	var total_height_needed = count * ITEM_HEIGHT # Assuming simplified strict stacking
	# Actually, if we stack with standard spacing, height needed is (count * (ITEM_HEIGHT + SPACING)) - SPACING

	# Formula for step:
	# If strictly stacking: step = ITEM_HEIGHT + SPACING
	# If overlapping: step = (available_height - ITEM_HEIGHT) / (count - 1)

	var step = ITEM_HEIGHT + SPACING_DEFAULT

	if count > 1:
		var max_possible_step = (available_height - ITEM_HEIGHT) / float(count - 1)
		step = min(step, max_possible_step)

	# If available_height is very small (e.g. 0), step might be negative?
	# Keep step logical.
	# If step is negative, items will overlap in reverse or weirdly.
	# But visually we just want them to fit.

	for i in range(count):
		var child = children[i]

		# Index i: 0 is Oldest, count-1 is Newest.
		# Newest should be at Bottom: y = available_height - ITEM_HEIGHT
		# Previous items stacked above.

		# y_i = (Bottom Y of Newest) - (Distance from Newest)
		# Distance from Newest = (count - 1 - i) * step

		var target_y = (available_height - ITEM_HEIGHT) - ((count - 1 - i) * step)

		# Animate to position
		var tween = create_tween()
		tween.tween_property(child, "position:y", target_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
