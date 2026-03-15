class_name DataMeat

const DATA: Dictionary = {
	"name": "五花肉", "icon": "🥓",
	"size": [1, 1],
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"isFood": true, "xp": 50,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "meat", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 10, "cost": 10,
			"desc": "喂食获得大量Buff",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 15, "cost": 20,
			"desc": "喂食获得大量Buff",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 22, "cost": 40,
			"desc": "喂食获得大量Buff",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
