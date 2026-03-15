class_name DataShell

const DATA: Dictionary = {
	"name": "贝壳", "icon": "🐚",
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "shell", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 200, "cost": 40,
			"desc": "珍珠:承受5次以下伤害，波次结束获得50金币",
			"mechanics": {"hit_threshold": 5, "pearl_value": 50}
		},
		"2": {
			"damage": 0, "hp": 300, "cost": 80,
			"desc": "珍珠:承受8次以下伤害，波次结束获得75金币",
			"mechanics": {"hit_threshold": 8, "pearl_value": 75}
		},
		"3": {
			"damage": 0, "hp": 450, "cost": 160,
			"desc": "珍珠:承受8次以下伤害，波次结束获得100金币。邻接单位减伤5%",
			"mechanics": {"hit_threshold": 8, "pearl_value": 100, "damage_reduction_aura": 0.05}
		}
	}
}
