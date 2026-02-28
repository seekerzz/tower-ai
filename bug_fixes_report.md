# Bug Fixes Report

**Date:** 2026-02-28
**Programmer Agent:** Bug Fixer

## Summary

This report documents bugs found during AI testing of the Totem Tower game. The test result files did not exist at the time of review, so a comprehensive code audit was performed against the GameDesign.md specifications.

## Bugs Fixed

### 1. HIGH: sell_unit Crash - Vector2i Type Conversion Error

**File:** `/home/zhangzhan/tower/src/Autoload/AIActionExecutor.gd`

**Line:** 232

**Issue:** In the `_action_sell_unit` function, when selling a unit from the grid zone, the code was passing the raw `pos` variable (which could be a Dictionary or Array from JSON) to `BoardController.sell_unit()` instead of the parsed `grid_pos` (which is a proper Vector2i). This caused a type conversion error and crash.

**Fix:** Changed line 232 to use the properly converted position:
- For grid zone: use `grid_pos` (Vector2i)
- For bench zone: use `bench_index` (int)

```gdscript
# Before:
var result = BoardController.sell_unit(zone, pos)

# After:
var sell_pos = grid_pos if zone == "grid" else bench_index
var result = BoardController.sell_unit(zone, sell_pos)
```

### 2. CRITICAL: Missing `has_method` Check in DefaultBehavior.gd

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/DefaultBehavior.gd`

**Issue:** The `on_projectile_hit` method accesses `source.behavior.get_debuff_chance()` without checking if `source` has the `behavior` property or if `behavior` has the `get_debuff_chance` method. This could cause a null reference error.

**Fix:** Added proper null and method existence checks.

### 3. HIGH: Dog Behavior Missing Cooldown Reset on Skill End

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Dog.gd`

**Issue:** When the rage skill ends, the `original_atk_speed` is restored, but there's no check to ensure `original_atk_speed` was properly initialized (not 0). If `on_skill_activated` is called multiple times rapidly, it could cause incorrect attack speed values.

**Fix:** Added initialization check and protection against multiple activations.

### 4. HIGH: Mosquito Behavior Missing Bleed Check

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Mosquito.gd`

**Issue:** Line 14 checks for `target.bleed_stacks` but doesn't verify the enemy actually has this property before accessing it, which could cause errors.

**Fix:** Added property existence check before accessing bleed_stacks.

### 5. MEDIUM: Peacock Behavior Attack Counter Bug

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Peacock.gd`

**Issue:** The `attack_counter` is incremented at line 107, but the comparison at line 20 checks `if attack_counter >= 3`. This means the special attack triggers on the 4th attack (counter = 3 after increment on 3rd attack), not the 3rd as intended per design spec.

**Fix:** Fixed the counter logic to properly trigger on the 3rd attack.

### 6. MEDIUM: Plant Behavior Missing Signal Disconnect Check

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Plant.gd`

**Issue:** Line 7 connects to `GameManager.wave_ended` but doesn't check if the signal is already connected before connecting, which could cause "signal already connected" errors if the unit is re-initialized.

**Fix:** Added check to prevent duplicate signal connections.

### 7. MEDIUM: Cow Behavior Incorrect Heal Interval

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Cow.gd`

**Issue:** According to GameDesign.md, the Cow should heal every 5 seconds at level 1, 4 seconds at level 2, and have bonus healing at level 3. The code sets `heal_interval = 6.0` initially, which is incorrect.

**Fix:** Changed initial heal interval from 6.0 to 5.0 seconds to match design spec.

### 8. LOW: IronTurtle Behavior Missing Source Validation

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/IronTurtle.gd`

**Issue:** Line 12 accesses `source` without null checking in some code paths.

**Fix:** Added null check for source parameter.

### 9. LOW: Butterfly Skill Cost Inconsistency

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Butterfly.gd`

**Issue:** The skill uses `GameManager.max_mana * 0.05` (5% of max mana), but the design document specifies "消耗5%最大法力" which is correctly implemented. However, there's no check if mana consumption actually succeeded before applying damage bonus.

**Fix:** Added check to ensure mana was actually consumed before enabling empowered state.

### 10. CRITICAL: Gargoyle Using Non-existent Signal

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Gargoyle.gd`

**Issue:** The code tries to connect to `GameManager.core_health_changed` signal, but this signal doesn't exist in GameManager. It exists in `SessionData` instead. This causes a runtime error.

**Fix:** Changed to connect to `GameManager.session_data.core_health_changed` signal with proper null checking.

### 11. HIGH: BloodAncestor Using Wrong Healing Method

**File:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/BloodAncestor.gd`

**Issue:** The code uses `GameManager.damage_core(-heal_amt)` for healing, which is incorrect. The `damage_core` function is designed for damage, not healing, and negative values may not work correctly.

**Fix:** Changed to use `GameManager.heal_core(heal_amt)` which is the proper healing method.

## Files Modified

1. `/home/zhangzhan/tower/src/Autoload/AIActionExecutor.gd`
2. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/DefaultBehavior.gd`
3. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Dog.gd`
4. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Mosquito.gd`
5. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Peacock.gd`
6. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Plant.gd`
7. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Cow.gd`
8. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/IronTurtle.gd`
9. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Butterfly.gd`
10. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Gargoyle.gd`
11. `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/BloodAncestor.gd`

## Additional Notes

- The Lion behavior file (`/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Lion.gd`) is essentially empty and needs implementation according to the design spec (circular shockwave attack).
- The Parrot behavior has complex mimic logic that may need additional testing.
- Several units marked as "❌" (not implemented) in GameDesign.md were not reviewed for bugs.
- The Shadow Bat unit (marked ❌ in design doc) is not implemented.
- The Storm Eagle unit (marked ❌ in design doc) is not implemented.
- The Echo Amplifier unit (marked ❌ in design doc) is not implemented.

## Verification

All fixes have been verified to:
1. Not introduce syntax errors
2. Follow the existing code patterns
3. Match the GameDesign.md specifications
4. Include proper null checks where applicable
