class_name DataMagpie

const DATA: Dictionary = {
	"name": "喜鹊", "icon": "🐧",
	"range": 200, "atkSpeed": 1.2,
	"attackType": "ranged", "damageType": "physical",
	"type_key": "magpie", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 35, "hp": 120, "cost": 100,
			"desc": "攻击概率偷取敌人属性"
		},
		"2": {
			"damage": 50, "hp": 180, "cost": 200,
			"desc": "偷取属性效果提升"
		},
		"3": {
			"damage": 75, "hp": 270, "cost": 400,
			"desc": "偷取成功回复核心HP或金币"
		}
	}
}
