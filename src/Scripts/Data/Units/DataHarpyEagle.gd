class_name DataHarpyEagle

const DATA: Dictionary = {
	"name": "角雕", "icon": "🦅",
	"range": 120, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.15, "crit_dmg": 1.5,
	"type_key": "harpy_eagle", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 60, "hp": 250, "cost": 75,
			"desc": "三连爪击: 快速进行3次爪击，每次60%伤害",
			"mechanics": {"claw_count": 3, "damage_per_claw": 0.6, "third_claw_bleed": false}
		},
		"2": {
			"damage": 90, "hp": 375, "cost": 150,
			"desc": "三连爪击: 快速进行3次爪击，每次70%伤害",
			"mechanics": {"claw_count": 3, "damage_per_claw": 0.7, "third_claw_bleed": false}
		},
		"3": {
			"damage": 135, "hp": 562, "cost": 300,
			"desc": "三连爪击: 快速进行3次爪击，每次80%伤害，第三次附带流血",
			"mechanics": {"claw_count": 3, "damage_per_claw": 0.8, "third_claw_bleed": true}
		}
	}
}
