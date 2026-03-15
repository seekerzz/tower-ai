class_name DataOwl

const DATA: Dictionary = {
	"name": "猫头鹰", "icon": "🦉",
	"size": [1, 1],
	"range": 0, "atkSpeed": 1.0,
	"attackType": "none", "buffProvider": "crit",
	"type_key": "owl", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 120, "cost": 100,
			"desc": "邻接友军暴击率+12%"
		},
		"2": {
			"damage": 0, "hp": 180, "cost": 200,
			"desc": "周围2格友军暴击率+20%"
		},
		"3": {
			"damage": 0, "hp": 270, "cost": 400,
			"desc": "友军触发回响时增加攻速"
		}
	}
}
