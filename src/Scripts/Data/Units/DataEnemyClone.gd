class_name DataEnemyClone

const DATA: Dictionary = {
	"name": "克隆体", "icon": "👥",
	"type": "summoned_clone",
	"inherit_stats": ["damage", "attack_speed", "range"],
	"lifetime": -1,
	"attackType": "melee", "damageType": "physical",
	"type_key": "enemy_clone", "faction": "universal",
	"levels": {
		"1": {
			"damage": 0, "hp": 0, "cost": 0,
			"desc": "Clone of a unit"
		}
	}
}
