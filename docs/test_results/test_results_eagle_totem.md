# Eagle Totem Unit Test Report

**Date:** 2026-02-28 14:46:49

## Summary

- **Total Tests:** 26
- **Passed:** 15
- **Failed:** 11
- **Bugs Found:** 7

## Units Tested

- harpy_eagle - Triple claw attack, crit on 3rd hit
- gale_eagle - Wind blade attack, multi-hit
- kestrel - Dive attack with stun
- owl - Crit rate buff for adjacent allies
- eagle - Long range, priority high HP targets
- vulture - Priority low HP, permanent ATK boost on kill
- magpie - Steal attributes from enemies
- pigeon - Dodge chance, counter-attack on dodge
- woodpecker - Stacking damage on same target
- storm_eagle - Storm charge on crits
- echo_amplifier - Echo damage buff

## Bugs Found

### Bug #1: harpy_eagle

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy harpy_eagle
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

### Bug #2: gale_eagle

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy gale_eagle
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

### Bug #3: kestrel

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy kestrel
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

### Bug #4: owl

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy owl
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

### Bug #5: eagle

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy eagle
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

### Bug #6: vulture

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy vulture
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

### Bug #7: magpie

**Description:** BoardController.try_move_unit returns failure even though grid check passes (can_place=true)

**Reproduction Steps:**
```
1. Select eagle_totem
2. Buy magpie
3. Try to place on grid at valid position (e.g., {-1,0})
4. Observe error: grid_check.can_place=true but try_move_unit fails
```

## Detailed Test Results

| Test Name | Status | Details |
|-----------|--------|---------|
| select_eagle_totem | PASS | Event: ActionsCompleted |
| harpy_eagle_set_shop | PASS | Unit set in shop |
| harpy_eagle_buy | PASS | Unit purchased |
| harpy_eagle_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| gale_eagle_set_shop | PASS | Unit set in shop |
| gale_eagle_buy | PASS | Unit purchased |
| gale_eagle_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| kestrel_set_shop | PASS | Unit set in shop |
| kestrel_buy | PASS | Unit purchased |
| kestrel_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| owl_set_shop | PASS | Unit set in shop |
| owl_buy | PASS | Unit purchased |
| owl_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| eagle_set_shop | PASS | Unit set in shop |
| eagle_buy | PASS | Unit purchased |
| eagle_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| vulture_set_shop | PASS | Unit set in shop |
| vulture_buy | PASS | Unit purchased |
| vulture_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| magpie_set_shop | PASS | Unit set in shop |
| magpie_buy | PASS | Unit purchased |
| magpie_place | FAIL | Expected: ActionsCompleted, Actual: ActionError |
| pigeon_set_shop | FAIL | Expected: ActionsCompleted, Actual: Error |
| woodpecker_set_shop | FAIL | Expected: ActionsCompleted, Actual: Error |
| storm_eagle_set_shop | FAIL | Expected: ActionsCompleted, Actual: Error |
| echo_amplifier_set_shop | FAIL | Expected: ActionsCompleted, Actual: Error |

## Overall Assessment

Several issues were found during testing. Please review the bugs section above and address the identified problems.
