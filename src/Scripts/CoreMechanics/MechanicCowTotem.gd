extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var hit_count: int = 0
var timer: Timer

func _ready():
	timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func on_core_damaged(amount: float):
	hit_count += 1

func _on_timer_timeout():
	var damage = hit_count * 5.0
	print("[CowTotem] Timeout. Hits: ", hit_count, " Damage: ", damage)
	hit_count = 0 # Reset count immediately for next cycle

	if damage > 0:
		if GameManager.combat_manager:
			print("[CowTotem] Dealing global damage...")
			GameManager.combat_manager.deal_global_damage(damage, "magic")

		# Visual feedback
		GameManager.trigger_impact(Vector2.ZERO, 1.0)
		GameManager.spawn_floating_text(Vector2.ZERO, "Cow Totem: %d" % damage, Color.RED)
