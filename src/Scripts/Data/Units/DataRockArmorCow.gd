class_name DataRockArmorCow

const DATA: Dictionary = {
	"name": "岩甲牛", "icon": "🪨",
	"range": 80, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "rock_armor_cow", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 40, "hp": 500, "cost": 55,
			"desc": "岩盾再生: 脱战5秒后生成最大生命值10%的护盾",
			"mechanics": {"out_of_combat_time": 5.0, "shield_percent": 0.1}
		},
		"2": {
			"damage": 60, "hp": 750, "cost": 110,
			"desc": "岩盾再生: 脱战4秒后生成最大生命值15%的护盾",
			"mechanics": {"out_of_combat_time": 4.0, "shield_percent": 0.15}
		},
		"3": {
			"damage": 90, "hp": 1125, "cost": 220,
			"desc": "岩盾再生: 脱战3秒后生成最大生命值20%的护盾",
			"mechanics": {"out_of_combat_time": 3.0, "shield_percent": 0.2}
		}
	}
}
