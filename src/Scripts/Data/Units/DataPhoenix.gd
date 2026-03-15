class_name DataPhoenix

const DATA: Dictionary = {
	"name": "凤凰", "icon": "🦅",
	"size": [1, 1],
	"range": 300, "atkSpeed": 0.6, "manaCost": 0,
	"attackType": "ranged", "proj": "fire", "splash": 40,
	"skill": "firestorm", "skillCd": 20,
	"skillType": "point", "skillId": "firestorm",
	"targetType": "ground", "targetArea": [3, 3],
	"damageType": "fire",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "phoenix", "faction": "butterfly_totem",
	"levels": {
		"1": {
			"damage": 250, "hp": 250, "cost": 150,
			"desc": "远程:AOE轰炸\n技能:火雨(300💧)",
			"mechanics": {}
		},
		"2": {
			"damage": 375, "hp": 375, "cost": 300,
			"desc": "远程:AOE轰炸\n技能:火雨(300💧)",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 562, "hp": 562, "cost": 600,
			"desc": "远程:AOE轰炸\n技能:火雨(300💧)",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
