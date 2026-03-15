class_name DataSplitter

const DATA: Dictionary = {
	"name": "多重棱镜", "icon": "💠",
	"size": [1, 1],
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none", "buffProvider": "split",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "splitter", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 55,
			"desc": "邻接:子弹分裂+1",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 110,
			"desc": "邻接:子弹分裂+1",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 220,
			"desc": "邻接:子弹分裂+1",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
