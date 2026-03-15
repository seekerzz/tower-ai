class_name DataPlant

const DATA: Dictionary = {
	"name": "向日葵", "icon": "🌻",
	"range": 0, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none",
	"produce": "mana", "produceAmt": 60,
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "plant", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 50, "cost": 20,
			"desc": "产出:法力值+60/s",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 75, "cost": 40,
			"desc": "产出:法力值+60/s",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 112, "cost": 80,
			"desc": "产出:法力值+60/s",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
