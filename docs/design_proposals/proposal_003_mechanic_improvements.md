# 设计提案 003: 机制改进方案

**提案日期:** 2026-02-28
**提案类型:** 机制增强
**优先级:** 中
**状态:** 待评审

---

## 1. 问题陈述

根据测试报告分析，当前游戏机制存在以下改进空间：

### 1.1 毒液传播视觉特效缺失
- **来源:** report_viper_totem_test.md (设计问题反馈 - 趣味性)
- **问题:** 毒液传播时只有"传播!"文字，缺少视觉特效
- **影响:** 瘟疫使者核心机制缺乏视觉冲击力

### 1.2 斩杀爆炸动画缺失
- **来源:** report_viper_totem_test.md (设计问题反馈 - 爽快感)
- **问题:** 箭毒蛙斩杀缺少爆炸动画和特殊音效
- **影响:** 斩杀机制缺乏成就感

### 1.3 暴击回响视觉不足
- **来源:** report_eagle_totem_test.md (机制验证)
- **问题:** 暴击回响机制只有数值反馈，缺少视觉特效
- **影响:** 鹰图腾核心机制不够炫酷

### 1.4 石化碎裂震动缺失
- **来源:** report_viper_totem_test.md (设计问题反馈 - 爽快感)
- **问题:** 美杜莎石化破碎缺少震动效果
- **影响:** 控制+爆发机制缺乏冲击力

### 1.5 吸血粒子效果缺失
- **来源:** report_bat_totem_test.md (设计问题反馈 - 爽快感)
- **问题:** 成功吸血时没有粒子效果
- **影响:** 蝙蝠图腾核心机制反馈不足

### 1.6 陷阱触发反馈不足
- **来源:** report_traps_special_test.md (建议)
- **问题:** 陷阱触发时缺少明显的视觉和音效反馈
- **影响:** 陷阱流派存在感低

---

## 2. 解决方案

### 2.1 毒液传播视觉特效

**实现方案:**
- 毒液传播时添加绿色粒子飞溅效果
- 添加毒液连线动画，显示传播路径
- 受感染敌人身上有毒素蔓延动画

**具体规格:**
```
粒子效果:
  - 类型: 绿色毒液飞溅
  - 数量: 10-15个粒子
  - 颜色: #2ecc71 → #27ae60 渐变
  - 大小: 3-8像素
  - 速度: 100-200像素/秒
  - 生命周期: 0.5-1.0秒

连线动画:
  - 从死亡敌人到感染敌人
  - 颜色: 绿色半透明
  - 持续时间: 0.3秒
  - 宽度: 2像素

感染标记:
  - 新感染敌人显示"感染!"文字
  - 身上有毒液滴落动画
  - 持续0.5秒
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/PlagueSpreader.gd`
- 需创建: `res://src/Scenes/Effects/PoisonSpreadEffect.tscn`

**信号:**
```gdscript
GameManager.poison_spread.emit(source_enemy, target_enemy, stacks)
```

---

### 2.2 斩杀爆炸动画

**实现方案:**
- 斩杀触发时播放爆炸动画
- 添加屏幕震动效果
- 显示"斩杀!"大字提示

**具体规格:**
```
爆炸动画:
  - 类型: 粒子爆炸
  - 颜色: 深红 (#c0392b) + 金色 (#f1c40f)
  - 粒子数: 30-50个
  - 扩散速度: 300-500像素/秒
  - 持续时间: 0.8秒

屏幕震动:
  - 强度: 5像素
  - 持续时间: 0.2秒
  - 衰减: 线性衰减

文字提示:
  - 内容: "斩杀!" / "EXECUTE!"
  - 字体: 32px, 粗体
  - 颜色: 金色 (#f1c40f)
  - 动画: 放大弹出 + 淡出

音效:
  - 类型: 重击 + 爆炸混合
  - 音量: 1.2倍 (比普通音效更响)
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/ArrowFrog.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Wolf/UnitHyena.gd`
- 需创建: `res://src/Scenes/Effects/ExecuteEffect.tscn`

