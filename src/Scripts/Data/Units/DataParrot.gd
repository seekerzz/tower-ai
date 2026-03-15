class_name DataParrot

const DATA: Dictionary = {
	"name": "鹦鹉", "icon": "🦜",
	"range": 0, "atkSpeed": 0.08, "manaCost": 0,
	"attackType": "mimic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "parrot", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 0,
			"desc": "学习邻居子弹\n上限:5发",
			"mechanics": {"max_ammo": 5}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 0,
			"desc": "学习邻居子弹\n上限:7发",
			"mechanics": {"max_ammo": 7}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 0,
			"desc": "学习邻居子弹\n上限:10发",
			"mechanics": {"max_ammo": 10}
		}
	}
}
