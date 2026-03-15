class_name DataCow

const DATA: Dictionary = {
	"name": "奶牛", "icon": "🐄",
	"size": [1, 1],
	"range": 0, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none",
	"skill": "regenerate", "skillDuration": 5.0,
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "cow", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 300, "cost": 45,
			"desc": "每5秒治疗核心50",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 450, "cost": 90,
			"desc": "每5秒治疗核心50",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 675, "cost": 180,
			"desc": "每5秒治疗核心50",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