**信号:**
```gdscript
GameManager.execute_triggered.emit(unit, enemy, damage)
```

---

### 2.3 暴击回响视觉

**实现方案:**
- 暴击时添加闪电/残影效果
- 回响伤害显示特殊标识
- 添加"回响!"文字提示

**具体规格:**
```
暴击效果:
  - 投射物: 金色光芒
  - 命中: 闪电状粒子
  - 颜色: 金色 (#ffd700)

回响效果:
  - 延迟: 0.1秒后触发
  - 残影: 攻击残影动画
  - 连线: 金色闪电连线
  - 伤害数字: 金色 + "回响"标签

文字提示:
  - 内容: "回响!" / "ECHO!"
  - 位置: 伤害数字上方
  - 颜色: 金色
  - 字体: 14px

音效:
  - 暴击: 金属撞击声
  - 回响: 回声效果
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/CoreMechanics/MechanicEagleTotem.gd`
- `/home/zhangzhan/tower/src/Scripts/Projectile.gd`
- 需创建: `res://src/Scenes/Effects/CritEchoEffect.tscn`

**信号:**
```gdscript
GameManager.echo_triggered.emit(source_unit, target, original_damage, echo_damage)
```

---

### 2.4 石化碎裂震动

**实现方案:**
- 石化敌人死亡时播放碎裂动画
- 添加屏幕震动
- 碎裂石块飞溅效果

**具体规格:**
```
碎裂动画:
  - 敌人模型碎裂成石块
  - 石块数量: 8-12块
  - 石块大小: 随机 10-20像素
  - 颜色: 灰色 (#7f8c8d)
  - 重力: 正常重力下落

飞溅效果:
  - 速度: 200-400像素/秒
  - 方向: 360度随机
  - 旋转: 随机旋转

屏幕震动:
  - 强度: 8像素 (比斩杀更强)
  - 持续时间: 0.3秒
  - 原因: 石化碎裂是更强的效果

AOE伤害显示:
  - 显示伤害范围圈
  - 范围内敌人受到伤害数字
  - "碎裂!" 文字提示

音效:
  - 类型: 石块碎裂声
  - 音量: 1.0
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Effects/PetrifiedStatus.gd`
- `/home/zhangzhan/tower/src/Scripts/Enemy.gd`
- 需创建: `res://src/Scenes/Effects/PetrifiedShatterEffect.tscn`

**信号:**
```gdscript
GameManager.petrified_shatter.emit(source_unit, position, damage_percent, affected_enemies)
```

---

### 2.5 吸血粒子效果

**实现方案:**
- 吸血时生成血滴粒子
- 粒子从敌人飞向核心
- 根据吸血量调整效果强度

**具体规格:**
```
粒子系统:
  - 形状: 心形或血滴
  - 颜色: 深红 (#c0392b) → 鲜红 (#e74c3c)
  - 大小: 5-10像素
  - 发光: 微弱红色光芒

飞行轨迹:
  - 起始: 被攻击敌人中心
  - 目标: 核心位置
  - 速度: 150-250像素/秒
  - 曲线: 轻微弧线向上

数量计算:
  - 基础: 3个粒子
  - 每5点吸血: +1个粒子
  - 最大: 15个粒子

命中效果:
  - 核心闪烁绿色
  - 治疗数字放大弹出
  - "+XX HP" 绿色文字

音效:
  - 类型: 吸血/治疗音效
  - 音量: 0.8
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Managers/LifestealManager.gd`
- 需创建: `res://src/Scenes/Effects/LifestealEffect.tscn`

**信号:**
```gdscript
GameManager.lifesteal_visual.emit(source_unit, target, amount)
```

---

### 2.6 陷阱触发特效

**实现方案:**
- 陷阱触发时添加明显的视觉反馈
- 不同类型陷阱有不同特效
- 添加陷阱范围指示器

