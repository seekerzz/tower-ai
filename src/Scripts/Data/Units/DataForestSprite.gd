class_name DataForestSprite

const DATA: Dictionary = {
	"name": "森林精灵", "icon": "🧚",
	"range": 150, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none", "buffProvider": "forest_blessing",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "forest_sprite", "faction": "butterfly_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 150, "cost": 70,
			"desc": "森林祝福：单位攻击5%概率给被攻击敌人增加随机一层Debuff",
			"mechanics": {}
		},
		"2": {
			"damage": 0, "hp": 225, "cost": 140,
			"desc": "森林祝福：单位攻击10%概率附加随机Debuff",
			"mechanics": {"crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 0, "hp": 337, "cost": 280,
			"desc": "森林祝福：额外10%概率使得Debuff层数+20%",
			"mechanics": {"crit_rate_bonus": 0.2}
		}
	}
}
