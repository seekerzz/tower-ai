class_name MechanicWolfTotem
extends BaseTotemMechanic

@export var attack_interval: float = 5.0
@export var base_damage: int = 15

const TOTEM_ID: String = "wolf"

func _ready():
	var timer = Timer.new()
	timer.wait_time = attack_interval
	timer.timeout.connect(_on_totem_attack)
	add_child(timer)
	timer.start()

	# 连接信号以获取魂魄
	GameManager.enemy_died.connect(_on_enemy_died)
	GameManager.unit_upgraded.connect(_on_unit_upgraded)

func _on_enemy_died(_enemy, _killer_unit):
	"""击杀敌人时增加魂魄"""
	TotemManager.add_resource(TOTEM_ID, 1)

func _on_unit_upgraded(_unit, _old_level, _new_level):
	"""单位合成/升级时增加魂魄"""
	TotemManager.add_resource(TOTEM_ID, 10)

func _on_totem_attack():
	var targets = get_nearest_enemies(3)
	var soul_bonus = TotemManager.get_resource(TOTEM_ID)
	for enemy in targets:
		var damage = base_damage + soul_bonus
		deal_damage(enemy, damage)
