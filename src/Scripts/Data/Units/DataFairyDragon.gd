class_name DataFairyDragon

const DATA: Dictionary = {
	"name": "精灵龙", "icon": "🧚🐉",
	"range": 250, "atkSpeed": 1.2,
	"attackType": "ranged", "proj": "magic_missile",
	"desc": "攻击命中时有概率将敌人传送至2-3格外的直线距离。概率受敌人抗性影响。",
	"type_key": "fairy_dragon", "faction": "butterfly_totem",
	"levels": {
		"1": {
			"damage": 35, "cost": 60,
			"mechanics": {"teleport_base_chance": 0.5}
		},
		"2": {
			"damage": 55, "cost": 120,
			"mechanics": {"teleport_base_chance": 0.7, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 85, "cost": 240,
			"mechanics": {"teleport_base_chance": 0.9, "crit_rate_bonus": 0.2}
		}
	}
}
