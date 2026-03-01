extends Node

## Narrative Logger
## Generates natural language narratives and structured JSON arrays out of raw game signals

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_game_signals()

func _connect_game_signals():
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.damage_dealt.connect(_on_damage_dealt)
	GameManager.enemy_died.connect(_on_enemy_died)

func _on_wave_started():
	var wave = GameManager.wave
	var narrative = "【波次事件】第 %d 波战斗正式开始！" % wave
	_build_and_broadcast("WaveStarted", narrative, {"wave": wave})

func _on_wave_ended():
	var wave = GameManager.wave
	var narrative = "【波次事件】第 %d 波战斗结束，进入备战阶段。" % wave
	_build_and_broadcast("WaveEnded", narrative, {"wave": wave})

func _on_damage_dealt(unit, amount: float):
	if unit == null and amount > 0:
		var narrative = "【核心受击】图腾核心受到了 %.1f 点伤害！" % amount
		var core_health = GameManager.core_health
		var max_health = GameManager.max_core_health
		_build_and_broadcast("CoreDamaged", narrative, {
			"damage": amount,
			"health": core_health,
			"max_health": max_health
		})

func _on_enemy_died(enemy, _killer):
	if is_instance_valid(enemy):
		var type_key = enemy.type_key if "type_key" in enemy else "unknown"
		var hp = enemy.max_hp if "max_hp" in enemy else 0
		var narrative = "【敌方阵亡】敌人 %s 被消灭了。" % type_key
		_build_and_broadcast("EnemyDied", narrative, {
			"enemy_type": type_key,
			"max_hp": hp
		})

func _build_and_broadcast(event_type: String, narrative: String, data: Dictionary):
	print("[Narrative] " + narrative)

	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text(narrative)
