## Design Proposal #001: Missing Units Implementation

### Overview
This document provides detailed design specifications for 5 missing units that are referenced in the game design document but not yet fully implemented. These designs follow the established patterns in `docs/GameDesign.md` and balance against existing units in `data/game_data.json`.

---

## Unit 1: Shell (贝壳)

**Faction:** Universal
**Type:** Support
**Icon:** 🐚

### Theme & Mechanic
The Shell is a defensive support unit that generates a valuable "Pearl" relic if it survives combat without taking too many hits. This creates a risk/reward gameplay loop where players must protect the Shell to gain a significant economic advantage.

**Core Mechanic: Pearl Generation**
- The Shell tracks how many times it has been hit by enemies
- If the Shell survives a wave (or the entire battle) with hits below the threshold, it generates a Pearl relic
- The Pearl provides bonus gold and then the Shell is removed from play
- At higher levels, the Shell becomes tankier and provides defensive auras while active

### Stats by Level

| Level | HP | Hit Threshold | Pearl Value | Damage Reduction Aura |
|-------|-----|---------------|-------------|----------------------|
| 1 | 200 | 5 hits | 50 gold | None |
| 2 | 300 | 8 hits | 75 gold | None |
| 3 | 450 | 8 hits | 100 gold | 5% for adjacent allies |

### Detailed Mechanics

**Level 1 - Fragile Pearl:**
- Base HP: 200
- Hit Threshold: 5 (takes damage 5 times max)
- If threshold not exceeded by wave end: Generate 50 gold, unit removed
- No attack capability

**Level 2 - Sturdy Shell:**
- HP increased to 300
- Hit Threshold: 8 (more forgiving)
- Pearl Value: 75 gold
- Still removed after generating pearl

**Level 3 - Pearl Guardian:**
- HP increased to 450
- Hit Threshold: 8
- Pearl Value: 100 gold
- **New:** While active, provides 5% damage reduction to adjacent allies (Pearl Aura)
- After pearl generation, the aura persists for the remainder of the wave

### Implementation Notes

**New Properties to Track:**
```gdscript
var hit_count: int = 0
var hit_threshold: int = 5
var pearl_value: int = 50
var has_generated_pearl: bool = false
var damage_reduction_active: bool = false
```

**Signal Connections:**
- Connect to `GameManager.wave_ended` to check threshold and generate pearl
- Connect to unit's `damage_blocked` or override `on_damage_taken` to track hits

**Visual/Audio Feedback:**
- Visual: Shell glows brighter as it gets closer to threshold (green -> yellow -> red)
- Visual: Pearl generation spawns a golden orb that flies to the gold counter
- Audio: Satisfying "ching" sound when pearl is generated
- Audio: Cracking sound when hit

**Behavior Script:** `Shell.gd` extends `BuffProviderBehavior.gd`

---

## Unit 2: Rage Bear (暴怒熊)

**Faction:** Universal
**Type:** Melee
**Icon:** 🐻

### Theme & Mechanic
The Rage Bear is a heavy melee unit specializing in crowd control through stuns. Unlike the existing Bear unit which focuses on raw damage, the Rage Bear builds up stun potential and deals massive damage to stunned targets.

**Core Mechanic: Stun Mastery**
- Attacks have a chance to stun enemies
- Deals bonus damage to already-stunned enemies
- Active skill creates a powerful ground slam that stuns all enemies in range

### Stats by Level

| Level | Damage | HP | Attack Speed | Stun Chance | Stun Duration | Bonus vs Stunned |
|-------|--------|-----|--------------|-------------|---------------|------------------|
| 1 | 80 | 400 | 1.2s | 15% | 1.0s | +50% |
| 2 | 120 | 600 | 1.2s | 22% | 1.2s | +75% |
| 3 | 180 | 900 | 1.2s | 30% | 1.5s | +100% |

### Detailed Mechanics

**Level 1 - Stun Basher:**
- Base Damage: 80
- HP: 400
- Attack Speed: 1.2s
- Passive: 15% chance to stun for 1.0 second
- Passive: Deals +50% damage to stunned enemies
- Skill (Slam): 300 mana, 15s CD - Ground slam stuns all enemies in 150 range for 1.5s

