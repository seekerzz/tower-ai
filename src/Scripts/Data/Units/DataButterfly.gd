class_name DataButterfly

const DATA: Dictionary = {
	"name": "蝴蝶", "icon": "🦋",
	"range": 350, "atkSpeed": 1.2, "manaCost": 50,
	"attackType": "ranged", "proj": "pollen", "splash": 30,
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "butterfly", "faction": "butterfly_totem",
	"levels": {
		"1": {
			"damage": 600, "hp": 150, "cost": 50,
			"desc": "魔法: 消耗法力释放强力花粉",
			"mechanics": {}
		},
		"2": {
			"damage": 900, "hp": 225, "cost": 100,
			"desc": "魔法: 消耗法力释放强力花粉",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 1350, "hp": 337, "cost": 200,
			"desc": "魔法: 消耗法力释放强力花粉",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
