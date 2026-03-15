class_name DataSpider

const DATA: Dictionary = {
	"name": "蜘蛛", "icon": "🕷️",
	"size": [1, 1],
	"range": 250, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "ranged", "proj": "web",
	"trait": "slow", "damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "spider", "faction": "universal",
	"levels": {
		"1": {
			"damage": 30, "hp": 180, "cost": 40,
			"desc": "攻击概率生成蜘蛛网陷阱",
			"mechanics": {}
		},
		"2": {
			"damage": 45, "hp": 270, "cost": 80,
			"desc": "攻击概率生成蜘蛛网陷阱",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 67, "hp": 405, "cost": 160,
			"desc": "攻击概率生成蜘蛛网陷阱",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
