class_name DataViper

const DATA: Dictionary = {
	"name": "毒蛇", "icon": "🐍",
	"size": [1, 1],
	"range": 80, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "melee",
	"trait": "poison_touch", "damageType": "poison",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"has_interaction": true, "buff_id": "poison",
	"type_key": "viper", "faction": "viper_totem",
	"levels": {
		"1": {
			"damage": 40, "hp": 150, "cost": 30,
			"desc": "部署时放置毒液陷阱",
			"mechanics": {}
		},
		"2": {
			"damage": 60, "hp": 225, "cost": 60,
			"desc": "部署时放置毒液陷阱",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 90, "hp": 337, "cost": 120,
			"desc": "部署时放置毒液陷阱",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
