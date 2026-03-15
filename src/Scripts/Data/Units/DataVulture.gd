class_name DataVulture

const DATA: Dictionary = {
	"name": "秃鹫", "icon": "🦅",
	"size": [1, 1],
	"range": 100, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.05, "crit_dmg": 1.5,
	"type_key": "vulture", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 70, "hp": 300, "cost": 65,
			"desc": "腐食增益: 周围有敌人死亡时，自身攻击+5%持续5秒",
			"mechanics": {"damage_bonus_percent": 0.05, "lifesteal_percent": 0.0, "detection_range": 300}
		},
		"2": {
			"damage": 105, "hp": 450, "cost": 130,
			"desc": "腐食增益: 周围有敌人死亡时，自身攻击+10%持续5秒",
			"mechanics": {"damage_bonus_percent": 0.1, "lifesteal_percent": 0.0, "detection_range": 300}
		},
		"3": {
			"damage": 157, "hp": 675, "cost": 260,
			"desc": "腐食增益: 周围有敌人死亡时，自身攻击+10%持续5秒，且吸血+20%",
			"mechanics": {"damage_bonus_percent": 0.1, "lifesteal_percent": 0.2, "detection_range": 300}
		}
	}
}
