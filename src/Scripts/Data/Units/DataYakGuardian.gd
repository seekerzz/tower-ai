class_name DataYakGuardian

const DATA: Dictionary = {
	"name": "牦牛守护", "icon": "🦬",
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "yak_guardian", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 500, "cost": 60,
			"desc": "守护领域: 周围1格友方受到伤害减少5%",
			"mechanics": {"guardian_range": 1, "damage_reduction": 0.05}
		},
		"2": {
			"damage": 0, "hp": 750, "cost": 120,
			"desc": "守护领域: 周围1格友方受到伤害减少10%",
			"mechanics": {"guardian_range": 1, "damage_reduction": 0.1}
		},
		"3": {
			"damage": 0, "hp": 1125, "cost": 240,
			"desc": "守护领域: 周围1格友方受到伤害减少15%",
			"mechanics": {"guardian_range": 1, "damage_reduction": 0.15}
		}
	}
}
