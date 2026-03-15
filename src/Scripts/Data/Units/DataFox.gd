class_name DataFox

const DATA: Dictionary = {
	"name": "灵狐", "icon": "🦊",
	"range": 200, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "ranged", "proj": "spirit_orb",
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "fox", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 50, "hp": 200, "cost": 60,
			"desc": "魅惑：被攻击时20%概率魅惑敌人",
			"mechanics": {}
		},
		"2": {
			"damage": 75, "hp": 300, "cost": 120,
			"desc": "魅惑：被攻击时30%概率魅惑敌人",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 112, "hp": 450, "cost": 240,
			"desc": "魅惑：可同时魅惑2个敌人",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
