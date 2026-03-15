class_name DataEagle

const DATA: Dictionary = {
	"name": "老鹰", "icon": "🦅",
	"size": [1, 1],
	"range": 400, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.2, "crit_dmg": 1.5,
	"type_key": "eagle", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 100, "hp": 250, "cost": 70,
			"desc": "极速突进: 优先攻击最远敌人。满血敌人受到双倍伤害。",
			"mechanics": {}
		},
		"2": {
			"damage": 150, "hp": 375, "cost": 140,
			"desc": "极速突进: 优先攻击最远敌人。满血敌人受到双倍伤害。",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 225, "hp": 562, "cost": 280,
			"desc": "极速突进: 优先攻击最远敌人。满血敌人受到双倍伤害。",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
