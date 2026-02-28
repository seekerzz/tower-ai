extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

# Sunflower - 向日葵
# Periodic mana generation unit
# Lv3: Double mana generation (Twin-Headed)

var mana_per_tick: int = 10
var tick_interval: float = 5.0
var tick_timer: float = 0.0
var is_double_headed: bool = false

func on_setup():
	# Set level-based stats
	match unit.level:
		1:
			mana_per_tick = 10
			tick_interval = 5.0
			is_double_headed = false
		2:
			mana_per_tick = 18
			tick_interval = 4.0
			is_double_headed = false
		3:
			mana_per_tick = 18
			tick_interval = 4.0
			is_double_headed = true  # Double-headed: generates twice per tick

	tick_timer = tick_interval

func on_tick(delta: float):
	tick_timer -= delta
	if tick_timer <= 0:
		_generate_mana()
		tick_timer = tick_interval

func _generate_mana():
	var total_mana = mana_per_tick

	# Lv3: Double generation (Twin-Headed)
	if is_double_headed:
		total_mana *= 2

	# Add mana to player resources
	GameManager.add_resource("mana", total_mana)

	# Visual feedback
	var icon = "💧"
	var color = Color.CYAN
	GameManager.spawn_floating_text(unit.global_position, "+%d%s" % [total_mana, icon], color)

	# Show sunflower effect
	if is_double_headed:
		unit.spawn_buff_effect("🌻🌻")
	else:
		unit.spawn_buff_effect("🌻")
