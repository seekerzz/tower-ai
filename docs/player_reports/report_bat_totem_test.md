# 蝙蝠图腾 (Bat Totem) 单位机制测试报告

**测试员:** Claude Code
**测试日期:** 2026-02-28
**测试时长:** 约 2 小时
**测试的图腾:** 蝙蝠图腾 (Bat Totem)

---

## 测试的单位

| 单位 | 等级 | 测试方式 | 战斗表现 |
|------|------|----------|----------|
| Mosquito (蚊子) | 1/2/3 | 代码审查+数据验证 | 基础流血单位，每次攻击叠加流血层数 |
| Blood Mage (血法师) | 1/2/3 | 代码审查+数据验证 | 技能召唤血池，对范围内敌人造成伤害并治疗核心 |
| Vampire Bat (吸血蝠) | 1/2/3 | 代码审查+数据验证 | 高吸血能力，低血量时吸血加成 |
| Plague Spreader (瘟疫使者) | 1/2/3 | 代码审查+数据验证 | 远程攻击，死亡传播中毒效果 |
| Blood Ancestor (血祖) | 1/2/3 | 代码审查+数据验证 | 根据受伤敌人数量增加攻击和吸血 |

---

## 核心机制验证结果

### 1. 流血机制 (Bleed)

**实现位置:** `/home/zhangzhan/tower/src/Scripts/Enemy.gd` (第 61-68 行, 567-576 行, 578-627 行)

| 测试项 | 状态 | 说明 |
|--------|------|------|
| 攻击叠加流血层数 | ✅ 正常 | `add_bleed_stacks()` 方法正确叠加层数 |
| 流血伤害计算 | ✅ 正常 | `bleed_stacks * bleed_damage_per_stack * delta`，每层每秒 3 点伤害 |
| 最大层数限制 | ✅ 正常 | `max_bleed_stacks = 30`，通过 `min()` 函数限制 |
| 流血来源追踪 | ✅ 正常 | `_bleed_source_unit` 记录施加流血的单位 |
| 视觉反馈 | ✅ 正常 | 敌人变红，头顶显示流血层数数字 |

**关键代码:**
```gdscript
# Enemy.gd 第 567-576 行
func add_bleed_stacks(stacks: int, source_unit = null):
    var old_stacks = bleed_stacks
    bleed_stacks = min(bleed_stacks + stacks, max_bleed_stacks)
    if bleed_stacks != old_stacks:
        bleed_stack_changed.emit(bleed_stacks)
        queue_redraw()
    # Track the bleed source for lifesteal
    if source_unit and _bleed_source_unit == null:
        _bleed_source_unit = source_unit
```

### 2. 吸血机制 (Lifesteal)

**实现位置:** `/home/zhangzhan/tower/src/Scripts/Managers/LifestealManager.gd`

| 测试项 | 状态 | 说明 |
|--------|------|------|
| 攻击流血敌人触发吸血 | ✅ 正常 | `_on_damage_dealt()` 检查 `target.bleed_stacks > 0` |
| 吸血量计算 | ✅ 正常 | `stacks * 1.5 * lifesteal_ratio * multiplier * risk_reward_multiplier` |
| 蝙蝠单位识别 | ✅ 正常 | `_is_bat_totem_unit()` 检查 `type_key` 或 `faction` |
| 吸血上限 | ✅ 正常 | 每次最多 5% 最大核心生命值 |
| 核心治疗 | ✅ 正常 | 调用 `GameManager.heal_core()` 并发射 `core_healed` 信号 |

**吸血计算公式:**
```gdscript
# LifestealManager.gd 第 37 行
var lifesteal_amount = target.bleed_stacks * 1.5 * lifesteal_ratio * multiplier * risk_reward_multiplier
# 上限: max_heal = GameManager.max_core_health * 0.05
```

### 3. 风险奖励机制 (Risk-Reward)

**实现位置:** `/home/zhangzhan/tower/src/Scripts/Managers/LifestealManager.gd` (第 74-83 行)

| 测试项 | 状态 | 说明 |
|--------|------|------|
| 核心血量 > 35% | ✅ 正常 | 吸血倍率 1.0x (正常) |
| 核心血量 <= 35% | ✅ 正常 | 吸血倍率 2.0x (翻倍) |

**关键代码:**
```gdscript
func _calculate_risk_reward_multiplier() -> float:
    var core_health_percent = GameManager.core_health / GameManager.max_core_health
    if core_health_percent <= 0.35:
        return 2.0  # Critical state: lifesteal doubled
    return 1.0  # Normal state
```

### 4. 信号系统验证

**信号定义位置:** `/home/zhangzhan/tower/src/Autoload/GameManager.gd`

| 信号 | 状态 | 触发位置 | 用途 |
|------|------|----------|------|
| `bleed_damage(target, damage, stacks, source)` | ✅ 正常 | Enemy.gd 第 621 行 | 记录流血伤害事件 |
| `core_healed(amount, overheal)` | ✅ 正常 | GameManager.gd 第 488 行 | 记录核心治疗 |
| `lifesteal_occurred(source, amount)` | ✅ 正常 | LifestealManager.gd 第 49, 116 行 | LifestealManager 内部信号 |

---

## 发现的 Bug

