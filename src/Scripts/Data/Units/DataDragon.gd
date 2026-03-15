class_name DataDragon

const DATA: Dictionary = {
	"name": "龙", "icon": "🐉",
	"range": 300, "manaCost": 200,
	"attackType": "none",
	"skill": "black_hole", "skillType": "point",
	"targetArea": [3, 3], "skillCd": 20.0,
	"proj": "black_hole_field",
	"skillDuration": 8.0, "skillRadius": 150.0,
	"skillStrength": 3000.0, "skillColor": "#330066",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "dragon",
	"levels": {
		"1": {
			"hp": 250, "cost": 200,
			"desc": "主动：召唤黑洞控制敌人",
			"mechanics": {}
		},
		"2": {
			"hp": 375, "cost": 400,
			"desc": "主动：召唤黑洞控制敌人",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"hp": 562, "cost": 800,
			"desc": "主动：召唤黑洞控制敌人",
			"mechanics": {"crit_rate_bonus": 0.2, "multi_shot_chance": 0.3}
		}
	}
}
