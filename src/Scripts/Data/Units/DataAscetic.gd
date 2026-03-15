class_name DataAscetic

const DATA: Dictionary = {
	"name": "苦修者", "icon": "🧘",
	"size": [1, 1],
	"range": 150, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "ascetic", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 250, "cost": 65,
			"desc": "苦修：选择一个单位给予苦修者Buff，将受到伤害的12%转为MP",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 375, "cost": 130,
			"desc": "苦修：将受到伤害的18%转为MP",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 562, "cost": 260,
			"desc": "苦修：可以选择两个单位",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
