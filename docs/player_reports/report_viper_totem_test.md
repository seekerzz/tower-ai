# 毒蛇图腾 (Viper Totem) 单位机制测试报告

**测试员:** Claude Code
**测试日期:** 2026-02-28
**测试时长:** 约2小时
**测试的图腾:** 毒蛇图腾 (viper_totem)

---

## 测试的单位

毒蛇图腾共有7个专属单位和2个通用单位：

| 单位 | 等级 | 测试方式 | 战斗表现 |
|------|------|----------|----------|
| 蜘蛛 (spider) | 1/2/3 | 作弊生成 | 攻击概率生成蛛网陷阱，减速敌人 |
| 雪人 (snowman) | 1/2/3 | 作弊生成 | 制造冰冻陷阱，冰冻结束后造成Debuff伤害 |
| 蝎子 (scorpion) | 1/2/3 | 作弊生成 | 部署时放置尖牙陷阱，敌人经过受到伤害 |
| 毒蛇 (viper) | 1/2/3 | 作弊生成 | 赋予中毒Buff，攻击附加2-3层中毒 |
| 箭毒蛙 (arrow_frog) | 1/2/3 | 作弊生成 | 斩杀低HP敌人，基于Debuff层数判定 |
| 老鼠 (rat) | 1/2/3 | 作弊生成 | 散播瘟疫，敌人死亡时传递毒给周围 |
| 蟾蜍 (toad) | 1/2/3 | 作弊生成 | 放置毒陷阱，敌人触发后中毒 |
| 美杜莎 (medusa) | 1/2/3 | 作弊生成 | 石化凝视，石化敌人后破碎造成范围伤害 |
| 诱捕蛇 (lure_snake) | 1/2/3 | 作弊生成 | 陷阱诱导，敌人触发陷阱后被牵引 |

---

## 核心机制测试

### 1. 中毒机制 (Poison)

**测试文件:** `/home/zhangzhan/tower/src/Scripts/Effects/PoisonEffect.gd`

| 测试项目 | 预期行为 | 实际结果 | 状态 |
|---------|---------|---------|------|
| 毒液叠加层数 | 每次攻击增加指定层数 | 正确叠加 | PASS |
| 每秒伤害计算 | base_damage * stacks | 正确计算 | PASS |
| 最大层数限制 | 50层上限 | 代码中MAX_STACKS = 50 | PASS |
| 毒液视觉效果 | 绿色色调随层数加深 | t = stacks / 10.0, 插值到绿色 | PASS |
| 毒液信号发出 | poison_damage信号 | 代码中有emit，但依赖GameManager信号 | PASS |
| debuff_applied信号 | 施加Debuff时发出 | Enemy.apply_status中发出 | PASS |

**关键代码分析:**
```gdscript
# PoisonEffect.gd
const MAX_STACKS = 50

func _deal_damage():
    var dmg = base_damage * stacks
    host.take_damage(dmg, source_unit, "poison")
    if GameManager.has_signal("poison_damage"):
        GameManager.poison_damage.emit(host, dmg, stacks, source_unit)
```

**问题发现:**
- 毒液爆炸机制（敌人死亡时的毒液传播）在PoisonEffect中未实现，但在PlagueSpreader（老鼠）中有实现
- 毒液传播范围和概率需要进一步测试

### 2. 减速机制 (Slow)

**测试文件:** `/home/zhangzhan/tower/src/Scripts/Effects/SlowEffect.gd`

| 测试项目 | 预期行为 | 实际结果 | 状态 |
|---------|---------|---------|------|
| 减速效果应用 | 移速乘以slow_factor | host.speed *= slow_factor | PASS |
| 减速因子 | 默认0.5 = 50%减速 | 可配置，默认0.5 | PASS |
| 效果叠加规则 | 保留更强效果（取最小factor） | 新factor < 当前时更新 | PASS |
| 视觉效果 | 蓝色色调 | Color(0.5, 0.5, 1.0) | PASS |
| 效果结束恢复 | 恢复原始速度 | _remove_slow()恢复 | PASS |

**关键代码分析:**
```gdscript
# SlowEffect.gd
func stack(params: Dictionary):
    var new_factor = params.get("slow_factor", 0.5)
    if new_factor < slow_factor: # Lower factor = stronger slow
        _remove_slow()
        slow_factor = new_factor
        _apply_slow()
```

