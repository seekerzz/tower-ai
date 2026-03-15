class_name DataSquirrel

const DATA: Dictionary = {
	"name": "松鼠", "icon": "🐿️",
	"size": [1, 1],
	"range": 250, "atkSpeed": 0.15, "manaCost": 0,
	"attackType": "ranged", "proj": "pinecone",
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "squirrel", "faction": "universal",
	"levels": {
		"1": {
			"damage": 30, "hp": 100, "cost": 15,
			"desc": "远程: 快速投掷松果",
			"mechanics": {}
		},
		"2": {
			"damage": 45, "hp": 150, "cost": 30,
			"desc": "远程: 快速投掷松果",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 67, "hp": 225, "cost": 60,
			"desc": "远程: 快速投掷松果",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
