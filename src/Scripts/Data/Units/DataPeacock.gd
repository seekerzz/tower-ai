class_name DataPeacock

const DATA: Dictionary = {
	"name": "孔雀", "icon": "🦚",
	"size": [1, 1],
	"range": 300, "atkSpeed": 1.2,
	"attackType": "ranged", "proj": "feather",
	"max_quills": 3,
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "peacock", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 60, "hp": 200, "cost": 40,
			"desc": "远程: 发射羽毛, 第4次收回拉扯敌人",
			"mechanics": {}
		},
		"2": {
			"damage": 90, "hp": 300, "cost": 80,
			"desc": "远程: 发射羽毛, 第4次收回拉扯敌人",
			"mechanics": {"pull_strength": 600, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 135, "hp": 450, "cost": 160,
			"desc": "远程: 发射羽毛, 第4次收回拉扯敌人",
			"mechanics": {"pull_strength": 1000, "multi_shot_chance": 0.2, "crit_rate_bonus": 0.2}
		}
	}
}
