class_name SummonedUnit
extends "res://src/Scripts/Unit.gd"

@export var lifetime: float = 25.0
@export var is_clone: bool = false
@export var summon_source: Unit = null

var lifetime_timer: Timer

signal summon_expired(summon: SummonedUnit)
signal summon_killed(summon: SummonedUnit)

func _ready():
	super._ready()
	is_summoned = true

	# 视觉区分
	modulate = Color(1, 1, 1, 0.7)

	# Initialize current_hp from max_hp which might be set by setup() or manager
	current_hp = max_hp

	if lifetime > 0:
		lifetime_timer = Timer.new()
		lifetime_timer.wait_time = lifetime
		lifetime_timer.timeout.connect(_on_lifetime_expired)
		lifetime_timer.one_shot = true
		add_child(lifetime_timer)
		lifetime_timer.start()

func _on_lifetime_expired():
	summon_expired.emit(self)
	queue_free()

func take_damage(amount: float, source_enemy = null):
	# Summoned units take damage themselves, not the core
	if "guardian_shield" in active_buffs:
		var source = buff_sources.get("guardian_shield")
		if source and is_instance_valid(source) and source.behavior:
			var reduction = source.behavior.get_damage_reduction() if source.behavior.has_method("get_damage_reduction") else 0.05
			amount = amount * (1.0 - reduction)

	# Apply damage
	current_hp -= amount

	if visual_holder:
		var tween = create_tween()
		tween.tween_property(visual_holder, "modulate", Color(1, 0, 0, 0.7), 0.1)
		tween.tween_property(visual_holder, "modulate", Color(1, 1, 1, 0.7), 0.1)

	if current_hp <= 0:
		_die()

func _die():
	summon_killed.emit(self)
	queue_free()