**Level 2 - Stun Specialist:**
- Damage: 120, HP: 600
- Stun Chance: 22%
- Stun Duration: 1.2s
- Bonus vs Stunned: +75%
- Skill stun duration: 2.0s

**Level 3 - Stun Master:**
- Damage: 180, HP: 900
- Stun Chance: 30%
- Stun Duration: 1.5s
- Bonus vs Stunned: +100% (double damage!)
- Skill stun duration: 2.5s
- **New:** Killing a stunned enemy resets the skill cooldown (10s internal CD)

### Implementation Notes

**New Properties to Track:**
```gdscript
var stun_chance: float = 0.15
var stun_duration: float = 1.0
var bonus_vs_stunned: float = 0.5
var skill_stun_duration: float = 1.5
var kill_reset_internal_cd: float = 0.0  # For Lv3
```

**Signal Connections:**
- Connect to `GameManager.skill_activated` for the slam skill
- Track kills to check for cooldown reset (Lv3)

**Visual/Audio Feedback:**
- Visual: Bear glows red when attacking stunned enemies (bonus damage proc)
- Visual: Stunned enemies show stars above their heads
- Visual: Skill creates expanding shockwave circle
- Audio: Heavy thud on stun proc
- Audio: Roar sound for skill activation

**Behavior Script:** `RageBear.gd` extends `DefaultBehavior.gd`

**Note:** This unit is distinct from the existing `bear` unit in game_data.json which has different stats and mechanics.

---

## Unit 3: Sunflower (向日葵)

**Faction:** Universal
**Type:** Support
**Icon:** 🌻

### Theme & Mechanic
The Sunflower is a mana generation unit that passively produces mana over time. It serves as an economic engine for spell-heavy compositions, allowing players to sustain expensive active skills.

**Core Mechanic: Mana Photosynthesis**
- Generates mana every few seconds
- Higher levels generate more mana and generate it more frequently
- At max level, becomes a "Double-Headed Sunflower" with doubled production

### Stats by Level

| Level | HP | Mana per Tick | Tick Interval | Mana per Second |
|-------|-----|---------------|---------------|-----------------|
| 1 | 80 | 10 | 5.0s | 2.0/s |
| 2 | 120 | 18 | 4.0s | 4.5/s |
| 3 | 180 | 18 | 4.0s | 9.0/s (Double Head) |

### Detailed Mechanics

**Level 1 - Seedling:**
- HP: 80
- Generates 10 mana every 5.0 seconds
- No attack capability
- Vulnerable but cheap economic investment

**Level 2 - Blooming:**
- HP: 120
- Generates 18 mana every 4.0 seconds
- 125% more efficient than Level 1
- Better survivability

**Level 3 - Twin-Headed:**
- HP: 180
- **Double Head:** Generates mana twice per tick (36 mana every 4.0 seconds)
- Effectively 9 mana/second
- Visual shows two sunflower heads

### Implementation Notes

**New Properties to Track:**
```gdscript
var mana_per_tick: int = 10
var tick_interval: float = 5.0
var tick_timer: float = 0.0
var is_double_headed: bool = false  # Lv3
```

**Signal Connections:**
- None required (self-contained timer)

**Visual/Audio Feedback:**
- Visual: Sunflower pulses with yellow glow when generating mana
- Visual: Lv3 shows two distinct sunflower heads
- Visual: Mana particles float from sunflower to mana bar
- Audio: Soft "pop" sound on mana generation
- Audio: Blooming sound on level up

**Behavior Script:** `Sunflower.gd` extends `DefaultBehavior.gd`

**Balance Note:** Compare to Plant (cow faction) which generates HP - Sunflower generates mana instead. Cost should be similar (20-40 gold range).

---

## Unit 4: Blood Meat (血食)

**Faction:** Wolf
**Type:** Support/Buff
**Icon:** 🥩

