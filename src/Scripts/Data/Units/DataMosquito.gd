class_name DataMosquito

const DATA: Dictionary = {
	"name": "蚊子", "icon": "🦟",
	"size": [1, 1],
	"range": 200, "atkSpeed": 1.5, "manaCost": 0,
	"attackType": "ranged", "proj": "dot",
	"trait": "lifesteal", "lifesteal_percent": 0.2,
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "mosquito", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 20, "hp": 50, "cost": 25,
			"desc": "造成伤害治疗核心20%",
			"mechanics": {"lifesteal_percent": 0.2}
		},
		"2": {
			"damage": 30, "hp": 75, "cost": 50,
			"desc": "造成伤害治疗核心25%",
			"mechanics": {"crit_rate_bonus": 0.1, "lifesteal_percent": 0.25}
		},
		"3": {
			"damage": 45, "hp": 112, "cost": 100,
			"desc": "造成伤害治疗核心30%",
			"mechanics": {"crit_rate_bonus": 0.2, "lifesteal_percent": 0.3}
		}
	}
}
