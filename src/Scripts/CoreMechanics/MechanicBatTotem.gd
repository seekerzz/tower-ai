class_name MechanicBatTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var target_count: int = 3
@export var bleed_stacks_per_hit: int = 1

func _ready():
	var timer = Timer.new()
	timer.wait_time = attack_interval
	timer.autostart = true
	timer.timeout.connect(_on_totem_attack)
	add_child(timer)

func _on_totem_attack():
	if !GameManager.is_wave_active: return

	var targets = get_nearest_enemies(target_count)
	for enemy in targets:
		if is_instance_valid(enemy) and enemy.has_method("add_bleed_stacks"):
			enemy.add_bleed_stacks(bleed_stacks_per_hit, self)
			_play_bat_attack_effect(enemy)

func _play_bat_attack_effect(enemy):
	# Visual effect for bleed application
	GameManager.spawn_floating_text(enemy.global_position, "Bleed!", Color.RED, Vector2.UP)
