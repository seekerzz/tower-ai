extends RefCounted

func get_test_config(case_id: String) -> Dictionary:
	match case_id:
		"test_soul_system":
			return {
				"id": "test_soul_system",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"units": [
					{"id": "squirrel", "x": 0, "y": 1}
				]
			}
		"test_cow_squirrel":
			return {
				"id": "test_cow_squirrel",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 2,
				"duration": 10.0,
				"units": [
					{"id": "squirrel", "x": 0, "y": 2}
				]
			}
		"test_butterfly_phoenix":
			return {
				"id": "test_butterfly_phoenix",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"units": [
					{"id": "phoenix", "x": 0, "y": 1}
				],
				"scheduled_actions": [
					{
						"time": 5.0,
						"type": "skill",
						"source": "phoenix",
						"target": {"x": -2, "y": -2}
					}
				]
			}
		"test_viper_strategy":
			return {
				"id": "test_viper_strategy",
				"core_type": "viper_totem",
				"initial_gold": 2000,
				"start_wave_index": 1,
				"end_condition": "wave_end_or_fail",
				"units": [
					{"id": "squirrel", "x": 0, "y": 1},
					{"id": "viper", "x": -1, "y": 0}
				],
				"setup_actions": [
					{
						"type": "spawn_trap",
						"trap_id": "poison_trap",
						"strategy": "random_valid"
					},
					{
						"type": "apply_buff",
						"buff_id": "poison",
						"target_unit_id": "squirrel"
					}
				]
			}
		"test_bleed_lifesteal":
			return {
				"id": "test_bleed_lifesteal",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 400,
				"max_core_health": 500,
				"units": [
					{"id": "mosquito", "x": 0, "y": 1}
				],
				"enemies": [
					{"type": "slime", "count": 3, "hp": 100, "debuffs": [{"type": "bleed", "stacks": 5}]}
				],
				"scheduled_actions": [
					{"time": 1.0, "type": "record_baseline", "metrics": ["core_health"]},
					{"time": 10.0, "type": "verify_change", "validation_type": "core_health_increased", "min_increase": 5.0}
				],
				"validations": [
					{"time": 10.0, "type": "core_health_increased", "min_increase": 5.0},
					{"time": 14.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "蚊子攻击流血敌人，核心血量应该增加",
					"verification": "核心血量从400增加至少5点，且有攻击事件记录"
				}
			}
		"test_bleed_lifesteal_v2":
			return {
				"id": "test_bleed_lifesteal_v2",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 30.0,
				"core_health": 400,
				"max_core_health": 500,
				"units": [
					{"id": "mosquito", "x": 0, "y": 1},
					{"id": "blood_mage", "x": -1, "y": 0},
					{"id": "gargoyle", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 2, "hp": 80, "debuffs": [{"type": "bleed", "stacks": 5}]}
				],
				"scheduled_actions": [
					{"time": 1.0, "type": "record_baseline", "metrics": ["core_health"]},
					{"time": 15.0, "type": "verify_change", "validation_type": "core_health_increased", "min_increase": 10.0}
				],
				"validations": [
					{"time": 15.0, "type": "core_health_increased", "min_increase": 10.0},
					{"time": 29.0, "type": "event_occurred", "event_type": "lifesteal", "min_count": 1}
				],
				"expected_behavior": {
					"description": "蝙蝠图腾单位攻击流血敌人，核心血量应该显著增加（吸血比例0.8）",
					"verification": "核心血量从400增加至少10点，且有吸血事件记录"
				}
			}
		"test_taunt_system":
			return {
				"id": "test_taunt_system",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [
					{"id": "yak_guardian", "x": 0, "y": 1}
				]
			}
		"test_summon_system":
			return {
				"id": "test_summon_system",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 30.0,
				"units": [],
				"scheduled_actions": [
					{
						"time": 1.0,
						"type": "summon_test",
						"summon_type": "spiderling",
						"position": {"x": 0, "y": 1}
					}
				]
			}
		"test_eagle_kestrel":
			return {
				"id": "test_eagle_kestrel",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [{"id": "kestrel", "x": 0, "y": 1}]
			}
		"test_eagle_owl":
			return {
				"id": "test_eagle_owl",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [
					{"id": "owl", "x": 0, "y": 1},
					{"id": "kestrel", "x": 0, "y": 0}
				]
			}
		"test_eagle_magpie":
			return {
				"id": "test_eagle_magpie",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [{"id": "magpie", "x": 0, "y": 1}]
			}
		"test_eagle_pigeon":
			return {
				"id": "test_eagle_pigeon",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [{"id": "pigeon", "x": 0, "y": 1}]
			}
		"test_shop_faction_refresh":
			return {
				"id": "test_shop_faction_refresh",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 5.0,
				"test_shop": true,
				"validate_shop_faction": "wolf_totem"
			}
		"test_enemy_death_no_duplicate":
			return {
				"id": "test_enemy_death_no_duplicate",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 5.0,
				"units": [
					{"id": "tiger", "x": 0, "y": 0}
				],
				"scheduled_actions": [
					{
						"time": 2.0,
						"type": "test_enemy_death"
					}
				],
				"description": "测试敌人死亡时不会重复调用die()函数，防止重复添加魂魄/金币"
			}
		# ========== 牛图腾流派单位测试 (9个单位) ==========
		# 1.1 牦牛守护 (yak_guardian) - 嘲讽机制
		"test_cow_totem_yak_guardian":
			return {
				"id": "test_cow_totem_yak_guardian",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [
					{"id": "squirrel", "x": 0, "y": -1},
					{"id": "yak_guardian", "x": 0, "y": 1, "level": 1}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 3, "spawn_delay": 1.0}
				],
				"expected_behavior": {
					"description": "敌人初始攻击松鼠，5秒后转为攻击牦牛守护",
					"verification": "检查敌人target切换",
					"taunt_interval": 5.0,
					"damage_reduction": 0.05
				}
			}
		"test_cow_totem_yak_guardian_lv2":
			return {
				"id": "test_cow_totem_yak_guardian_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 12.0,
				"units": [
					{"id": "squirrel", "x": 0, "y": -1},
					{"id": "yak_guardian", "x": 0, "y": 1, "level": 2}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 3, "spawn_delay": 1.0}
				],
				"expected_behavior": {
					"description": "Lv2嘲讽间隔缩短至4秒，减伤提升至10%",
					"verification": "检查嘲讽频率和减伤数值",
					"taunt_interval": 4.0,
					"damage_reduction": 0.10
				}
			}
		"test_cow_totem_yak_guardian_lv3":
			return {
				"id": "test_cow_totem_yak_guardian_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "yak_guardian", "x": 0, "y": 1, "level": 3}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 3, "spawn_delay": 2.0}
				],
				"scheduled_actions": [
					{
						"time": 5.0,
						"type": "damage_core",
						"amount": 50
					}
				],
				"expected_behavior": {
					"description": "牛图腾反击时，牦牛攻击范围内敌人受到牦牛血量15%的额外伤害",
					"verification": "检查反击时敌人受到的伤害数值",
					"counter_damage_percent": 0.15
				}
			}
		# 1.2 铁甲龟 (iron_turtle) - 固定减伤
		"test_cow_totem_iron_turtle":
			return {
				"id": "test_cow_totem_iron_turtle",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [
					{"id": "iron_turtle", "x": 0, "y": 1, "level": 1}
				],
				"enemies": [
					{"type": "basic_enemy", "attack_damage": 30, "count": 3}
				],
				"expected_behavior": {
					"description": "敌人攻击铁甲龟时，伤害减少20点",
					"verification": "核心血量减少量 = 原伤害 - 20",
					"damage_reduction": 20
				}
			}
		"test_cow_totem_iron_turtle_lv2":
			return {
				"id": "test_cow_totem_iron_turtle_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"units": [
					{"id": "iron_turtle", "x": 0, "y": 1, "level": 2}
				],
				"enemies": [
					{"type": "basic_enemy", "attack_damage": 50, "count": 3}
				],
				"expected_behavior": {
					"description": "Lv2减伤提升至35点",
					"verification": "检查减伤数值",
					"damage_reduction": 35
				}
			}
		"test_cow_totem_iron_turtle_lv3":
			return {
				"id": "test_cow_totem_iron_turtle_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 500,
				"max_core_health": 500,
				"units": [
					{"id": "iron_turtle", "x": 0, "y": 1, "level": 3}
				],
				"enemies": [
					{"type": "weak_enemy", "attack_damage": 10, "count": 5}
				],
				"expected_behavior": {
					"description": "当伤害被减为0或miss时，回复1%核心HP",
					"verification": "观察核心血量是否增加",
					"damage_reduction": 50,
					"heal_percent": 0.01
				}
			}
		# 1.3 刺猬 (hedgehog) - 反弹伤害
		"test_cow_totem_hedgehog":
			return {
				"id": "test_cow_totem_hedgehog",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 30.0,
				"units": [
					{"id": "hedgehog", "x": 0, "y": 1, "level": 1}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 10, "hp": 100}
				],
				"expected_behavior": {
					"description": "30%概率反弹敌人伤害",
					"verification": "统计多次攻击中反弹发生的次数，概率应在30%左右",
					"reflect_chance": 0.30,
					"reflect_damage": "equal_to_incoming"
				}
			}
		"test_cow_totem_hedgehog_lv2":
			return {
				"id": "test_cow_totem_hedgehog_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 30.0,
				"units": [
					{"id": "hedgehog", "x": 0, "y": 1, "level": 2}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 10, "hp": 100}
				],
				"expected_behavior": {
					"description": "Lv2反弹概率提升至50%",
					"verification": "检查反弹概率",
					"reflect_chance": 0.50
				}
			}
		"test_cow_totem_hedgehog_lv3":
			return {
				"id": "test_cow_totem_hedgehog_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "hedgehog", "x": 0, "y": 1, "level": 3}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 5, "positions": [{"x": 2, "y": 0}, {"x": -2, "y": 0}, {"x": 0, "y": 2}]},
					{"type": "attacker_enemy", "count": 1}
				],
				"expected_behavior": {
					"description": "反伤时向周围发射3枚尖刺",
					"verification": "检查周围敌人是否受到尖刺伤害",
					"reflect_chance": 0.50,
					"spike_count": 3
				}
			}
		# 1.4 牛魔像 (cow_golem) - 怒火叠加
		"test_cow_totem_cow_golem":
			return {
				"id": "test_cow_totem_cow_golem",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "cow_golem", "x": 0, "y": 1, "level": 1}
				],
				"enemies": [
					{"type": "fast_attacker", "attack_speed": 2.0, "count": 1}
				],
				"scheduled_actions": [
					{"time": 2.0, "type": "record_damage"},
					{"time": 10.0, "type": "record_damage"}
				],
				"expected_behavior": {
					"description": "每次受击攻击力+3%，上限30%(10层)",
					"verification": "对比不同时间点的攻击伤害",
					"rage_per_hit": 0.03,
					"max_rage": 0.30
				}
			}
		"test_cow_totem_cow_golem_lv2":
			return {
				"id": "test_cow_totem_cow_golem_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 25.0,
				"units": [
					{"id": "cow_golem", "x": 0, "y": 1, "level": 2}
				],
				"enemies": [
					{"type": "fast_attacker", "attack_speed": 2.0, "count": 1}
				],
				"expected_behavior": {
					"description": "Lv2攻击力上限提升至50%(约17层)",
					"verification": "检查叠加上限",
					"max_rage": 0.50
				}
			}
		"test_cow_totem_cow_golem_lv3":
			return {
				"id": "test_cow_totem_cow_golem_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 30.0,
				"units": [
					{"id": "cow_golem", "x": 0, "y": 1, "level": 3}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 3, "positions": [{"x": 1, "y": 1}, {"x": -1, "y": 1}]}
				],
				"expected_behavior": {
					"description": "受击时20%概率给敌人叠加瘟疫易伤Debuff",
					"verification": "检查敌人是否获得plague_debuff",
					"debuff_chance": 0.20,
					"debuff_type": "plague_vulnerability"
				}
			}
		# 1.5 岩甲牛 (rock_armor_cow) - 脱战护盾
		"test_cow_totem_rock_armor_cow":
			return {
				"id": "test_cow_totem_rock_armor_cow",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "rock_armor_cow", "x": 0, "y": 1, "level": 1}
				],
				"scheduled_actions": [
					{"time": 3.0, "type": "spawn_enemy", "enemy_type": "basic", "count": 2},
					{"time": 10.0, "type": "verify_shield", "expected_shield_percent": 0.1}
				],
				"expected_behavior": {
					"description": "脱战5秒后生成10%最大HP的护盾，攻击附加护盾值50%的伤害",
					"verification": "检查护盾值是否为最大血量的10%",
					"shield_percent": 0.10,
					"out_of_combat_time": 5.0,
					"bonus_damage_percent": 0.50
				}
			}
		"test_cow_totem_rock_armor_cow_lv2":
			return {
				"id": "test_cow_totem_rock_armor_cow_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 18.0,
				"units": [
					{"id": "rock_armor_cow", "x": 0, "y": 1, "level": 2}
				],
				"scheduled_actions": [
					{"time": 3.0, "type": "spawn_enemy", "enemy_type": "basic", "count": 2},
					{"time": 9.0, "type": "verify_shield", "expected_shield_percent": 0.15}
				],
				"expected_behavior": {
					"description": "Lv2护盾值提升至15%，脱战时间缩短至4秒",
					"verification": "检查护盾数值和脱战时间",
					"shield_percent": 0.15,
					"out_of_combat_time": 4.0
				}
			}
		"test_cow_totem_rock_armor_cow_lv3":
			return {
				"id": "test_cow_totem_rock_armor_cow_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 25.0,
				"core_health": 500,
				"max_core_health": 500,
				"units": [
					{"id": "rock_armor_cow", "x": 0, "y": 1, "level": 3},
					{"id": "mushroom_healer", "x": 1, "y": 0, "level": 3}
				],
				"expected_behavior": {
					"description": "核心满血时，溢出回血的10%转为护盾",
					"verification": "核心满血后，观察护盾是否继续增加",
					"overflow_conversion": 0.10
				}
			}
		# 1.6 菌菇治愈者 (mushroom_healer) - 孢子护盾
		"test_cow_totem_mushroom_healer":
			return {
				"id": "test_cow_totem_mushroom_healer",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "mushroom_healer", "x": 0, "y": 1, "level": 1},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 3}
				],
				"validations": [
					{"time": 18.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "为周围友方添加1层孢子Buff，抵消1次伤害并使敌人叠加3层中毒",
					"verification": "松鼠第一次受击时不掉血，敌人获得中毒Debuff",
					"spore_stacks": 1,
					"poison_stacks_on_trigger": 3
				}
			}
		"test_cow_totem_mushroom_healer_lv2":
			return {
				"id": "test_cow_totem_mushroom_healer_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "mushroom_healer", "x": 0, "y": 1, "level": 2},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 5}
				],
				"validations": [
					{"time": 18.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "Lv2孢子层数提升至3层",
					"verification": "检查孢子层数",
					"spore_stacks": 3
				}
			}
		"test_cow_totem_mushroom_healer_lv3":
			return {
				"id": "test_cow_totem_mushroom_healer_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"units": [
					{"id": "mushroom_healer", "x": 0, "y": 1, "level": 3},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "basic_enemy", "count": 5}
				],
				"validations": [
					{"time": 18.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "孢子耗尽时额外造成一次中毒伤害",
					"verification": "孢子层数归零时，敌人受到额外中毒伤害",
					"spore_stacks": 3,
					"bonus_damage_on_deplete": true
				}
			}
		# 1.7 奶牛 (cow) - 周期性治疗
		"test_cow_totem_cow":
			return {
				"id": "test_cow_totem_cow",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"core_health": 700,
				"max_core_health": 1000,
				"units": [
					{"id": "cow", "x": 0, "y": 1, "level": 1},
					{"id": "torch", "x": 1, "y": 0, "level": 1}
				],
				"enemies": [
					{"type": "slime", "hp": 30, "damage": 5, "count": 1}
				],
				"scheduled_actions": [
					{"time": 1.0, "type": "record_baseline", "metrics": ["core_health"]}
				],
				"validations": [
					{"time": 18.0, "type": "core_health_increased", "min_increase": 3.0}
				],
				"expected_behavior": {
					"description": "每6秒回复1.5%核心HP",
					"verification": "18秒内核心血量至少增加3点(3次治疗，每次15HP)",
					"heal_interval": 6.0,
					"heal_percent": 0.015
				}
			}
		"test_cow_totem_cow_lv2":
			return {
				"id": "test_cow_totem_cow_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"core_health": 400,
				"max_core_health": 500,
				"units": [
					{"id": "cow", "x": 0, "y": 1, "level": 2}
				],
				"expected_behavior": {
					"description": "Lv2治疗间隔缩短至4秒",
					"verification": "检查治疗频率",
					"heal_interval": 4.0,
					"heal_percent": 0.01
				}
			}
		"test_cow_totem_cow_lv3":
			return {
				"id": "test_cow_totem_cow_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 25.0,
				"core_health": 250,
				"max_core_health": 500,
				"units": [
					{"id": "cow", "x": 0, "y": 1, "level": 3}
				],
				"expected_behavior": {
					"description": "根据核心已损失血量额外回复，血量越低治疗量越高",
					"verification": "核心损失50%血量时，治疗量增加",
					"heal_interval": 4.0,
					"bonus_heal_based_on_missing_hp": true
				}
			}
		# 1.8 苦修者 (ascetic) - 伤害转MP
		"test_cow_totem_ascetic":
			return {
				"id": "test_cow_totem_ascetic",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"initial_mp": 500,
				"units": [
					{"id": "ascetic", "x": 0, "y": 1, "level": 1},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "basic_enemy", "attack_damage": 50, "count": 3}
				],
				"setup_actions": [
					{"type": "apply_buff", "buff_id": "ascetic", "target_unit_id": "squirrel"}
				],
				"expected_behavior": {
					"description": "被Buff单位受到伤害的12%转为MP",
					"verification": "松鼠受击50点伤害，MP增加6点",
					"mp_conversion": 0.12,
					"max_buff_targets": 1
				}
			}
		"test_cow_totem_ascetic_lv2":
			return {
				"id": "test_cow_totem_ascetic_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"initial_mp": 500,
				"units": [
					{"id": "ascetic", "x": 0, "y": 1, "level": 2},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "basic_enemy", "attack_damage": 50, "count": 3}
				],
				"setup_actions": [
					{"type": "apply_buff", "buff_id": "ascetic", "target_unit_id": "squirrel"}
				],
				"expected_behavior": {
					"description": "Lv2转化比例提升至18%",
					"verification": "检查MP转化数值",
					"mp_conversion": 0.18,
					"max_buff_targets": 1
				}
			}
		"test_cow_totem_ascetic_lv3":
			return {
				"id": "test_cow_totem_ascetic_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"initial_mp": 500,
				"units": [
					{"id": "ascetic", "x": 0, "y": 1, "level": 3},
					{"id": "squirrel", "x": 1, "y": 0},
					{"id": "bee", "x": -1, "y": 0}
				],
				"setup_actions": [
					{"type": "apply_buff", "buff_id": "ascetic", "target_unit_id": "squirrel"},
					{"type": "apply_buff", "buff_id": "ascetic", "target_unit_id": "bee"}
				],
				"enemies": [
					{"type": "basic_enemy", "attack_damage": 50, "count": 5}
				],
				"expected_behavior": {
					"description": "Lv3可以选择两个单位施加Buff",
					"verification": "两个被Buff单位受到伤害都转化为MP",
					"mp_conversion": 0.18,
					"max_buff_targets": 2
				}
			}
		# 1.9 植物/树苗 (plant) - 生产金币
		"test_cow_totem_plant":
			return {
				"id": "test_cow_totem_plant",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 60.0,
				"units": [
					{"id": "plant", "x": 0, "y": 1, "level": 1}
				],
				"scheduled_actions": [
					{"time": 5.0, "type": "end_wave"},
					{"time": 10.0, "type": "verify_hp", "expected_hp_percent": 1.05}
				],
				"expected_behavior": {
					"description": "每波结束后自身Max HP+5%，当前血量同步增加",
					"verification": "波次结束后检查血量是否增加",
					"hp_growth_per_wave": 0.05
				}
			}
		"test_cow_totem_plant_lv2":
			return {
				"id": "test_cow_totem_plant_lv2",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 60.0,
				"units": [
					{"id": "plant", "x": 0, "y": 1, "level": 2}
				],
				"scheduled_actions": [
					{"time": 5.0, "type": "end_wave"},
					{"time": 10.0, "type": "verify_hp", "expected_hp_percent": 1.08}
				],
				"expected_behavior": {
					"description": "Lv2每波最大血量增加8%",
					"verification": "检查成长速度",
					"hp_growth_per_wave": 0.08
				}
			}
		"test_cow_totem_plant_lv3":
			return {
				"id": "test_cow_totem_plant_lv3",
				"core_type": "cow_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 30.0,
				"units": [
					{"id": "plant", "x": 0, "y": 1, "level": 3},
					{"id": "squirrel", "x": 1, "y": 0},
					{"id": "bee", "x": 0, "y": 2}
				],
				"scheduled_actions": [
					{"time": 5.0, "type": "end_wave"},
					{"time": 10.0, "type": "verify_hp", "target": "squirrel", "expected_hp_percent": 1.05}
				],
				"expected_behavior": {
					"description": "Lv3周围一圈单位Max HP加成5%",
					"verification": "周围友方单位血量增加5%",
					"hp_growth_per_wave": 0.08,
					"aura_hp_bonus": 0.05,
					"aura_range": 1
				}
			}
		# ========== 蝙蝠图腾流派单位测试 (5个单位) ==========
		"test_bat_totem_mosquito":
			return {
				"id": "test_bat_totem_mosquito",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "mosquito", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50, "debuffs": [{"type": "bleed", "stacks": 5}]}
				],
				"scheduled_actions": [
					{"time": 1.0, "type": "record_baseline", "metrics": ["core_health"]}
				],
				"validations": [
					{"time": 8.0, "type": "core_health_increased", "min_increase": 1.0},
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_bat_totem_vampire_bat":
			return {
				"id": "test_bat_totem_vampire_bat",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 20.0,
				"core_health": 400,
				"max_core_health": 500,
				"units": [{"id": "vampire_bat", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 3, "hp": 100, "debuffs": [{"type": "bleed", "stacks": 5}]}
				],
				"scheduled_actions": [
					{"time": 1.0, "type": "record_baseline", "metrics": ["core_health"]}
				],
				"validations": [
					{"time": 18.0, "type": "core_health_increased", "min_increase": 5.0},
					{"time": 18.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_bat_totem_plague_spreader":
			return {
				"id": "test_bat_totem_plague_spreader",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "plague_spreader", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_bat_totem_blood_mage":
			return {
				"id": "test_bat_totem_blood_mage",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 12.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "blood_mage", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"scheduled_actions": [
					{"type": "skill", "time": 3.0, "source": "blood_mage", "target": {"x": 2, "y": 2}}
				],
				"validations": [
					{"time": 10.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_bat_totem_blood_mage_skill":
			return {
				"id": "test_bat_totem_blood_mage_skill",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "blood_mage", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 2, "hp": 50}
				],
				"scheduled_actions": [
					{"type": "skill", "time": 2.0, "source": "blood_mage", "target": {"x": 2, "y": 2}},
					{"type": "skill", "time": 8.0, "source": "blood_mage", "target": {"x": -2, "y": 2}}
				],
				"validations": [
					{"time": 13.0, "type": "event_occurred", "event_type": "hit", "min_count": 2}
				]
			}
		"test_bat_totem_blood_ancestor":
			return {
				"id": "test_bat_totem_blood_ancestor",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "blood_ancestor", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		# ========== 蝴蝶图腾流派单位测试 (6个单位) ==========
		"test_butterfly_totem_torch":
			return {
				"id": "test_butterfly_totem_torch",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "torch", "x": 0, "y": 1},
					{"id": "squirrel", "x": 0, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_butterfly_totem_butterfly":
			return {
				"id": "test_butterfly_totem_butterfly",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "butterfly", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_butterfly_totem_fairy_dragon":
			return {
				"id": "test_butterfly_totem_fairy_dragon",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "fairy_dragon", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_butterfly_totem_phoenix":
			return {
				"id": "test_butterfly_totem_phoenix",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "phoenix", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"scheduled_actions": [
					{"time": 3.0, "type": "skill", "source": "phoenix", "target": {"x": 2, "y": 2}}
				],
				"validations": [
					{"time": 12.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_butterfly_totem_eel":
			return {
				"id": "test_butterfly_totem_eel",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "eel", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_butterfly_totem_dragon":
			return {
				"id": "test_butterfly_totem_dragon",
				"core_type": "butterfly_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "dragon", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		# ========== 狼图腾流派单位测试 (3个单位) ==========
		"test_wolf_devour_system":
			return {
				"id": "test_wolf_devour_system",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "wolf", "x": 0, "y": 0},
					{"id": "tiger", "x": 0, "y": 1}
				],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"description": "测试狼的吞噬继承系统"
			}
		"test_wolf_totem_tiger":
			return {
				"id": "test_wolf_totem_tiger",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 12.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "tiger", "x": 0, "y": 1, "level": 1},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"scheduled_actions": [
					{"time": 3.0, "type": "skill", "source": "tiger", "target": {"x": 1, "y": 0}}
				],
				"validations": [
					{"time": 5.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "猛虎使用主动技能吞噬松鼠，释放流星雨攻击敌人",
					"verification": "技能释放不报错，流星雨对敌人造成伤害"
				}
			}
		"test_wolf_totem_dog":
			return {
				"id": "test_wolf_totem_dog",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "dog", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_wolf_totem_lion":
			return {
				"id": "test_wolf_totem_lion",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "lion", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		# ========== 眼镜蛇图腾流派单位测试 (7个单位) ==========
		"test_viper_totem_spider":
			return {
				"id": "test_viper_totem_spider",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "spider", "x": 0, "y": 1, "level": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_viper_totem_snowman":
			return {
				"id": "test_viper_totem_snowman",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "snowman", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_viper_totem_scorpion":
			return {
				"id": "test_viper_totem_scorpion",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "scorpion", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_viper_totem_viper":
			return {
				"id": "test_viper_totem_viper",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "viper", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_viper_totem_arrow_frog":
			return {
				"id": "test_viper_totem_arrow_frog",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "arrow_frog", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_viper_totem_medusa":
			return {
				"id": "test_viper_totem_medusa",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "medusa", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_viper_totem_lure_snake":
			return {
				"id": "test_viper_totem_lure_snake",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "lure_snake", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		# ========== 鹰图腾流派单位测试 (12个单位) ==========
		"test_eagle_totem_harpy_eagle":
			return {
				"id": "test_eagle_totem_harpy_eagle",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "harpy_eagle", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_gale_eagle":
			return {
				"id": "test_eagle_totem_gale_eagle",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "gale_eagle", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_kestrel":
			return {
				"id": "test_eagle_totem_kestrel",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "kestrel", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_owl":
			return {
				"id": "test_eagle_totem_owl",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "owl", "x": 0, "y": 1},
					{"id": "eagle", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "猫头鹰是支援单位，为相邻友军提供暴击率加成",
					"note": "鹰单位攻击产生命中事件，验证猫头鹰的buff生效"
				}
			}
		"test_eagle_totem_eagle":
			return {
				"id": "test_eagle_totem_eagle",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "eagle", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_vulture":
			return {
				"id": "test_eagle_totem_vulture",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "vulture", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_magpie":
			return {
				"id": "test_eagle_totem_magpie",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "magpie", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_pigeon":
			return {
				"id": "test_eagle_totem_pigeon",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "pigeon", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_woodpecker":
			return {
				"id": "test_eagle_totem_woodpecker",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "woodpecker", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_parrot":
			return {
				"id": "test_eagle_totem_parrot",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 12.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "parrot", "x": 0, "y": 1},
					{"id": "squirrel", "x": 1, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 2, "hp": 50}
				],
				"validations": [
					{"time": 10.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "鹦鹉需要捕捉其他远程单位的子弹才能攻击",
					"note": "松鼠(squirrel)提供远程子弹供鹦鹉捕捉"
				}
			}
		"test_eagle_totem_peacock":
			return {
				"id": "test_eagle_totem_peacock",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "peacock", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_eagle_totem_storm_eagle":
			return {
				"id": "test_eagle_totem_storm_eagle",
				"core_type": "eagle_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 10.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [{"id": "storm_eagle", "x": 0, "y": 1}],
				"enemies": [
					{"type": "slime", "count": 1, "hp": 50}
				],
				"validations": [
					{"time": 8.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		# ========== 流血和吸血系统测试 ==========
		"test_bleed_lifesteal_system":
			return {
				"id": "test_bleed_lifesteal_system",
				"core_type": "bat_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 12.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "mosquito", "x": 0, "y": 1},
					{"id": "blood_mage", "x": 1, "y": 1}
				],
				"enemies": [
					{"type": "slime", "count": 2, "hp": 50, "debuffs": [{"type": "bleed", "stacks": 5}]}
				],
				"scheduled_actions": [
					{"time": 1.0, "type": "record_baseline", "metrics": ["core_health"]}
				],
				"validations": [
					{"time": 10.0, "type": "core_health_increased", "min_increase": 1.0},
					{"time": 11.0, "type": "event_occurred", "event_type": "hit", "min_count": 2}
				]
			}
		"test_charm_system":
			return {
				"id": "test_charm_system",
				"core_type": "wolf_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "fox", "x": 0, "y": 1, "level": 1}
				],
				"enemies": [
					{"type": "slime", "count": 3, "hp": 50, "damage": 5}
				],
				"description": "测试狐狸魅惑系统（狐狸被攻击时15%概率魅惑敌人）",
				"validations": [
					{"time": 14.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				],
				"expected_behavior": {
					"description": "狐狸被敌人攻击时有15%概率魅惑攻击者",
					"note": "移除守护单位确保狐狸会被攻击，增加测试时长和敌人数量以提高触发概率"
				}
			}
		"test_medusa_petrify":
			return {
				"id": "test_medusa_petrify",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "medusa", "x": 0, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 2, "hp": 80}
				],
				"description": "测试美杜莎石化凝视和石块生成（需要等待石化触发）",
				"validations": [
					{"time": 13.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
		"test_medusa_petrify_juice":
			return {
				"id": "test_medusa_petrify_juice",
				"core_type": "viper_totem",
				"initial_gold": 1000,
				"start_wave_index": 1,
				"duration": 15.0,
				"core_health": 2000,
				"max_core_health": 2000,
				"units": [
					{"id": "medusa", "x": 0, "y": 0}
				],
				"enemies": [
					{"type": "slime", "count": 2, "hp": 80}
				],
				"description": "测试美杜莎石化Juice效果：动画冻结、碎裂图像、石块伤害",
				"validations": [
					{"time": 13.0, "type": "event_occurred", "event_type": "hit", "min_count": 1}
				]
			}
	return {}