### Theme & Mechanic
Blood Meat is a unique Wolf faction unit that synergizes with the devour/sacrifice mechanics. It serves as "food" for other wolf units, providing powerful temporary buffs when devoured. It can also sacrifice itself to trigger powerful effects.

**Core Mechanic: Living Sacrifice**
- Can be devoured by other Wolf units for enhanced bonuses
- Provides temporary buffs to adjacent Wolf units
- Can activate a self-sacrifice skill to heal core and boost all Wolf units

### Stats by Level

| Level | HP | Adjacent Buff | Devour Bonus | Sacrifice Heal | Sacrifice Duration |
|-------|-----|---------------|--------------|----------------|-------------------|
| 1 | 150 | +10% ATK | +20% ATK, +20% HP | 5% Core HP | 5s |
| 2 | 225 | +15% ATK | +30% ATK, +30% HP | 8% Core HP | 6s |
| 3 | 337 | +20% ATK | +40% ATK, +40% HP | 10% Core HP | 8s |

### Detailed Mechanics

**Level 1 - Fresh Meat:**
- HP: 150
- Passive Aura: Adjacent Wolf units gain +10% Attack
- When devoured: Devouring unit gets +20% ATK and +20% HP for 10 seconds
- Skill (Sacrifice): 50 mana, 20s CD - Destroy self, heal core 5% max HP, all Wolf units gain +25% ATK for 5s

**Level 2 - Enriched Blood:**
- HP: 225
- Aura: +15% ATK to adjacent Wolves
- Devour Bonus: +30% ATK, +30% HP for 12 seconds
- Sacrifice Heal: 8% Core HP
- Sacrifice Buff: +30% ATK for 6s to all Wolves

**Level 3 - Blood Feast:**
- HP: 337
- Aura: +20% ATK to adjacent Wolves
- Devour Bonus: +40% ATK, +40% HP for 15 seconds
- Sacrifice Heal: 10% Core HP
- Sacrifice Buff: +40% ATK for 8s to all Wolves
- **New:** When any Wolf unit devours anything, Blood Meat gains a stack (max 5). Each stack increases aura by +2% ATK.

### Implementation Notes

**New Properties to Track:**
```gdscript
var adjacent_wolf_buff: float = 0.10
var devour_atk_bonus: float = 0.20
var devour_hp_bonus: float = 0.20
var sacrifice_heal_percent: float = 0.05
var sacrifice_buff_percent: float = 0.25
var sacrifice_duration: float = 5.0
var blood_stacks: int = 0  # Lv3
var max_blood_stacks: int = 5
```

**Signal Connections:**
- Connect to `GameManager.unit_devoured` to track devours (for Lv3 stacks)
- Connect to `GameManager.wave_started` to reset stacks

**Visual/Audio Feedback:**
- Visual: Pulsing red aura around Blood Meat
- Visual: Blood particles flow to adjacent Wolf units
- Visual: When devoured, creates blood explosion buff effect on devourer
- Visual: Lv3 stacks show as floating blood orbs above the unit
- Audio: Wet "splat" on devour interaction
- Audio: Deep heartbeat sound for aura pulse

**Behavior Script:** `BloodMeat.gd` extends `BuffProviderBehavior.gd`

**Faction Synergy:**
- Works with: Wolf (devour), Dog (rage synergy), Tiger (meteor synergy)
- Strategy: Place in center of Wolf composition for aura, sacrifice when needed, or feed to carry unit

---

## Unit 5: Lion (狮子)

**Faction:** Wolf (Note: Currently in Wolf faction per game_data.json, but design doc mentions Eagle)
**Type:** Melee
**Icon:** 🦁

### Theme & Mechanic
The Lion is a powerful melee unit that transforms its attacks into circular shockwaves, dealing damage to all enemies within range. This makes it exceptional against grouped enemies and provides consistent area damage.

**Core Mechanic: Circular Shockwave**
- All attacks become circular shockwaves (no single-target)
- Shockwave deals damage to ALL enemies within range
- Higher levels increase shockwave radius and add secondary effects

### Stats by Level

