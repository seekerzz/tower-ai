class_name DataBloodRitualist

const DATA: Dictionary = {
	"name": "血祭术士", "icon": "🔮",
	"range": 250, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "ranged", "proj": "blood_orb",
	"skill": "blood_ritual", "skillCd": 12.0,
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "blood_ritualist", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 60, "hp": 220, "cost": 70,
			"desc": "血祭仪式: 消耗20%核心生命，对范围内(150)敌人施加2层流血",
			"mechanics": {
				"health_cost_ratio": 0.2,
				"bleed_stacks": 2,
				"aoe_range": 150
			}
		},
		"2": {
			"damage": 90, "hp": 330, "cost": 140,
			"desc": "血祭仪式: 消耗20%核心生命，对范围内(180)敌人施加3层流血",
			"mechanics": {
				"health_cost_ratio": 0.2,
				"bleed_stacks": 3,
				"aoe_range": 180,
				"crit_rate_bonus": 0.1
			}
		},
		"3": {
			"damage": 135, "hp": 495, "cost": 280,
			"desc": "血祭仪式: 消耗20%核心生命，对范围内(200)敌人施加4层流血，4秒内全体吸血×2",
			"mechanics": {
				"health_cost_ratio": 0.2,
				"bleed_stacks": 4,
				"aoe_range": 200,
				"lifesteal_multiplier": 2.0,
				"buff_duration": 4.0,
				"crit_rate_bonus": 0.2
			}
		}
	}
}
