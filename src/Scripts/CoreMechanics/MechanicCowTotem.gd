extends "res://src/Scripts/CoreMechanics/CoreMechanic.gd"

var timer: Timer
const TOTEM_ID: String = "cow"

func _ready():
	timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func on_core_damaged(_amount: float):
	"""核心受击时增加层数"""
	TotemManager.add_resource(TOTEM_ID, 1)

func _on_timer_timeout():
	var hit_count = TotemManager.get_resource(TOTEM_ID)
	var damage = hit_count * 5.0

	print("[CowTotem] Timeout. Hits: ", hit_count, " Damage: ", damage)

	# 清零层数（必须在计算伤害后）
	TotemManager.clear_resource(TOTEM_ID)

	if damage > 0:
		if GameManager.combat_manager:
			print("[CowTotem] Dealing global damage...")
			GameManager.combat_manager.deal_global_damage(damage, "magic")

		# Visual feedback
		GameManager.trigger_impact(Vector2.ZERO, 1.0)
		GameManager.spawn_floating_text(Vector2.ZERO, "Cow Totem: %d" % damage, Color.RED)