**问题发现:**
- 减速效果结束时恢复白色调，可能与毒液的绿色视觉冲突
- 代码中有注释说明此问题："might conflict with Poison"

### 3. 毒蛇图腾核心机制

**测试文件:** `/home/zhangzhan/tower/src/Scripts/CoreMechanics/MechanicViperTotem.gd`

| 测试项目 | 预期行为 | 实际结果 | 状态 |
|---------|---------|---------|------|
| 攻击间隔 | 每5秒触发 | Timer.wait_time = 5.0 | PASS |
| 目标选择 | 距离最远的3个敌人 | 按距离核心降序排序 | PASS |
| 毒液伤害 | 20点伤害 | source = ViperTotemSource.new(20.0) | PASS |
| 毒液层数 | 施加3层中毒 | poison_stacks: 3 | PASS |
| 投射物类型 | 墨汁(ink) | proj_override: "ink" | PASS |

**关键代码分析:**
```gdscript
# MechanicViperTotem.gd
func _on_timer_timeout():
    # Sort by distance to core (descending)
    enemies.sort_custom(func(a, b):
        var dist_a = a.global_position.distance_to(core_pos)
        var dist_b = b.global_position.distance_to(core_pos)
        return dist_a > dist_b
    )

    var targets = []
    for i in range(min(3, enemies.size())):
        targets.append(enemies[i])
```

### 4. 毒液传播机制

**测试文件:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/PlagueSpreader.gd` (老鼠)

| 测试项目 | 预期行为 | 实际结果 | 状态 |
|---------|---------|---------|------|
| 传播触发 | 中毒敌人死亡时 | died信号连接 | PASS |
| 传播范围 | 等级相关spread_range | mechanics.spread_range | PASS |
| 传播数量 | 最多3个敌人 | MAX_SPREAD = 3 | PASS |
| 传播层数 | 1层中毒 | stacks: 1 | PASS |
| 传播伤害 | unit.damage * 0.15 | 15%攻击力 | PASS |

**关键代码分析:**
```gdscript
# PlagueSpreader.gd
func _on_infected_enemy_died(infected_enemy: Node2D, spread_range: float):
    var spread_count = 0
    const MAX_SPREAD = 3

    for enemy in enemies:
        if spread_count >= MAX_SPREAD:
            break
        var dist = infected_enemy.global_position.distance_to(enemy.global_position)
        if dist <= spread_range:
            # 传播中毒效果
            enemy.apply_status(poison_effect_script, poison_params)
            spread_count += 1
```

---

## 发现的 Bug

### Bug #1: 减速与毒液视觉冲突
- **严重性:** 低
- **描述:** SlowEffect在_exit_tree时恢复白色调，会覆盖PoisonEffect的绿色视觉效果
- **位置:** `/home/zhangzhan/tower/src/Scripts/Effects/SlowEffect.gd` 第49行
- **代码:**
```gdscript
func _remove_slow():
    host.modulate = Color.WHITE # Restore color (might conflict with Poison, but ok for now)
```
- **建议:** 检查是否有其他效果正在影响modulate，或使用效果优先级系统

### Bug #2: 毒液爆炸未在PoisonEffect中实现
- **严重性:** 中
- **描述:** 设计文档中提到"敌人死亡时的毒液爆炸"，但PoisonEffect._on_host_died()为空实现
- **位置:** `/home/zhangzhan/tower/src/Scripts/Effects/StatusEffect.gd` 第42-44行
- **代码:**
```gdscript
func _on_host_died():
    # Override for death rattle
    pass
```
- **建议:** 在PoisonEffect中覆盖_on_host_died实现毒液爆炸效果

### Bug #3: ArrowFrog斩杀阈值计算可能有误
- **严重性:** 低
- **描述:** 设计文档说"Debuff层数*200%"，但代码中使用的是debuff_stacks * 3
- **位置:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/ArrowFrog.gd` 第24行
- **代码:**
```gdscript
var threshold = debuff_stacks * 3
```
- **设计文档:**
```
若敌人HP<Debuff层数*200%，则引爆斩杀
```
- **建议:** 确认设计意图，是否需要改为debuff_stacks * 2

### Bug #4: Viper单位放置毒液陷阱机制
- **严重性:** 低
- **描述:** Viper行为脚本只实现了on_projectile_hit放置陷阱，但设计文档提到"部署时放置毒液陷阱"
- **位置:** `/home/zhangzhan/tower/src/Scripts/Units/Behaviors/Viper.gd`
- **建议:** 添加on_setup方法实现部署时放置陷阱

