class_name DataOxpecker

const DATA: Dictionary = {
	"name": "牛椋鸟", "icon": "🐦",
	"size": [1, 1],
	"range": 300, "atkSpeed": 1.0,
	"attackType": "ranged",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "oxpecker", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 10, "hp": 100, "cost": 50,
			"desc": "可附身于其他单位，协助宿主攻击",
			"mechanics": {}
		},
		"2": {
			"damage": 20, "hp": 150, "cost": 100,
			"desc": "可附身于其他单位，协助宿主攻击",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 40, "hp": 225, "cost": 200,
			"desc": "可附身于其他单位，协助宿主攻击",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
