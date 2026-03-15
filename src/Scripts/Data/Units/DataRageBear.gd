class_name DataRageBear

const DATA: Dictionary = {
	"name": "暴怒熊", "icon": "🐻",
	"size": [1, 1],
	"range": 80, "atkSpeed": 1.2, "manaCost": 300,
	"attackType": "melee",
	"skill": "ground_slam", "skillCd": 15,
	"damageType": "physical",
	"crit_rate": 0.1, "crit_dmg": 1.5,
	"type_key": "rage_bear", "faction": "universal",
	"levels": {
		"1": {
			"damage": 80, "hp": 400, "cost": 65,
			"desc": "近战:15%概率眩晕1秒，对眩晕敌人+50%伤害。技能:地面猛击眩晕范围敌人",
			"mechanics": {"stun_chance": 0.15, "stun_duration": 1.0, "bonus_vs_stunned": 0.5, "skill_stun_duration": 1.5}
		},
		"2": {
			"damage": 120, "hp": 600, "cost": 130,
			"desc": "近战:22%概率眩晕1.2秒，对眩晕敌人+75%伤害",
			"mechanics": {"stun_chance": 0.22, "stun_duration": 1.2, "bonus_vs_stunned": 0.75, "skill_stun_duration": 2.0}
		},
		"3": {
			"damage": 180, "hp": 900, "cost": 260,
			"desc": "近战:30%概率眩晕1.5秒，对眩晕敌人+100%伤害。击杀眩晕敌人重置技能CD",
			"mechanics": {"stun_chance": 0.30, "stun_duration": 1.5, "bonus_vs_stunned": 1.0, "skill_stun_duration": 2.5, "kill_reset_cd": true}
		}
	}
}
