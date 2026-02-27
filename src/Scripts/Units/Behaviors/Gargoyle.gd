extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

enum State { NORMAL, PETRIFIED }
var current_state: State = State.NORMAL
var reflect_count: int = 0

func on_setup():
	GameManager.core_health_changed.connect(_check_petrify_state)
	# Initial check
	if GameManager.max_core_health > 0:
		_check_petrify_state(GameManager.core_health, GameManager.max_core_health)

func _check_petrify_state(current_hp, max_hp):
	if max_hp <= 0: return

	var health_percent = current_hp / max_hp
	if health_percent < 0.35 and current_state == State.NORMAL:
		_enter_petrified_state()
	elif health_percent > 0.65 and current_state == State.PETRIFIED:
		_exit_petrified_state()

func _enter_petrified_state():
	current_state = State.PETRIFIED
	reflect_count = 1 if unit.level < 2 else 2

	# Visual effect
	unit.modulate = Color(0.5, 0.5, 0.5) # Grey
	GameManager.spawn_floating_text(unit.global_position, "Petrified!", Color.GRAY)

func _exit_petrified_state():
	current_state = State.NORMAL
	reflect_count = 0

	# Visual effect
	unit.modulate = Color.WHITE
	GameManager.spawn_floating_text(unit.global_position, "Normal!", Color.WHITE)

func on_combat_tick(delta: float) -> bool:
	if current_state == State.PETRIFIED:
		return true # Skip attack
	return false

func on_damage_taken(amount: float, source: Node2D) -> float:
	if current_state == State.PETRIFIED and reflect_count > 0:
		var reflect_damage = amount * 0.15
		if source and source.has_method("take_damage"):
			source.take_damage(reflect_damage, unit)
			reflect_count -= 1
			GameManager.spawn_floating_text(unit.global_position, "Reflect!", Color.WHITE)
	return amount

func on_cleanup():
	if GameManager.core_health_changed.is_connected(_check_petrify_state):
		GameManager.core_health_changed.disconnect(_check_petrify_state)
