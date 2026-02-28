# 设计提案 002: 数值平衡调整方案

**提案日期:** 2026-02-28
**提案类型:** 数值平衡
**优先级:** 高
**状态:** 待评审

---

## 1. 问题陈述

根据测试报告分析，当前游戏存在以下数值平衡问题：

### 1.1 中毒伤害过低
- **来源:** report_viper_totem_test.md (平衡性评估)
- **问题:** 中毒基础伤害10/秒偏低，最大层数50层过高
- **影响:** 毒液流派前期无力，后期堆叠困难

### 1.2 吸血数值过高
- **来源:** report_bat_totem_test.md (Bug分析)
- **问题:** Mosquito吸血比例100%，造成100点伤害治疗核心100点
- **影响:** 游戏早期过于强大，破坏平衡

### 1.3 魅惑几率偏低
- **来源:** report_wolf_totem_test.md (平衡性评估)
- **问题:** Fox魅惑几率15%/25%，触发频率低
- **影响:** 玩家难以感知魅惑机制的存在

### 1.4 冰冻触发偏慢
- **来源:** report_butterfly_totem_test.md (平衡性评估)
- **问题:** 需要3次攻击触发冰冻，快节奏战斗中偏慢
- **影响:** 冰晶蝶实用性下降

### 1.5 斩杀阈值过低
- **来源:** report_viper_totem_test.md (平衡性评估)
- **问题:** 箭毒蛙斩杀阈值debuff_stacks * 3过低
- **影响:** 斩杀机制难以触发

---

## 2. 解决方案

### 2.1 中毒数值调整

**当前数值:**
```
基础伤害: 10/秒
最大层数: 50层
满层伤害: 500/秒
```

**建议数值:**
```
基础伤害: 15/秒 (提升50%)
最大层数: 25层 (降低50%)
满层伤害: 375/秒

调整理由:
- 提升前期伤害感知
- 降低堆叠难度，更快达到满层
- 满层伤害略微降低，避免过于强力
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Effects/PoisonEffect.gd`
- `/home/zhangzhan/tower/data/game_data.json`

---

### 2.2 Mosquito吸血调整

**当前数值:**
```json
{
    "mosquito": {
        "lifesteal_percent": 1.0
    }
}
```

**建议数值:**
```json
{
    "mosquito": {
        "lifesteal_percent": 0.25,
        "lifesteal_percent_lv2": 0.35,
        "lifesteal_percent_lv3": 0.50
    }
}
```

**调整理由:**
- 100%吸血过于强大，破坏早期游戏平衡
- 随等级成长提供进阶感
- 与其他吸血单位保持一致性

**相关文件:**
- `/home/zhangzhan/tower/data/game_data.json`
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Mosquito.gd`

---

### 2.3 Fox魅惑几率提升

**当前数值:**
```
Lv1: 15%
Lv2: 25%
Lv3: 可同时魅惑2个敌人
```

**建议数值:**
```
Lv1: 20% (+5%)
Lv2: 30% (+5%)
Lv3: 可同时魅惑2个敌人，魅惑持续时间+1秒
```

**调整理由:**
- 提升触发频率，让玩家更频繁感知机制
- Lv3增加持续时间，提供额外成长感

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Wolf/UnitFox.gd`
- `/home/zhangzhan/tower/data/game_data.json`

---

### 2.4 冰冻触发优化

**当前数值:**
```
冰冻阈值: 3层
冻结时间: 1.0/1.5秒
```

**建议数值:**
```
冰冻阈值: 2层 (降低)
冻结时间: 1.5/2.0秒 (提升)
```

**调整理由:**
- 降低触发门槛，适应快节奏战斗
- 提升冻结持续时间，增加控制价值

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/IceButterfly.gd`

---

### 2.5 斩杀阈值提升

**当前数值:**
```
斩杀阈值: debuff_stacks * 3
```

**建议数值:**
```
斩杀阈值: debuff_stacks * 5

Lv3额外效果: 斩杀时触发毒液爆炸，传播50%层数给周围敌人
```

**调整理由:**
- 提升斩杀成功率
- Lv3增加AOE效果，增强爽快感

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/ArrowFrog.gd`

---

### 2.6 Dog溅射触发条件优化

**当前数值:**
```
Lv3溅射触发: 核心HP < 25%
```

