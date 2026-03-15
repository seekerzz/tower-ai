class_name DataWolf

const DATA: Dictionary = {
	"name": "野狼", "icon": "🐺",
	"range": 100, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "wolf", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 100, "hp": 300, "cost": 100,
			"desc": "吞噬单位继承属性",
			"mechanics": {}
		},
		"2": {
			"damage": 150, "hp": 450, "cost": 200,
			"desc": "吞噬单位继承属性",
			"mechanics": {"crit_rate_bonus": 0.1}
		}
	}
}
