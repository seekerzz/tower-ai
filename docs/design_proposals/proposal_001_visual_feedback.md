# 设计提案 001: 视觉反馈增强方案

**提案日期:** 2026-02-28
**提案类型:** 视觉/UI改进
**优先级:** 高
**状态:** 待评审

---

## 1. 问题陈述

根据测试报告分析，当前游戏在视觉反馈方面存在以下问题：

### 1.1 毒液层数显示不清晰
- **来源:** report_viper_totem_test.md (设计问题反馈 - 清晰度)
- **问题:** 敌人身上的毒液层数不够明显，玩家难以判断斩杀时机
- **影响:** 毒蛇图腾核心玩法体验受损

### 1.2 斩杀预警缺失
- **来源:** report_viper_totem_test.md (设计问题反馈 - 爽快感)
- **问题:** 箭毒蛙斩杀条件不够清晰，敌人HP低于斩杀线时无视觉提示
- **影响:** 玩家无法享受精准斩杀的爽快感

### 1.3 风险奖励机制无UI提示
- **来源:** report_bat_totem_test.md (设计问题反馈 - 清晰度)
- **问题:** 蝙蝠图腾35%血量阈值没有UI提示，吸血增强效果不明显
- **影响:** 玩家无法感知危险状态下的奖励机制

### 1.4 吸血效果反馈不足
- **来源:** report_bat_totem_test.md (设计问题反馈 - 爽快感)
- **问题:** 成功吸血时没有足够的粒子效果和音效反馈
- **影响:** 蝙蝠图腾核心机制缺乏成就感

### 1.5 冰冻层数不可见
- **来源:** report_butterfly_totem_test.md (设计问题反馈 - 清晰度)
- **问题:** 冰晶蝶冰冻层数无法直观查看
- **影响:** 玩家难以规划冰冻触发时机

---

## 2. 解决方案

### 2.1 毒液层数数字显示

**实现方案:**
- 在敌人头顶添加层数指示器
- 层数变化时添加小型粒子爆发效果
- 达到最大层数时触发特殊视觉提示

**具体规格:**
```
位置: 敌人头顶上方20像素
字体: 16px, 粗体
颜色渐变:
  - 1-10层: 绿色 (#2ecc71)
  - 11-20层: 黄绿色 (#f1c40f)
  - 21-30层: 橙色 (#e67e22)
  - 30+层: 红色 (#e74c3c)

动画:
  - 层数增加: 数字弹跳 + 绿色粒子
  - 达到最大: 金色光环闪烁
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Effects/PoisonEffect.gd`
- `/home/zhangzhan/tower/src/Scripts/Enemy.gd`

---

### 2.2 斩杀预警提示

**实现方案:**
- 当敌人HP低于斩杀线时，敌人轮廓高亮显示
- 添加"斩杀就绪"图标在敌人头顶
- 斩杀触发时播放特殊动画和音效

**具体规格:**
```
斩杀线计算:
  - 箭毒蛙: debuff_stacks * 3 (当前值)
  - 豺狼: 25% HP

视觉提示:
  - 敌人边框: 红色脉冲发光
  - 图标: ⚔️ 或 💀 悬浮显示
  - 颜色: 深红色 (#c0392b)

斩杀触发效果:
  - 敌人溶解动画
  - 爆炸粒子效果
  - "斩杀!" 浮动文字
  - 屏幕轻微震动
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/ArrowFrog.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Wolf/UnitHyena.gd`

---

### 2.3 风险奖励UI警告

**实现方案:**
- 核心血量低于35%时，屏幕边缘添加红色警告边框
- 显示"危险状态 - 吸血翻倍"提示
- 吸血数值显示为金色并放大

**具体规格:**
```
触发条件: 核心血量 <= 35%

UI元素:
  - 屏幕边框: 红色脉冲发光 (2秒周期)
  - 警告文字: "⚠️ 危险状态 - 吸血效果翻倍"
  - 位置: 屏幕顶部中央

吸血反馈增强:
  - 数值颜色: 金色 (#f1c40f)
  - 字体大小: 24px (正常18px)
  - 添加"暴击治疗!"文字提示

音效:
  - 进入危险状态: 低沉警报声
  - 吸血触发: 增强版吸血音效
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Managers/LifestealManager.gd`
- `/home/zhangzhan/tower/src/Autoload/GameManager.gd`

