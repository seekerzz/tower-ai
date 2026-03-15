class_name DataHyena

const DATA: Dictionary = {
	"name": "豺狼", "icon": "🐕",
	"range": 100, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "hyena", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 120, "hp": 350, "cost": 80,
			"desc": "撕咬: 攻击HP<25%敌人时触发1次额外攻击，造成20%伤害",
			"mechanics": {"execute_threshold": 0.25, "extra_attacks": 1, "execute_damage_ratio": 0.2}
		},
		"2": {
			"damage": 180, "hp": 525, "cost": 160,
			"desc": "撕咬: 攻击HP<25%敌人时触发1次额外攻击，造成40%伤害",
			"mechanics": {"execute_threshold": 0.25, "extra_attacks": 1, "execute_damage_ratio": 0.4, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 270, "hp": 787, "cost": 320,
			"desc": "撕咬: 攻击HP<25%敌人时触发2次额外攻击，每次造成40%伤害",
			"mechanics": {"execute_threshold": 0.25, "extra_attacks": 2, "execute_damage_ratio": 0.4, "crit_rate_bonus": 0.2}
		}
	}
}