| Level | Damage | HP | Attack Speed | Range | Shockwave Radius |
|-------|--------|-----|--------------|-------|------------------|
| 1 | 150 | 200 | 2.0s | 200 | 150 |
| 2 | 225 | 300 | 2.0s | 200 | 180 |
| 3 | 337 | 450 | 2.0s | 200 | 200 |

### Detailed Mechanics

**Level 1 - Roar:**
- Damage: 150
- HP: 200
- Attack Speed: 2.0s (slow but powerful)
- Range: 200
- Shockwave Radius: 150
- All attacks hit every enemy within shockwave radius
- 100% damage to all targets (no falloff)

**Level 2 - Thunderous Roar:**
- Damage: 225, HP: 300
- Shockwave Radius: 180 (+20%)
- **New:** Shockwaves have 20% chance to knock back small enemies

**Level 3 - King of Beasts:**
- Damage: 337, HP: 450
- Shockwave Radius: 200
- Knockback chance: 30%
- **New:** Every 3rd roar creates a secondary delayed shockwave (0.5s delay, 50% damage)
- Secondary shockwave has 100% knockback chance

### Implementation Notes

**New Properties to Track:**
```gdscript
var shockwave_radius: float = 150.0
var roar_counter: int = 0  # For Lv3 secondary shockwave
var knockback_chance: float = 0.0
var secondary_shockwave_delay: float = 0.5
```

**Signal Connections:**
- None required (handled in combat tick override)

**Visual/Audio Feedback:**
- Visual: Expanding orange/red ring for shockwave
- Visual: Lion rears up before roaring (attack windup)
- Visual: Secondary shockwave (Lv3) is a darker red ring
- Visual: Knockback creates dust particles
- Audio: Powerful lion roar for each attack
- Audio: Echo effect for secondary shockwave

**Behavior Script:** `Lion.gd` extends `DefaultBehavior.gd`

**Implementation Pattern:**
The Lion behavior should override `on_combat_tick` to return `true` (taking over attack logic) and implement custom shockwave spawning. Reference `UnitLion.gd` which already has partial implementation.

**Current Implementation Status:**
- `src/Scripts/Units/Wolf/UnitLion.gd` exists with shockwave logic
- `src/Scripts/Units/Behaviors/Lion.gd` is empty (only extends DefaultBehavior)
- Need to move logic from UnitLion.gd to Lion.gd behavior or coordinate between them

---

## Summary Table

| Unit | Faction | Type | Core Mechanic | Cost Range |
|------|---------|------|---------------|------------|
| Shell | Universal | Support | Pearl generation (survival reward) | 40-80 gold |
| Rage Bear | Universal | Melee | Stun mastery + bonus vs stunned | 65-260 gold |
| Sunflower | Universal | Support | Mana generation over time | 20-80 gold |
| Blood Meat | Wolf | Support | Devour synergy + sacrifice | 50-200 gold |
| Lion | Wolf | Melee | Circular shockwave AoE | 90-360 gold |

---

## Implementation Priority

1. **Sunflower** - Simplest implementation, clear utility, fills mana generation niche
2. **Lion** - Behavior file exists but empty, shockwave mechanic already partially implemented
3. **Rage Bear** - Stun mechanic exists in codebase (Kestrel reference), straightforward
4. **Shell** - Requires new relic/pearl mechanic integration
5. **Blood Meat** - Most complex, requires devour system integration and faction synergy

---

## Files to Create/Modify

### New Behavior Files:
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Shell.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/RageBear.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Sunflower.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/BloodMeat.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Lion.gd` (complete the existing stub)

### Data File Updates:
- `/home/zhangzhan/tower/data/game_data.json` - Add/update unit entries for all 5 units

### Potential New Assets:
- Shockwave effect scene for Lion (may already exist at `res://src/Scenes/Effects/Shockwave.tscn`)
- Pearl visual effect for Shell
- Blood particle effects for Blood Meat

---

*Document Version: 1.0*
*Created: 2026-02-28*
*Based on: GameDesign.md v2026-02-25*
