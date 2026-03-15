class_name DataFirefly

const DATA: Dictionary = {
	"name": "萤火虫", "icon": "✨",
	"range": 200, "atkSpeed": 1.2, "manaCost": 0,
	"attackType": "ranged", "proj": "light",
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "firefly", "faction": "butterfly_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 100, "cost": 50,
			"desc": "闪光：攻击不造成伤害，给敌人一层致盲debuff（命中率-10%）",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 150, "cost": 100,
			"desc": "闪光：致盲持续时间+2秒",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 225, "cost": 200,
			"desc": "闪光回蓝：致盲敌人每次Miss回复10法力",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
