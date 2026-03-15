class_name DataHedgehog

const DATA: Dictionary = {
	"name": "刺猬", "icon": "🦔",
	"range": 80, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee",
	"trait": "reflect", "reflect_percent": 0.3,
	"damageType": "physical",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "hedgehog", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 50, "hp": 400, "cost": 40,
			"desc": "反伤30%",
			"mechanics": {}
		},
		"2": {
			"damage": 75, "hp": 600, "cost": 80,
			"desc": "反伤30%",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 112, "hp": 900, "cost": 160,
			"desc": "反伤30%",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
