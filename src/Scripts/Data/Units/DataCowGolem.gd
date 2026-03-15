class_name DataCowGolem

const DATA: Dictionary = {
	"name": "牛魔像", "icon": "🗿",
	"size": [1, 1],
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "cow_golem", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 800, "cost": 80,
			"desc": "震荡反击: 每受到15次攻击触发全屏震荡，晕眩1秒",
			"mechanics": {"hits_threshold": 15, "stun_duration": 1.0}
		},
		"2": {
			"damage": 0, "hp": 1200, "cost": 160,
			"desc": "震荡反击: 每受到12次攻击触发全屏震荡，晕眩1秒",
			"mechanics": {"hits_threshold": 12, "stun_duration": 1.0}
		},
		"3": {
			"damage": 0, "hp": 1800, "cost": 320,
			"desc": "震荡反击: 每受到10次攻击触发全屏震荡，晕眩1.5秒",
			"mechanics": {"hits_threshold": 10, "stun_duration": 1.5}
		}
	}
}
