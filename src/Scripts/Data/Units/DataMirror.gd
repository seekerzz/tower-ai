class_name DataMirror

const DATA: Dictionary = {
	"name": "反射魔镜", "icon": "🪞",
	"size": [1, 1],
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none", "buffProvider": "bounce",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "mirror", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 50,
			"desc": "邻接:子弹弹射+1",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 100,
			"desc": "邻接:子弹弹射+1",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 200,
			"desc": "邻接:子弹弹射+1",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
