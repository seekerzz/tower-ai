class_name DataPigeon

const DATA: Dictionary = {
	"name": "鸽子", "icon": "🕊️",
	"size": [1, 1],
	"range": 200, "atkSpeed": 1.0,
	"attackType": "ranged", "damageType": "physical",
	"type_key": "pigeon", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 30, "hp": 100, "cost": 80,
			"desc": "有几率闪避敌人攻击"
		},
		"2": {
			"damage": 45, "hp": 150, "cost": 160,
			"desc": "闪避后短暂无敌"
		},
		"3": {
			"damage": 67, "hp": 225, "cost": 320,
			"desc": "闪避时反击并增加友军暴击"
		}
	}
}
