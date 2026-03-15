class_name DataPlagueSpreader

const DATA: Dictionary = {
	"name": "瘟疫使者", "icon": "🦇",
	"range": 250, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "ranged", "proj": "stinger",
	"damageType": "poison",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "plague_spreader", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 40, "hp": 150, "cost": 60,
			"desc": "毒血传播: 攻击使敌人中毒，中毒敌人死亡时传播给附近敌人",
			"mechanics": {"spread_range": 0.0}
		},
		"2": {
			"damage": 60, "hp": 225, "cost": 120,
			"desc": "毒血传播: 传播范围+1格",
			"mechanics": {"spread_range": 60.0, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 90, "hp": 337, "cost": 240,
			"desc": "毒血传播: 传播范围+2格",
			"mechanics": {"spread_range": 120.0, "crit_rate_bonus": 0.2}
		}
	}
}
