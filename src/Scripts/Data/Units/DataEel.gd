class_name DataEel

const DATA: Dictionary = {
	"name": "电鳗", "icon": "⚡",
	"range": 200, "atkSpeed": 1.2, "manaCost": 50,
	"attackType": "ranged", "proj": "lightning",
	"chain": 4, "damageType": "lightning",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "eel",
	"levels": {
		"1": {
			"damage": 350, "hp": 200, "cost": 70,
			"desc": "连锁: 释放电流攻击多个敌人",
			"mechanics": {}
		},
		"2": {
			"damage": 525, "hp": 300, "cost": 140,
			"desc": "连锁: 释放电流攻击多个敌人",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 787, "hp": 450, "cost": 280,
			"desc": "连锁: 释放电流攻击多个敌人",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
