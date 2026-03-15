class_name DataOctopus

const DATA: Dictionary = {
	"name": "八爪鱼", "icon": "🐙",
	"range": 180, "atkSpeed": 1.5, "manaCost": 0,
	"attackType": "ranged", "proj": "ink",
	"projCount": 5, "spread": 0.5,
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"has_interaction": true, "buff_id": "multishot",
	"type_key": "octopus",
	"levels": {
		"1": {
			"damage": 120, "hp": 150, "cost": 60,
			"desc": "散射: 同时喷射多道墨汁",
			"mechanics": {}
		},
		"2": {
			"damage": 180, "hp": 225, "cost": 120,
			"desc": "散射: 同时喷射多道墨汁",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 270, "hp": 337, "cost": 240,
			"desc": "散射: 同时喷射多道墨汁",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
