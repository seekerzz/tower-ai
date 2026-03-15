class_name DataGaleEagle

const DATA: Dictionary = {
	"name": "疾风鹰", "icon": "💨",
	"range": 250, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "ranged", "proj": "feather",
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "gale_eagle", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 50, "hp": 180, "cost": 70,
			"desc": "风刃连击: 每次攻击发射2道风刃，每道60%伤害",
			"mechanics": {"wind_blade_count": 2, "damage_per_blade": 0.6}
		},
		"2": {
			"damage": 75, "hp": 270, "cost": 140,
			"desc": "风刃连击: 每次攻击发射3道风刃，每道70%伤害",
			"mechanics": {"wind_blade_count": 3, "damage_per_blade": 0.7}
		},
		"3": {
			"damage": 112, "hp": 405, "cost": 280,
			"desc": "风刃连击: 每次攻击发射4道风刃，每道80%伤害",
			"mechanics": {"wind_blade_count": 4, "damage_per_blade": 0.8}
		}
	}
}
