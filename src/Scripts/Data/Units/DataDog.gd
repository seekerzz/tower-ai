class_name DataDog

const DATA: Dictionary = {
	"name": "恶霸犬", "icon": "🐕",
	"range": 100, "atkSpeed": 0.8, "manaCost": 0,
	"attackType": "melee", "splash": 60,
	"skill": "rage", "skillCd": 10, "skillDuration": 5.0,
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "dog", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 200, "hp": 300, "cost": 30,
			"desc": "近战: 凶猛撕咬 (范围伤害)",
			"mechanics": {}
		},
		"2": {
			"damage": 300, "hp": 450, "cost": 60,
			"desc": "近战: 凶猛撕咬 (范围伤害)",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 450, "hp": 675, "cost": 120,
			"desc": "近战: 凶猛撕咬 (范围伤害)",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
