class_name DataLuckyCat

const DATA: Dictionary = {
	"name": "招财猫", "icon": "🐱",
	"size": [1, 1],
	"range": 0, "atkSpeed": 1.0,
	"attackType": "none",
	"has_interaction": true, "interaction_pattern": "neighbor_pair",
	"buff_id": "wealth",
	"type_key": "lucky_cat", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 100,
			"desc": "邻接:击杀获金",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 200,
			"desc": "邻接:击杀获金",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 400,
			"desc": "邻接:击杀获金",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
