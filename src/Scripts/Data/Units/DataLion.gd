class_name DataLion

const DATA: Dictionary = {
	"name": "狮子", "icon": "🦁",
	"size": [1, 1],
	"range": 200, "atkSpeed": 2.0, "manaCost": 0,
	"attackType": "shockwave", "damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "lion", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 150, "hp": 200, "cost": 90,
			"desc": "声波:狮吼对范围内所有敌人造成伤害",
			"mechanics": {"shockwave_radius": 150}
		},
		"2": {
			"damage": 225, "hp": 300, "cost": 180,
			"desc": "声波:范围扩大，20%概率击退",
			"mechanics": {"shockwave_radius": 180, "knockback_chance": 0.20}
		},
		"3": {
			"damage": 337, "hp": 450, "cost": 360,
			"desc": "声波:范围200，每3次攻击产生延迟冲击波",
			"mechanics": {"shockwave_radius": 200, "knockback_chance": 0.30, "secondary_shockwave": true}
		}
	}
}
