class_name DataKestrel

const DATA: Dictionary = {
	"name": "红隼", "icon": "🐦",
	"size": [1, 1],
	"range": 250, "atkSpeed": 1.0,
	"attackType": "ranged", "damageType": "physical",
	"type_key": "kestrel", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 40, "hp": 150, "cost": 120,
			"desc": "攻击概率眩晕敌人"
		},
		"2": {
			"damage": 60, "hp": 225, "cost": 240,
			"desc": "眩晕概率和时间增加"
		},
		"3": {
			"damage": 90, "hp": 337, "cost": 480,
			"desc": "眩晕时触发音爆伤害"
		}
	}
}