**具体规格:**
```
粘液陷阱 (Slow):
  - 触发: 绿色粘液飞溅
  - 持续: 粘液附着效果
  - 音效: 粘滞声

毒雾陷阱 (Poison):
  - 触发: 绿色毒雾爆发
  - 持续: 毒雾缭绕
  - 音效: 嘶嘶声

荆棘陷阱 (Reflect):
  - 触发: 尖刺突出动画
  - 伤害: 红色闪光
  - 音效: 金属撞击声

雪球陷阱 (Freeze):
  - 触发: 冰霜扩散
  - 爆炸: 雪花飞溅
  - 音效: 冰冻爆裂声

范围指示器:
  - 放置时显示范围圈
  - 颜色: 半透明对应陷阱色
  - 持续时间: 2秒后淡出
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Barricade.gd`
- `/home/zhangzhan/tower/src/Scripts/Enemy.gd`
- 需创建: `res://src/Scenes/Effects/TrapTriggerEffect.tscn`

**信号:**
```gdscript
GameManager.trap_triggered_visual.emit(trap_type, position, affected_enemies)
```

---

## 3. 实现建议

### 3.1 技术实现路径

| 功能 | 实现文件 | 依赖资源 | 预估工时 |
|------|----------|----------|----------|
| 毒液传播特效 | PlagueSpreader.gd | PoisonSpreadEffect.tscn | 6h |
| 斩杀爆炸 | ArrowFrog.gd, Hyena.gd | ExecuteEffect.tscn | 5h |
| 暴击回响 | MechanicEagleTotem.gd | CritEchoEffect.tscn | 5h |
| 石化碎裂 | PetrifiedStatus.gd | PetrifiedShatterEffect.tscn | 6h |
| 吸血粒子 | LifestealManager.gd | LifestealEffect.tscn | 4h |
| 陷阱特效 | Barricade.gd | TrapTriggerEffect.tscn | 6h |

### 3.2 资源需求

**需要创建的特效场景:**
1. `res://src/Scenes/Effects/PoisonSpreadEffect.tscn`
2. `res://src/Scenes/Effects/ExecuteEffect.tscn`
3. `res://src/Scenes/Effects/CritEchoEffect.tscn`
4. `res://src/Scenes/Effects/PetrifiedShatterEffect.tscn`
5. `res://src/Scenes/Effects/LifestealEffect.tscn`
6. `res://src/Scenes/Effects/TrapTriggerEffect.tscn`

**需要添加的音效:**
1. `res://assets/audio/sfx/execute_explosion.wav`
2. `res://assets/audio/sfx/petrified_shatter.wav`
3. `res://assets/audio/sfx/crit_echo.wav`
4. `res://assets/audio/sfx/lifesteal.wav`
5. `res://assets/audio/sfx/trap_trigger_*.wav` (4种)

### 3.3 性能优化

- 使用对象池管理粒子效果
- 限制同屏特效数量 (最大20个)
- 提供"低特效模式"选项
- 远距离特效简化或禁用

---

## 4. 优先级

| 功能 | 优先级 | 理由 |
|------|--------|------|
| 斩杀爆炸 | P0 | 核心爽快感机制，测试报告多次强调 |
| 吸血粒子 | P0 | 蝙蝠图腾核心机制，急需视觉反馈 |
| 石化碎裂 | P1 | 美杜莎核心机制，增强控制流派 |
| 暴击回响 | P1 | 鹰图腾特色，提升炫酷感 |
| 毒液传播 | P2 | 锦上添花，增强瘟疫使者 |
| 陷阱特效 | P2 | 提升陷阱流派存在感 |

---

## 5. 验收标准

- [ ] 毒液传播时有绿色粒子飞溅和连线动画
- [ ] 斩杀触发时播放爆炸动画和屏幕震动
- [ ] 暴击回响有金色残影和"回响!"文字
- [ ] 石化敌人死亡时播放碎裂动画和震动
- [ ] 吸血时有血滴粒子从敌人飞向核心
- [ ] 陷阱触发时有对应的视觉特效和音效
- [ ] 所有特效在低端设备保持30fps
- [ ] 提供选项可关闭或简化特效

---

## 6. 参考文档

- `/home/zhangzhan/tower/docs/player_reports/report_viper_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_bat_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_eagle_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_traps_special_test.md`

---

*提案基于测试报告数据生成*
