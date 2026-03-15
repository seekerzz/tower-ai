class_name DataMushroomHealer

const DATA: Dictionary = {
	"name": "菌菇治愈者", "icon": "🍄",
	"range": 0, "atkSpeed": 1.0, "manaCost": 0,
	"attackType": "none",
	"skill": "burst_heal", "skillCd": 15,
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "mushroom_healer", "faction": "cow_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 250, "cost": 50,
			"desc": "过量转化:核心治疗溢出80%转为延迟回血",
			"mechanics": {"conversion_rate": 0.8, "delay_seconds": 3.0}
		},
		"2": {
			"damage": 0, "hp": 375, "cost": 100,
			"desc": "过量转化:核心治疗溢出100%转为延迟回血",
			"mechanics": {"conversion_rate": 1.0, "delay_seconds": 3.0}
		},
		"3": {
			"damage": 0, "hp": 562, "cost": 200,
			"desc": "过量转化:核心治疗溢出100%转为延迟回血，转化量+50%",
			"mechanics": {"conversion_rate": 1.0, "delay_seconds": 3.0, "enhancement": 1.5}
		}
	}
}
