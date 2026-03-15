class_name DataLureSnake

const DATA: Dictionary = {
	"name": "诱捕蛇", "icon": "🐍",
	"range": 0, "atkSpeed": 0, "manaCost": 0,
	"attackType": "none",
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "lure_snake", "faction": "viper_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 150, "cost": 50,
			"desc": "陷阱诱导: 敌人触发陷阱后，被牵引向最近的另一个陷阱",
			"mechanics": {"pull_speed_multiplier": 1.0}
		},
		"2": {
			"damage": 0, "hp": 225, "cost": 100,
			"desc": "陷阱诱导: 敌人触发陷阱后，被牵引向最近的另一个陷阱，牵引速度+50%",
			"mechanics": {"pull_speed_multiplier": 1.5}
		},
		"3": {
			"damage": 0, "hp": 337, "cost": 200,
			"desc": "陷阱诱导: 敌人触发陷阱后，被牵引向最近的另一个陷阱，牵引后晕眩1秒",
			"mechanics": {"pull_speed_multiplier": 1.5, "stun_duration": 1.0}
		}
	}
}
