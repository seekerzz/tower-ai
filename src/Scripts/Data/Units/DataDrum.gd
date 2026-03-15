class_name DataDrum

const DATA: Dictionary = {
	"name": "战鼓", "icon": "🥁",
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none", "buffProvider": "speed",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "drum", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 40,
			"desc": "邻接:攻速+20%",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 80,
			"desc": "邻接:攻速+20%",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 160,
			"desc": "邻接:攻速+20%",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
