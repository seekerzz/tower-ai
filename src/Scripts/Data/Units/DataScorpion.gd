class_name DataScorpion

const DATA: Dictionary = {
	"name": "蝎子", "icon": "🦂",
	"range": 200, "atkSpeed": 1.0,
	"attackType": "ranged", "proj": "stinger",
	"type_key": "scorpion", "faction": "viper_totem",
	"levels": {
		"1": {
			"damage": 30, "cost": 40,
			"desc": "部署时放置尖牙陷阱",
			"mechanics": {}
		},
		"2": {
			"damage": 45, "cost": 80,
			"desc": "部署时放置尖牙陷阱",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 67, "cost": 160,
			"desc": "部署时放置尖牙陷阱",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
