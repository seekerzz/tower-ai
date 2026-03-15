class_name DataWoodpecker

const DATA: Dictionary = {
	"name": "啄木鸟", "icon": "🐦",
	"size": [1, 1],
	"range": 250, "atkSpeed": 0.5,
	"attackType": "ranged", "proj": "stinger",
	"damageType": "physical",
	"type_key": "woodpecker", "faction": "eagle_totem",
	"levels": {
		"1": {
			"damage": 8, "hp": 80, "cost": 40,
			"desc": "被动：对同一目标的连续攻击伤害逐渐增加 (每次+10%)",
			"mechanics": {"stack_bonus": 0.1}
		},
		"2": {
			"damage": 12, "hp": 120, "cost": 80,
			"desc": "被动：对同一目标的连续攻击伤害逐渐增加 (每次+10%)",
			"mechanics": {"stack_bonus": 0.1, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 18, "hp": 180, "cost": 160,
			"desc": "被动：对同一目标的连续攻击伤害逐渐增加 (每次+10%)",
			"mechanics": {"stack_bonus": 0.1, "crit_rate_bonus": 0.2}
		}
	}
}
