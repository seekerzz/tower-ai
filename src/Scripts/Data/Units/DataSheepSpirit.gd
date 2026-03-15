class_name DataSheepSpirit

const DATA: Dictionary = {
	"name": "羊灵", "icon": "🐑",
	"range": 150, "atkSpeed": 0.8, "manaCost": 0,
	"attackType": "ranged", "proj": "spirit_orb",
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "sheep_spirit", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 50, "hp": 200, "cost": 60,
			"desc": "灵魂召唤: 敌人死亡时召唤1个克隆体，继承40%属性",
			"mechanics": {"clone_count": 1, "inherit_ratio": 0.4}
		},
		"2": {
			"damage": 75, "hp": 300, "cost": 120,
			"desc": "灵魂召唤: 敌人死亡时召唤1个克隆体，继承40%属性",
			"mechanics": {"clone_count": 1, "inherit_ratio": 0.4, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 112, "hp": 450, "cost": 240,
			"desc": "灵魂召唤: 敌人死亡时召唤2个克隆体，继承60%属性",
			"mechanics": {"clone_count": 2, "inherit_ratio": 0.6, "crit_rate_bonus": 0.2}
		}
	}
}