**建议数值:**
```
Lv3溅射触发: 核心HP < 50%
```

**调整理由:**
- 25%阈值过于危险，难以触发
- 50%阈值提供更多战术选择空间

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Wolf/UnitDog.gd`

---

### 2.7 毒蛇图腾核心伤害提升

**当前数值:**
```
毒液伤害: 20点
攻击间隔: 5秒
```

**建议数值:**
```
毒液伤害: 35点 (提升75%)
攻击间隔: 5秒 (保持不变)
```

**调整理由:**
- 核心伤害偏低，存在感不足
- 提升后与其他图腾核心伤害持平

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/CoreMechanics/MechanicViperTotem.gd`

---

## 3. 数值调整汇总表

| 单位/机制 | 属性 | 当前值 | 建议值 | 变化 | 优先级 |
|-----------|------|--------|--------|------|--------|
| 中毒效果 | 基础伤害 | 10/秒 | 15/秒 | +50% | P0 |
| 中毒效果 | 最大层数 | 50层 | 25层 | -50% | P0 |
| Mosquito | 吸血比例 | 100% | 25%/35%/50% | -75% | P0 |
| Fox | 魅惑几率 | 15%/25% | 20%/30% | +5% | P1 |
| Ice Butterfly | 冰冻阈值 | 3层 | 2层 | -33% | P1 |
| Ice Butterfly | 冻结时间 | 1.0/1.5秒 | 1.5/2.0秒 | +33% | P1 |
| ArrowFrog | 斩杀阈值 | 层数*3 | 层数*5 | +67% | P1 |
| Dog | 溅射触发 | HP<25% | HP<50% | +100% | P2 |
| Viper Totem | 核心伤害 | 20点 | 35点 | +75% | P2 |
| 流血效果 | 最大层数 | 30层 | 25层 | -17% | P2 |

---

## 4. 实现建议

### 4.1 实现路径

| 调整项 | 实现方式 | 风险等级 |
|--------|----------|----------|
| 中毒数值 | 修改PoisonEffect.gd常量 | 低 |
| Mosquito吸血 | 修改game_data.json | 低 |
| Fox魅惑 | 修改UnitFox.gd和game_data.json | 低 |
| 冰冻数值 | 修改IceButterfly.gd | 低 |
| 斩杀阈值 | 修改ArrowFrog.gd | 中 |
| Dog溅射 | 修改UnitDog.gd | 低 |
| 核心伤害 | 修改MechanicViperTotem.gd | 低 |

### 4.2 测试计划

1. **单元测试:** 单独验证每个数值调整
2. **组合测试:** 验证调整后的单位组合效果
3. **平衡测试:** 对比调整前后的通关数据
4. **玩家测试:** 收集玩家反馈

### 4.3 回滚方案

所有数值调整通过配置文件实现，保留原始数值作为注释，便于快速回滚。

---

## 5. 预期效果

### 5.1 毒蛇图腾
- 前期伤害提升，玩家更快感知毒液效果
- 满层难度降低，斩杀机制更易触发
- 整体流派强度提升约20%

### 5.2 蝙蝠图腾
- Mosquito早期统治力下降
- 其他蝙蝠单位价值提升
- 吸血机制整体更平衡

### 5.3 蝴蝶图腾
- 冰冻控制更可靠
- 冰晶蝶成为实用的控制单位
- 控制流派可行性提升

### 5.4 狼图腾
- Fox魅惑成为可依赖的控制手段
- Dog溅射在更多场景可用
- 整体流派更灵活

---

## 6. 验收标准

- [ ] 中毒伤害15/秒，最大层数25层
- [ ] Mosquito吸血比例随等级25%/35%/50%
- [ ] Fox魅惑几率20%/30%
- [ ] 冰冻2层触发，冻结1.5/2.0秒
- [ ] 箭毒蛙斩杀阈值层数*5
- [ ] Dog溅射在核心HP<50%时触发
- [ ] 毒蛇图腾核心伤害35点
- [ ] 所有调整后数值通过平衡测试

---

## 7. 参考文档

- `/home/zhangzhan/tower/docs/player_reports/report_viper_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_bat_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_wolf_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_butterfly_totem_test.md`
- `/home/zhangzhan/tower/data/game_data.json`

---

*提案基于测试报告数据生成*
