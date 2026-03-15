class_name DataTorch

const DATA: Dictionary = {
	"name": "红莲火炬", "icon": "🔥",
	"size": [1, 1],
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none", "buffProvider": "fire",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "torch", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 35,
			"desc": "邻接:赋予燃烧",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 70,
			"desc": "邻接:赋予燃烧",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 140,
			"desc": "邻接:赋予燃烧",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
