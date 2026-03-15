class_name DataLifeChain

const DATA: Dictionary = {
	"name": "生命链接", "icon": "⛓️",
	"range": 200, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "ranged", "proj": "chain_link",
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "life_chain", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 40, "hp": 250, "cost": 65,
			"desc": "生命抽取: 链接2个最远敌人，每秒抽取10点生命，回复效率50%",
			"mechanics": {
				"chain_count": 2,
				"drain_per_second": 10,
				"heal_efficiency": 0.5
			}
		},
		"2": {
			"damage": 60, "hp": 375, "cost": 130,
			"desc": "生命抽取: 链接3个最远敌人，每秒抽取15点生命，回复效率60%",
			"mechanics": {
				"chain_count": 3,
				"drain_per_second": 15,
				"heal_efficiency": 0.6,
				"crit_rate_bonus": 0.1
			}
		},
		"3": {
			"damage": 90, "hp": 562, "cost": 260,
			"desc": "生命抽取: 链接4个最远敌人，每秒抽取20点生命，回复效率70%",
			"mechanics": {
				"chain_count": 4,
				"drain_per_second": 20,
				"heal_efficiency": 0.7,
				"crit_rate_bonus": 0.2
			}
		}
	}
}
