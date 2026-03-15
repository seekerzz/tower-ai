class_name DataBloodAncestor

const DATA: Dictionary = {
	"name": "血祖", "icon": "👑",
	"range": 280, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "ranged", "proj": "magic_missile",
	"damageType": "magic",
	"crit_rate": 0.15, "crit_dmg": 1.5,
	"type_key": "blood_ancestor", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 60, "hp": 250, "cost": 100,
			"desc": "鲜血领域: 场上每有1个受伤敌人，自身攻击+10%",
			"mechanics": {"damage_per_injured_enemy": 0.1, "lifesteal_bonus": 0.0}
		},
		"2": {
			"damage": 90, "hp": 375, "cost": 200,
			"desc": "鲜血领域: 场上每有1个受伤敌人，自身攻击+15%",
			"mechanics": {"damage_per_injured_enemy": 0.15, "lifesteal_bonus": 0.0, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 135, "hp": 562, "cost": 400,
			"desc": "鲜血领域: 场上每有1个受伤敌人，自身攻击+20%且吸血+20%",
			"mechanics": {"damage_per_injured_enemy": 0.2, "lifesteal_bonus": 0.2, "crit_rate_bonus": 0.2}
		}
	}
}