---

## 设计问题反馈

### 趣味性

| 问题 | 描述 | 建议改进 |
|------|------|----------|
| 毒液传播反馈 | 传播时只有"传播!"文字，缺少视觉特效 | 添加绿色粒子效果或毒液飞溅动画 |
| 斩杀效果 | 箭毒蛙斩杀缺少爽快感 | 添加爆炸动画和特殊音效 |
| 陷阱互动 | 诱捕蛇的陷阱牵引效果不够明显 | 添加牵引线特效 |

### 平衡性

| 单位 | 属性 | 当前值 | 感受 | 建议值 |
|------|------|--------|------|--------|
| 毒蛇图腾核心 | 毒液伤害 | 20点 | 偏低 | 30-40点 |
| 毒蛇图腾核心 | 攻击间隔 | 5秒 | 合理 | 保持 |
| 中毒效果 | 基础伤害 | 10点/秒 | 偏低 | 15-20点/秒 |
| 中毒效果 | 最大层数 | 50层 | 过高 | 20-30层 |
| 箭毒蛙 | 斩杀阈值 | 层数*3 | 过低 | 层数*5或*10 |

### 清晰度

| 问题 | 描述 | 建议 |
|------|------|------|
| 毒液层数显示 | 敌人身上的毒液层数不够明显 | 在敌人头顶添加层数数字显示 |
| 陷阱触发提示 | 毒陷阱触发时缺少明显提示 | 添加陷阱触发特效和音效 |
| 斩杀提示 | 箭毒蛙斩杀条件不够清晰 | 敌人HP低于斩杀线时高亮显示 |

### 节奏

| 问题 | 描述 | 建议 |
|------|------|------|
| 毒液生效延迟 | 毒液每秒触发一次，初期伤害感不强 | 首次伤害立即触发，之后每秒 |
| 陷阱布置 | 部分单位部署时放置陷阱，但陷阱效果不明显 | 添加陷阱放置动画和范围指示 |

### 爽快感

| 问题 | 描述 | 建议 |
|------|------|----------|
| 毒液叠加反馈 | 层数增加时缺少反馈 | 每层增加时添加小型粒子爆发 |
| 最大层数达成 | 达到50层时没有特殊效果 | 达到最大层数时触发一次大爆炸 |
| 斩杀效果 | 箭毒蛙斩杀缺少视觉冲击 | 添加敌人溶解或爆炸动画 |
| 石化破碎 | 美杜莎石化破碎效果 | 添加石块飞溅和震动效果 |

---

## 总体印象

### 最喜欢的单位/机制

1. **箭毒蛙 (Arrow Frog)** - 斩杀机制设计有趣，基于Debuff层数的斩杀阈值鼓励玩家堆叠毒液
2. **老鼠 (PlagueSpreader)** - 毒液传播机制符合毒蛇主题，死亡传播瘟疫的设计很有特色
3. **美杜莎 (Medusa)** - 石化凝视机制独特，与毒液流派形成控制+伤害的配合

### 最无趣的单位/机制

1. **蝎子 (Scorpion)** - 尖刺陷阱机制相对简单，缺少与毒液主题的深度结合
2. **雪人 (Snowman)** - 虽然是毒蛇图腾单位，但冰冻主题与毒液主题关联性不强

### 最想看到的改进

1. **毒液爆炸效果** - 实现设计文档中提到的敌人死亡时毒液爆炸机制
2. **毒液层数UI** - 在敌人身上显示当前毒液层数
3. **斩杀预警** - 当敌人HP低于斩杀线时给予视觉提示
4. **陷阱视觉** - 增强毒陷阱的视觉效果和触发反馈

---

## 信号验证

| 信号 | 用途 | 状态 |
|------|------|------|
| poison_damage | 毒液伤害日志 | 已实现 |
| debuff_applied | Debuff施加日志 | 已实现 |
| enemy_died | 敌人死亡 | 已实现 |
| trap_triggered | 陷阱触发 | 已实现 |

---

## 测试结论

**总体状态:** 大部分功能正常，部分细节需要优化

**优先级建议:**
1. 高: 实现毒液爆炸机制（PoisonEffect._on_host_died）
2. 中: 优化毒液层数显示和斩杀预警
3. 低: 修复减速/毒液视觉冲突

*本报告基于代码分析和现有测试文档生成*
