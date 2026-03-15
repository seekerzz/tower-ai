class_name DataStormEagle

const DATA: Dictionary = {
	"name": "风暴鹰", "icon": "⚡",
	"range": 300, "atkSpeed": 1.5, "manaCost": 0,
	"attackType": "ranged", "proj": "lightning",
	"damageType": "lightning",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "storm_eagle", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 80, "hp": 200, "cost": 80,
			"desc": "雷暴召唤: 友方暴击时积累电荷，满5层召唤全场雷击",
			"mechanics": {"charges_needed": 5, "lightning_can_crit": false}
		},
		"2": {
			"damage": 120, "hp": 300, "cost": 160,
			"desc": "雷暴召唤: 友方暴击时积累电荷，满4层召唤全场雷击",
			"mechanics": {"charges_needed": 4, "lightning_can_crit": false}
		},
		"3": {
			"damage": 180, "hp": 450, "cost": 320,
			"desc": "雷暴召唤: 友方暴击时积累电荷，满3层召唤全场雷击，雷击可暴击",
			"mechanics": {"charges_needed": 3, "lightning_can_crit": true}
		}
	}
}
