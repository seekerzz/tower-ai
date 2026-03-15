class_name DataIceButterfly

const DATA: Dictionary = {
	"name": "冰晶蝶", "icon": "🦋",
	"size": [1, 1],
	"range": 250, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "ranged", "proj": "ice_shard",
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "ice_butterfly", "faction": "butterfly_totem",
	"levels": {
		"1": {
			"damage": 35, "hp": 120, "cost": 60,
			"desc": "极寒：攻击给敌人叠加冰冻debuff，叠满3层冻结1秒",
			"mechanics": {}
		},
		"2": {
			"damage": 52, "hp": 180, "cost": 120,
			"desc": "极寒：冻结时间延长至2秒",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 78, "hp": 270, "cost": 240,
			"desc": "极寒增幅：法球命中冻结敌人时伤害翻倍",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
