class_name DataVampireBat

const DATA: Dictionary = {
	"name": "吸血蝠", "icon": "🦇",
	"range": 100, "atkSpeed": 0.8, "manaCost": 0,
	"attackType": "melee", "damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "vampire_bat", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 80, "hp": 200, "cost": 50,
			"desc": "鲜血狂噬: 生命值越低吸血越高，最低生命时+50%吸血",
			"mechanics": {"base_lifesteal": 0.0, "low_hp_bonus": 0.5}
		},
		"2": {
			"damage": 120, "hp": 300, "cost": 100,
			"desc": "鲜血狂噬: 基础吸血+20%，生命值越低吸血越高",
			"mechanics": {"base_lifesteal": 0.2, "low_hp_bonus": 0.5}
		},
		"3": {
			"damage": 180, "hp": 450, "cost": 200,
			"desc": "鲜血狂噬: 基础吸血+40%，生命值越低吸血越高",
			"mechanics": {"base_lifesteal": 0.4, "low_hp_bonus": 0.5, "crit_rate_bonus": 0.1}
		}
	}
}