---

### 2.4 吸血粒子效果

**实现方案:**
- 吸血时从敌人身上飞出红色粒子
- 粒子飞向核心，形成视觉连接
- 根据吸血量调整粒子数量和大小

**具体规格:**
```
粒子系统:
  - 起始位置: 被攻击敌人中心
  - 目标位置: 核心位置
  - 粒子颜色: 深红 → 鲜红渐变
  - 粒子形状: 心形或血滴

粒子数量计算:
  - 基础: 5个粒子
  - 每10点吸血: +2个粒子
  - 最大: 20个粒子

飞行轨迹:
  - 速度: 200像素/秒
  - 曲线: 轻微弧线
  - 持续时间: 0.5秒

命中效果:
  - 核心闪烁绿色
  - 治疗数字弹出
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Managers/LifestealManager.gd`

---

### 2.5 满层爆发效果

**实现方案:**
- 毒液/流血达到最大层数时触发爆发效果
- 冰冻满层时添加冰晶碎裂效果
- 满层状态添加特殊光环

**具体规格:**
```
毒液满层 (30层 - 调整后):
  - 敌人身上绿色光环
  - 持续粒子喷发
  - 死亡时毒液爆炸范围+50%

流血满层 (30层):
  - 敌人身上红色光环
  - 血滴粒子持续掉落
  - 伤害数字放大显示

冰冻满层触发:
  - 冻结瞬间: 冰晶扩散效果
  - 冻结期间: 冰块包裹外观
  - 解冻时: 碎裂飞溅效果
  - 音效: 玻璃碎裂声
```

**相关文件:**
- `/home/zhangzhan/tower/src/Scripts/Effects/PoisonEffect.gd`
- `/home/zhangzhan/tower/src/Scripts/Effects/SlowEffect.gd`
- `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/IceButterfly.gd`

---

## 3. 实现建议

### 3.1 技术实现路径

| 功能 | 实现文件 | 修改类型 | 预估工时 |
|------|----------|----------|----------|
| 毒液层数显示 | Enemy.gd + 新UI组件 | 新增 | 4h |
| 斩杀预警 | ArrowFrog.gd, Hyena.gd | 修改 | 3h |
| 风险奖励UI | LifestealManager.gd + HUD | 修改 | 4h |
| 吸血粒子 | LifestealManager.gd | 新增 | 3h |
| 满层爆发 | 各Effect.gd | 修改 | 5h |

### 3.2 性能考虑

- 粒子效果使用对象池管理，避免频繁创建销毁
- UI更新使用信号驱动，避免每帧检查
- 复杂视觉效果提供选项开关

### 3.3 配置化设计

```gdscript
# 建议在game_data.json中添加视觉配置
"visual_settings": {
    "poison_stack_indicator": true,
    "execute_warning": true,
    "risk_reward_warning": true,
    "lifesteal_particles": true,
    "max_stack_effects": true
}
```

---

## 4. 优先级

| 功能 | 优先级 | 理由 |
|------|--------|------|
| 毒液层数显示 | P0 | 核心玩法必需，测试报告多次提及 |
| 斩杀预警 | P0 | 影响爽快感，箭毒蛙核心机制 |
| 风险奖励UI | P1 | 增强机制清晰度 |
| 吸血粒子 | P1 | 增强爽快感 |
| 满层爆发 | P2 | 锦上添花效果 |

---

## 5. 验收标准

- [ ] 毒液层数在敌人头顶清晰显示，颜色随层数变化
- [ ] 可斩杀敌人有红色边框高亮和斩杀图标
- [ ] 核心血量<35%时屏幕有红色警告边框
- [ ] 吸血时有红色粒子从敌人飞向核心
- [ ] 毒液/流血达到最大层数有特殊光环效果
- [ ] 冰冻触发和结束时播放碎裂效果
- [ ] 所有效果在低端设备上保持30fps以上

---

## 6. 参考文档

- `/home/zhangzhan/tower/docs/player_reports/report_viper_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_bat_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_butterfly_totem_test.md`
- `/home/zhangzhan/tower/docs/player_reports/report_wolf_totem_test.md`

---

*提案基于测试报告数据生成*
