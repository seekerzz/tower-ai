class_name DataTiger

const DATA: Dictionary = {
	"name": "猛虎", "icon": "🐯",
	"range": 250, "atkSpeed": 1.5, "manaCost": 0,
	"attackType": "ranged", "proj": "pinecone",
	"damageType": "physical",
	"skill": "meteor_fall", "skillCd": 15, "skillDuration": 5.0,
	"type_key": "tiger", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 300, "hp": 500, "cost": 250,
			"desc": "主动：流星雨轰炸",
			"mechanics": {}
		},
		"2": {
			"damage": 450, "hp": 750, "cost": 500,
			"desc": "主动：流星雨轰炸",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 675, "hp": 1125, "cost": 1000,
			"desc": "主动：流星雨轰炸",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