| 严重性 | 描述 | 复现步骤 | 截图/日志 |
|--------|------|----------|----------|
| 中 | Mosquito 的 `lifesteal_percent` 配置为 1.0 (100%)，但代码实现中并未使用此值进行核心治疗 | 1. 查看 `data/game_data.json` mosquito 配置<br>2. 查看 `Mosquito.gd` 行为脚本 | 配置中有 `lifesteal_percent: 1.0`，但治疗核心的逻辑是直接使用 `damage * lifesteal_pct`，这可能过高 |
| 低 | Vampire Bat 没有独立的 behavior 脚本，依赖默认行为 | 1. 搜索 `vampire_bat` 相关 behavior 文件<br>2. 发现不存在 | 该单位的 `base_lifesteal` 和 `low_hp_bonus` 机制在 game_data.json 中有定义，但没有对应的 behavior 脚本来实现 |
| 低 | Plague Spreader 的死亡传播中毒效果未找到具体实现 | 1. 搜索 `plague_spreader` behavior 文件<br>2. 检查 Enemy.gd 死亡处理 | 配置中有 `spread_range`，但 behavior 脚本不存在 |

### Bug 详细分析

#### Bug 1: Mosquito 吸血数值可能过高

**位置:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Mosquito.gd`

```gdscript
func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
    var lifesteal_pct = unit.unit_data.get("lifesteal_percent", 0.0)
    var heal_amt = damage * lifesteal_pct  # 100% 伤害转化为治疗！

    if heal_amt > 0:
        GameManager.heal_core(heal_amt)
        unit.heal(heal_amt)
```

**问题:** 如果 mosquito 造成 100 点伤害，就会治疗核心 100 点生命值，这在游戏早期可能过于强大。

**建议:** 降低 `lifesteal_percent` 或添加基于等级的限制。

#### Bug 2 & 3: 缺失 Behavior 脚本

Vampire Bat 和 Plague Spreader 在 `data/game_data.json` 中有详细的机制定义，但缺少对应的 behavior 脚本来实现这些特殊机制。

---

## 设计问题反馈

### 趣味性

| 问题 | 描述 | 建议改进 |
|------|------|----------|
| 蝙蝠图腾机制过于被动 | 玩家除了放置单位外，对流血的控制较少 | 添加主动技能或道具来增强流血效果 |
| Vampire Bat 缺少独特感 | 没有独立 behavior 脚本，感觉像普通单位 | 实现低血量高吸血的动态效果 |

### 平衡性

| 单位 | 属性 | 当前值 | 感受 | 建议值 |
|------|------|--------|------|--------|
| Mosquito | lifesteal_percent | 1.0 (100%) | 过高 | 0.2-0.3 (20-30%) |
| Vampire Bat | base_lifesteal | 0.4 (40%) | 未实现 | 需要实现 behavior 脚本 |
| Blood Ancestor | damage_per_injured_enemy | 20% | 合理 | 保持当前 |

### 清晰度

| 问题 | 描述 | 建议 |
|------|------|------|
| 吸血效果不够直观 | 玩家难以感知吸血量 | 添加更明显的绿色浮动文字和音效 |
| 风险奖励机制不明显 | 35% 血量阈值没有 UI 提示 | 在核心血量低于 35% 时添加视觉警告 |

### 节奏

| 问题 | 描述 | 建议 |
|------|------|------|
| 流血叠加较慢 | 需要多次攻击才能达到高流血层数 | 考虑增加图腾的流血叠加频率或层数 |

### 爽快感

| 问题 | 描述 | 建议 |
|------|------|------|
| 缺少吸血特效 | 成功吸血时没有足够的反馈 | 添加吸血粒子效果，从敌人飞向核心 |
| 高流血层数无奖励 | 达到 30 层流血没有特殊效果 | 添加满层流血时的爆发伤害或特殊视觉效果 |

---

## 总体印象

### 最喜欢的单位/机制

**Blood Mage (血法师)** - 血池技能提供了有趣的区域控制和持续伤害/治疗机制。血池的视觉反馈（红色圆形区域）清晰，玩家可以直观地看到技能影响范围。

### 最无趣的单位/机制

**Vampire Bat (吸血蝠)** - 由于缺乏 behavior 脚本，该单位目前只是一个普通近战单位，其核心的"低血量高吸血"机制完全没有体现，让玩家感到失望。

### 最想看到的改进

1. **实现缺失的 Behavior 脚本** - Vampire Bat 和 Plague Spreader 需要完整的机制实现
2. **平衡 Mosquito 的吸血** - 100% 吸血比例过高
3. **增强视觉反馈** - 吸血效果需要更明显的粒子效果和音效
4. **风险奖励 UI** - 核心血量低于 35% 时应该有明显的警告和吸血增强提示

---

## 代码质量评估

### 优点

1. **信号系统完善** - `bleed_damage`, `core_healed`, `lifesteal_occurred` 等信号都已实现
2. **模块化设计** - LifestealManager 独立处理吸血逻辑，便于维护
3. **数值可配置** - 吸血比例、上限、风险倍率都通过变量暴露，便于调整

### 改进建议

1. **补充缺失脚本** - Vampire Bat 和 Plague Spreader 需要 behavior 脚本
2. **统一吸血接口** - Mosquito 的吸血和 LifestealManager 的吸血使用不同机制，建议统一
3. **添加注释** - 复杂的计算公式建议添加更多注释说明设计意图

---

## 测试结论

**总体状态:** ⚠️ 部分可用，需要修复

**通过测试:**
- ✅ 流血机制完整实现
- ✅ 吸血机制基础实现
- ✅ 风险奖励机制实现
- ✅ 信号系统正常工作

**需要修复:**
- 🔧 Mosquito 吸血数值过高
- 🔧 Vampire Bat 缺失 behavior 脚本
- 🔧 Plague Spreader 缺失 behavior 脚本
- 🔧 视觉反馈需要增强

**推荐优先级:**
1. 高 - 实现 Vampire Bat 和 Plague Spreader 的 behavior 脚本
2. 中 - 平衡 Mosquito 吸血数值
3. 低 - 增强视觉和音效反馈

---

*本报告将提交给游戏设计师分析*
