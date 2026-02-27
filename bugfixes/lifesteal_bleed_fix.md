# 蝙蝠图腾吸血机制修复记录

## 问题描述

游戏策划在评审中发现吸血机制根因：`LifestealManager`监听的是`enemy_hit`信号，但流血伤害发射的是`bleed_damage`信号，导致吸血机制虽然触发但无法正确处理流血伤害。

## 修复前状态

- 仅监听 `enemy_hit` 信号
- 流血伤害（bleed_damage）无法触发吸血

## 修复内容

### 1. 信号监听修改

文件：`src/Scripts/Managers/LifestealManager.gd`

在 `_ready()` 函数中同时监听两个信号：

```gdscript
func _ready():
    # Connect to GameManager signals for lifesteal
    # Signal signature: enemy_hit(enemy, source, amount)
    GameManager.enemy_hit.connect(_on_damage_dealt)
    # Signal signature: bleed_damage(target, damage, stacks, source)
    GameManager.bleed_damage.connect(_on_bleed_damage)
```

### 2. 添加 `_on_bleed_damage` 处理函数

新增处理函数，逻辑参照 `_on_damage_dealt`：

```gdscript
func _on_bleed_damage(target, damage, stacks, source):
    """
    Handle bleed damage event for lifesteal.
    Called when bleed damage is applied to an enemy.
    """
    if !is_instance_valid(target) or !is_instance_valid(source):
        return

    # Check if source is a Bat Totem unit
    if not _is_bat_totem_unit(source):
        return

    # Calculate lifesteal amount based on bleed stacks
    var multiplier = GameManager.get_global_buff("lifesteal_multiplier", 1.0)
    var risk_reward_multiplier = _calculate_risk_reward_multiplier()
    var lifesteal_amount = stacks * 1.5 * lifesteal_ratio * multiplier * risk_reward_multiplier

    # Cap lifesteal amount to 5% of max core health per hit
    var max_heal = GameManager.max_core_health * 0.05
    lifesteal_amount = min(lifesteal_amount, max_heal)

    if lifesteal_amount > 0:
        var old_hp = GameManager.core_health
        print("[LifestealManager] About to heal: ", lifesteal_amount, " current HP: ", old_hp)
        # Directly modify core_health if heal_core fails
        if GameManager.has_method("heal_core"):
            GameManager.heal_core(lifesteal_amount)
        else:
            GameManager.core_health = min(GameManager.max_core_health, GameManager.core_health + lifesteal_amount)
        print("[LifestealManager] After heal HP: ", GameManager.core_health)

        lifesteal_occurred.emit(source, lifesteal_amount)
        _show_lifesteal_effect(target.global_position, lifesteal_amount)
        print("[LifestealManager] Bleed stacks: ", stacks, ", Lifesteal: ", lifesteal_amount)
```

### 3. 风险收益机制

吸血计算包含风险收益机制（核心HP≤35%时翻倍）：

```gdscript
func _calculate_risk_reward_multiplier() -> float:
    """
    Risk-reward mechanism:
    - Core HP > 35%: normal (1.0x)
    - Core HP <= 35%: doubled (2.0x)
    """
    var core_health_percent = GameManager.core_health / GameManager.max_core_health
    if core_health_percent <= 0.35:
        return 2.0  # Critical state: lifesteal doubled
    return 1.0  # Normal state
```

## 吸血量计算公式

```
吸血量 = 流血层数 × 1.5 × 吸血比例 × 全局增益倍数 × 风险收益倍数

其中：
- 流血层数：目标敌人当前的流血层数
- 1.5：基础伤害系数
- 吸血比例：lifesteal_ratio (默认0.8)
- 全局增益倍数：来自游戏全局buff
- 风险收益倍数：核心HP≤35%时为2.0，否则为1.0

上限：单次吸血不超过核心最大血量的5%
```

## 验证状态

- [x] 代码实现完成
- [ ] AI玩家低血量测试验证

## 相关文件

- `src/Scripts/Managers/LifestealManager.gd` - 吸血管理器主文件

## 修复日期

2026-02-25
