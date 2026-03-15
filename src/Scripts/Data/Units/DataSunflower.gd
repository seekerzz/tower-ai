class_name DataSunflower

const DATA: Dictionary = {
	"name": "向日葵", "icon": "🌻",
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "sunflower", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 80, "cost": 20,
			"desc": "产出:每5秒生成10法力",
			"mechanics": {"mana_per_tick": 10, "tick_interval": 5.0}
		},
		"2": {
			"damage": 0, "hp": 120, "cost": 40,
			"desc": "产出:每4秒生成18法力",
			"mechanics": {"mana_per_tick": 18, "tick_interval": 4.0}
		},
		"3": {
			"damage": 0, "hp": 180, "cost": 80,
			"desc": "产出:每4秒生成36法力(双头向日葵)",
			"mechanics": {"mana_per_tick": 36, "tick_interval": 4.0, "double_headed": true}
		}
	}
}
