class_name DataCauldron

const DATA: Dictionary = {
	"name": "剧毒大锅", "icon": "🧪",
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none", "buffProvider": "poison",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "cauldron", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 35,
			"desc": "邻接:赋予中毒",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 70,
			"desc": "邻接:赋予中毒",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 140,
			"desc": "邻接:赋予中毒",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
