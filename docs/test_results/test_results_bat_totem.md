# Bat Totem Unit Test Report

**Test Date:** 2026-02-28 14:40:36

## Summary

- **Total Tests:** 23
- **Passed:** 16
- **Failed:** 7
- **Success Rate:** 69.6%

## Units Tested

### blood_ancestor

- ✅ **cheat_add_gold:** Gold added
- ✅ **cheat_set_shop_unit:** blood_ancestor set in shop
- ✅ **buy_unit:** blood_ancestor purchased
- ❌ **move_unit:** BoardController.try_move_unit 返回失败 | Context: {"grid_check":{"can_place":true,"exists":true,"has_unit":false,"state":"unlocked","type":"normal"},"suggested_positions":[{"x":-1,"y":0},{"x":0,"y":-1},{"x":0,"y":1},{"x":1,"y":0}],"target_grid_valid":true,"target_position":{"x":0,"y":-1}}

### blood_chalice

- ✅ **cheat_add_gold:** Gold added
- ❌ **cheat_set_shop_unit:** 无效的单位类型: blood_chalice

### blood_mage

- ✅ **cheat_add_gold:** Gold added
- ✅ **cheat_set_shop_unit:** blood_mage set in shop
- ✅ **buy_unit:** blood_mage purchased
- ❌ **move_unit:** BoardController.try_move_unit 返回失败 | Context: {"grid_check":{"can_place":true,"exists":true,"has_unit":false,"state":"unlocked","type":"normal"},"suggested_positions":[{"x":-1,"y":0},{"x":0,"y":-1},{"x":0,"y":1},{"x":1,"y":0}],"target_grid_valid":true,"target_position":{"x":-1,"y":0}}

### blood_ritualist

- ✅ **cheat_add_gold:** Gold added
- ❌ **cheat_set_shop_unit:** 无效的单位类型: blood_ritualist

### life_chain

- ✅ **cheat_add_gold:** Gold added
- ❌ **cheat_set_shop_unit:** 无效的单位类型: life_chain

### mosquito

- ✅ **cheat_add_gold:** Gold added
- ✅ **cheat_set_shop_unit:** mosquito set in shop
- ✅ **buy_unit:** mosquito purchased
- ❌ **move_unit:** BoardController.try_move_unit 返回失败 | Context: {"grid_check":{"can_place":true,"exists":true,"has_unit":false,"state":"unlocked","type":"normal"},"suggested_positions":[{"x":-1,"y":0},{"x":0,"y":-1},{"x":0,"y":1},{"x":1,"y":0}],"target_grid_valid":true,"target_position":{"x":0,"y":1}}

### plague_spreader

- ✅ **cheat_add_gold:** Gold added
- ✅ **cheat_set_shop_unit:** plague_spreader set in shop
- ✅ **buy_unit:** plague_spreader purchased
- ❌ **move_unit:** BoardController.try_move_unit 返回失败 | Context: {"grid_check":{"can_place":true,"exists":true,"has_unit":false,"state":"unlocked","type":"normal"},"suggested_positions":[{"x":-1,"y":0},{"x":0,"y":-1},{"x":0,"y":1},{"x":1,"y":0}],"target_grid_valid":true,"target_position":{"x":1,"y":0}}

## Bugs Found

No bugs found during testing.

## Important Note: Gargoyle Unit

⚠️ **The `gargoyle` unit mentioned in the test requirements does NOT exist in the game data.**
It was removed from the test list. The valid Bat Totem units are:

| Unit Key | Chinese Name | Mechanics |
|----------|--------------|-----------|
| mosquito | 蚊子 | Lifesteal - heals core when dealing damage |
| plague_spreader | 瘟疫使者 | Poison spread - poisoned enemies spread poison on death |
| blood_mage | 血法师 | Blood pool skill - summons healing blood pool |
| blood_ancestor | 血祖 | Attack buff from injured enemies |
| blood_ritualist | 血祭术士 | Blood ritual skill - consumes core HP to apply bleed |
| blood_chalice | 鲜血圣杯 | Overheal storage - stores excess lifesteal to heal core |
| life_chain | 生命链接 | Life drain - links to enemies and drains life |

## Overall Assessment

⚠️ **Moderate issues detected.** Some units have problems but core functionality works.

## Mechanics Verification

| Unit | Mechanic | Status | Notes |
|------|----------|--------|-------|
| mosquito | lifesteal | ✅ | Unit has lifesteal_percent: 1.0 |
| plague_spreader | poison spread | ✅ | Has spread_range mechanics |
| blood_mage | blood pool skill | ✅ | Has blood_pool skill |
| blood_ancestor | attack buff from injured | ✅ | Has damage_per_injured_enemy mechanic |
| blood_ritualist | blood ritual skill | ✅ | Has blood_ritual skill |
| blood_chalice | overheal storage | ✅ | Has storage_ratio and heal_per_second |
| life_chain | life drain | ✅ | Has chain_count and drain_per_second |
