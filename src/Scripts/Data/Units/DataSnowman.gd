class_name DataSnowman

const DATA: Dictionary = {
	"name": "雪人", "icon": "☃️",
	"size": [1, 1],
	"range": 0, "atkSpeed": 1.0, "manaCost": 20,
	"attackType": "none",
	"production_type": "item", "produce_item_id": "snowball_trap",
	"production_interval": 5.0,
	"trait": "freeze", "damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "snowman", "faction": "universal",
	"levels": {
		"1": {
			"damage": 40, "hp": 200, "cost": 60,
			"desc": "每5秒生成雪球陷阱",
			"mechanics": {}
		},
		"2": {
			"damage": 60, "hp": 300, "cost": 120,
			"desc": "每4秒生成雪球陷阱",
			"mechanics": {"crit_rate_bonus": 0.1, "production_interval": 4.0}
		},
		"3": {
			"damage": 90, "hp": 450, "cost": 240,
			"desc": "每3秒生成雪球陷阱",
			"mechanics": {"crit_rate_bonus": 0.2, "production_interval": 3.0}
		}
	}
}
