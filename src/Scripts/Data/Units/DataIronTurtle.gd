class_name DataIronTurtle

const DATA: Dictionary = {
	"name": "铁甲龟", "icon": "🐢🛡️",
	"size": [1, 1],
	"range": 80, "atkSpeed": 0.8, "manaCost": 0,
	"attackType": "melee",
	"trait": "flat_reduce", "flat_amount": 20,
	"damageType": "physical",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "iron_turtle", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 20, "hp": 600, "cost": 50,
			"desc": "固定减伤20",
			"mechanics": {}
		},
		"2": {
			"damage": 30, "hp": 900, "cost": 100,
			"desc": "固定减伤20",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 45, "hp": 1350, "cost": 200,
			"desc": "固定减伤20",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
