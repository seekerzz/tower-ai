class_name DataBee

const DATA: Dictionary = {
	"name": "蜜蜂", "icon": "🐝",
	"range": 250, "atkSpeed": 0.8, "manaCost": 0,
	"attackType": "ranged", "proj": "stinger",
	"pierce": 3, "damageType": "physical",
	"crit_rate": 0.2, "crit_dmg": 1.5,
	"type_key": "bee",
	"levels": {
		"1": {
			"damage": 250, "hp": 180, "cost": 80,
			"desc": "穿透: 尖锐的蜂刺穿透敌人",
			"mechanics": {}
		},
		"2": {
			"damage": 375, "hp": 270, "cost": 160,
			"desc": "穿透: 尖锐的蜂刺穿透敌人",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 562, "hp": 405, "cost": 320,
			"desc": "穿透: 尖锐的蜂刺穿透敌人",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
