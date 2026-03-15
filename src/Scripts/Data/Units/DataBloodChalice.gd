class_name DataBloodChalice

const DATA: Dictionary = {
	"name": "鲜血圣杯", "icon": "🏆",
	"size": [1, 1],
	"range": 0, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none", "damageType": "physical",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "blood_chalice", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 400, "cost": 60,
			"desc": "鲜血储存: 吸血溢出部分按50%储存，每秒治疗核心5点",
			"mechanics": {
				"storage_ratio": 0.5,
				"heal_per_second": 5
			}
		},
		"2": {
			"damage": 0, "hp": 600, "cost": 120,
			"desc": "鲜血储存: 吸血溢出按70%储存，每秒治疗核心8点",
			"mechanics": {
				"storage_ratio": 0.7,
				"heal_per_second": 8,
				"crit_rate_bonus": 0.1
			}
		},
		"3": {
			"damage": 0, "hp": 900, "cost": 240,
			"desc": "鲜血储存: 吸血溢出全量储存，每秒治疗核心12点",
			"mechanics": {
				"storage_ratio": 1.0,
				"heal_per_second": 12,
				"crit_rate_bonus": 0.2
			}
		}
	}
}
