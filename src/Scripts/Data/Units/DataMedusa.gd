class_name DataMedusa

const DATA: Dictionary = {
	"name": "美杜莎", "icon": "👑",
	"size": [1, 1],
	"range": 300, "atkSpeed": 1.5, "manaCost": 0,
	"attackType": "ranged", "proj": "magic_missile",
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "medusa", "faction": "viper_totem",
	"levels": {
		"1": {
			"damage": 40, "hp": 200, "cost": 70,
			"desc": "石化凝视: 每3秒石化最近的敌人3秒",
			"mechanics": {"petrify_duration": 3.0}
		},
		"2": {
			"damage": 60, "hp": 300, "cost": 140,
			"desc": "石化凝视: 每3秒石化最近的敌人5秒，结束造成范围伤害",
			"mechanics": {"petrify_duration": 5.0}
		},
		"3": {
			"damage": 90, "hp": 450, "cost": 280,
			"desc": "石化凝视: 每3秒石化最近的敌人8秒，结束造成高额范围伤害",
			"mechanics": {"petrify_duration": 8.0}
		}
	}
}
