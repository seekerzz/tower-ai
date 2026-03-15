class_name DataBloodMeat

const DATA: Dictionary = {
	"name": "五花肉", "icon": "🥩",
	"range": 0, "atkSpeed": 0, "manaCost": 50,
	"attackType": "none",
	"skill": "sacrifice", "skillCd": 20,
	"crit_rate": 0.0, "crit_dmg": 1.5,
	"type_key": "blood_meat", "faction": "wolf_totem",
	"levels": {
		"1": {
			"damage": 0, "hp": 150, "cost": 50,
			"desc": "邻接狼族+10%攻击。技能:牺牲自己治疗核心5%，所有狼族+25%攻击5秒",
			"mechanics": {"adjacent_wolf_buff": 0.10, "sacrifice_heal": 0.05, "sacrifice_buff": 0.25, "sacrifice_duration": 5.0}
		},
		"2": {
			"damage": 0, "hp": 225, "cost": 100,
			"desc": "邻接狼族+15%攻击。技能:牺牲治疗核心8%，所有狼族+30%攻击6秒",
			"mechanics": {"adjacent_wolf_buff": 0.15, "sacrifice_heal": 0.08, "sacrifice_buff": 0.30, "sacrifice_duration": 6.0}
		},
		"3": {
			"damage": 0, "hp": 337, "cost": 200,
			"desc": "邻接狼族+20%攻击，吞噬叠加层数。技能:牺牲治疗核心10%，所有狼族+40%攻击8秒",
			"mechanics": {"adjacent_wolf_buff": 0.20, "sacrifice_heal": 0.10, "sacrifice_buff": 0.40, "sacrifice_duration": 8.0, "blood_stacks": true}
		}
	}
}
