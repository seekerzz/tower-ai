class_name DataBear

const DATA: Dictionary = {
	"name": "暴怒熊", "icon": "🐻",
	"size": [1, 1],
	"range": 80, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "melee",
	"skill": "stun", "skillCd": 15,
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "bear",
	"levels": {
		"1": {
			"damage": 350, "hp": 400, "cost": 65,
			"desc": "近战:重击晕眩\n技能:震慑(300💧)",
			"mechanics": {}
		},
		"2": {
			"damage": 525, "hp": 600, "cost": 130,
			"desc": "近战:重击晕眩\n技能:震慑(300💧)",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 787, "hp": 900, "cost": 260,
			"desc": "近战:重击晕眩\n技能:震慑(300💧)",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
