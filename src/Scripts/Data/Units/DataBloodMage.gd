class_name DataBloodMage

const DATA: Dictionary = {
	"name": "血法师", "icon": "🩸",
	"size": [1, 1],
	"range": 300, "atkSpeed": 1.0, "manaCost": 100,
	"attackType": "ranged", "proj": "magic_missile",
	"skill": "blood_pool", "skillType": "point",
	"targetArea": [3, 3], "skillCd": 15.0,
	"damageType": "magic",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "blood_mage", "faction": "bat_totem",
	"levels": {
		"1": {
			"damage": 50, "hp": 180, "cost": 80,
			"desc": "血池降临: 召唤1x1血池，敌人受伤友方回血",
			"mechanics": {"pool_size": 1, "heal_efficiency": 1.0}
		},
		"2": {
			"damage": 75, "hp": 270, "cost": 160,
			"desc": "血池降临: 召唤2x2血池",
			"mechanics": {"pool_size": 2, "heal_efficiency": 1.0, "crit_rate_bonus": 0.1}
		},
		"3": {
			"damage": 112, "hp": 405, "cost": 320,
			"desc": "血池降临: 召唤3x3血池，效果+50%",
			"mechanics": {"pool_size": 3, "heal_efficiency": 1.5, "crit_rate_bonus": 0.2}
		}
	}
}
