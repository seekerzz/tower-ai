class_name DataArrowFrog

const DATA: Dictionary = {
	"name": "箭毒蛙", "icon": "🐸",
	"size": [1, 1],
	"range": 80, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee", "damageType": "poison",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "arrow_frog", "faction": "viper_totem",
	"levels": {
		"1": {
			"damage": 150, "hp": 300, "cost": 80,
			"desc": "攻击附带中毒。若敌人生命值低于[Debuff层数*3]，则直接斩杀。",
			"mechanics": {}
		},
		"2": {
			"damage": 225, "hp": 450, "cost": 160,
			"desc": "攻击附带中毒。若敌人生命值低于[Debuff层数*3]，则直接斩杀。",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 337, "hp": 675, "cost": 320,
			"desc": "攻击附带中毒。若敌人生命值低于[Debuff层数*3]，则直接斩杀。",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
