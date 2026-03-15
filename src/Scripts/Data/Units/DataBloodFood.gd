class_name DataBloodFood

const DATA: Dictionary = {
	"name": "血食", "icon": "🩸",
	"range": 0, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none", "damageType": "physical",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "blood_food", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 300, "cost": 50,
			"desc": "魂魄共鸣: 每魂魄提供+0.5%全局伤害加成",
			"mechanics": {"damage_per_soul": 0.005}
		},
		"2": {
			"damage": 0, "hp": 450, "cost": 100,
			"desc": "魂魄共鸣: 每魂魄提供+0.5%全局伤害加成",
			"mechanics": {"damage_per_soul": 0.005, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 675, "cost": 200,
			"desc": "魂魄共鸣: 每魂魄提供+0.8%全局伤害加成",
			"mechanics": {"damage_per_soul": 0.008, "crit_rate_bonus": 0.2}
		}
	}
}
