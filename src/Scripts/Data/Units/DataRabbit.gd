class_name DataRabbit

const DATA: Dictionary = {
	"name": "兔子", "icon": "🐇",
	"size": [1, 1],
	"range": 80, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "none",
	"has_interaction": true, "buff_id": "bounce",
	"damageType": "physical",
	"crit_rate": 0.2, "crit_dmg": 1.5,
	"type_key": "rabbit", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 150, "cost": 35,
			"desc": "邻接：使单位子弹获得物理弹射+1。多个兔子可叠加。",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 225, "cost": 70,
			"desc": "邻接：使单位子弹获得物理弹射+1。多个兔子可叠加。",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 337, "cost": 140,
			"desc": "邻接：使单位子弹获得物理弹射+1。多个兔子可叠加。",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
