extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var production_timer: float = 0.0

func on_setup():
	production_timer = 1.0
	# Safely connect signal, checking if already connected
	# 连接到 WaveSystemManager 的 wave_ended 信号
	if GameManager.wave_system_manager:
		if GameManager.wave_system_manager.wave_ended.is_connected(_on_wave_end):
			GameManager.wave_system_manager.wave_ended.disconnect(_on_wave_end)
		GameManager.wave_system_manager.wave_ended.connect(_on_wave_end)

	# Re-apply permanent growth - directly modify max_hp
	var growth = unit.get_meta("permanent_hp_growth", 0.0)
	if growth > 0:
		unit.stats.max_hp *= (1.0 + growth)

func on_tick(delta: float):
	production_timer -= delta
	if production_timer <= 0:
		var p_type = unit.unit_data.get("produce", "mana")
		var p_amt = unit.unit_data.get("produceAmt", 1)

		GameManager.add_resource(p_type, p_amt)

		var icon = "💎"
		var color = Color.CYAN
		GameManager.spawn_floating_text(unit.global_position, "+%d%s" % [p_amt, icon], color)

		production_timer = 1.0

func _on_wave_end(wave_number: int = 0, stats: Dictionary = {}):
	var growth = 0.05 if unit.level < 2 else 0.08
	var current = unit.get_meta("permanent_hp_growth", 0.0)
	unit.set_meta("permanent_hp_growth", current + growth)

	unit.stats.max_hp *= (1.0 + growth)
	unit.spawn_buff_effect("🌱")

func broadcast_buffs():
	if unit.level >= 3:
		_apply_nearby_hp_buff()

func _apply_nearby_hp_buff():
	if !is_instance_valid(unit): return
	var nearby = unit.get_units_in_cell_range(unit, 1)
	for u in nearby:
		# Apply HP buff directly
		u.max_hp *= 1.05
		u.spawn_buff_effect("💚")

func on_cleanup():
	if GameManager.wave_system_manager and GameManager.wave_system_manager.wave_ended.is_connected(_on_wave_end):
		GameManager.wave_system_manager.wave_ended.disconnect(_on_wave_end)
