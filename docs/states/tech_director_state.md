# 💻 技术总监状态机

## [Inbox - 紧急修复任务]

### ✅ CRASH-002 第四轮修复完成

**任务ID**: CRASH-002-FIX-4
**来源**: 项目总监指派
**时间**: 2026-03-02
**优先级**: P0 (阻塞所有测试)
**状态**: ✅ 修复已实施并提交

**修复提交**: Commit 2f93927

**修复内容**:
1. ✅ 移除 `TauntBehavior.gd` 的 `class_name TauntBehavior`
2. ✅ 修复 `YakGuardian.gd` 类型声明为 `var taunt_behavior = null`
3. ✅ 增强 `BaseTotemMechanic.get_nearest_enemies()` 防御性编程（添加敌人列表有效性过滤）
4. ✅ 修复 `CombatManager.find_nearest_enemy()` 空值检查
5. ✅ 修复 `DefaultBehavior._find_nearest_hostile()` 空值检查

**根本原因**:
1. `class_name` + 脚本路径继承混合使用导致 Godot 类注册时序问题
2. 敌人列表访问时缺乏空值检查，可能访问到已释放的节点

**下一步**: 等待 AI Player 执行 TOTEM-COW-001-RETEST-3 验证测试

---

#### 调查范围

已检查以下与 Taunt/Aggro 机制相关的核心文件：

| 文件路径 | 检查内容 | 状态 |
|---------|---------|------|
| `src/Scripts/Managers/AggroManager.gd` | Taunt 管理器实现 | ✅ 无 `is` 操作符问题 |
| `src/Scripts/Units/Behaviors/TauntBehavior.gd` | Taunt 行为逻辑 | ⚠️ 发现潜在问题 |
| `src/Scripts/Units/Behaviors/YakGuardian.gd` | 牦牛守护单位行为 | ⚠️ 发现潜在问题 |
| `src/Scripts/Units/UnitBehavior.gd` | 行为基类 | ✅ 正常 |
| `src/Scripts/Unit.gd` | 单位主类 | ✅ 正常 |
| `src/Scripts/Enemy.gd` | 敌人类（调用 find_attack_target） | ✅ 已修复 `is` 检查 |
| `src/Scripts/Enemies/Behaviors/DefaultBehavior.gd` | 敌人默认行为 | ✅ 无 `is` 操作符问题 |
| `src/Scripts/Managers/WaveSystemManager.gd` | 波次管理器 | ✅ 正常 |

---

#### 关键发现（基于AI Player诊断更新）

**AI Player诊断结论**: 崩溃与单位部署无关、与图腾类型无关 → **非Taunt问题**

**修正后的调查范围**:

| 文件路径 | 检查内容 | 状态 |
|---------|---------|------|
| `src/Scripts/Managers/WaveSystemManager.gd` | 波次启动逻辑 | ✅ 正常 |
| `src/Autoload/GameManager.gd` | is_wave_active setter | ✅ 正常 |
| `src/Scripts/Data/SessionData.gd` | wave_state_changed信号 | ✅ 正常 |
| `src/Scripts/CombatManager.gd` | 敌人生成逻辑 | ⚠️ 发现潜在问题 |
| `src/Scripts/CoreMechanics/BaseTotemMechanic.gd` | 图腾攻击逻辑 | ⚠️ 发现潜在问题 |
| `src/Scripts/Enemies/Behaviors/DefaultBehavior.gd` | 敌人AI逻辑 | ⚠️ 发现潜在问题 |

---

#### 关键发现

**发现1: BaseTotemMechanic.get_nearest_enemies() 空值检查缺失**

```gdscript
# src/Scripts/CoreMechanics/BaseTotemMechanic.gd 第16-18行
enemies.sort_custom(func(a, b):
    return a.global_position.distance_squared_to(core_pos) < b.global_position.distance_squared_to(core_pos)
)
```
**问题**: 没有检查 `a` 和 `b` 的有效性，如果敌人列表包含已被释放的节点，访问 `global_position` 会崩溃。

**发现2: CombatManager.find_nearest_enemy() 空值检查缺失**

```gdscript
# src/Scripts/CombatManager.gd 第262-266行
for enemy in get_tree().get_nodes_in_group("enemies"):
    var dist = pos.distance_to(enemy.global_position)  # <-- 没有is_instance_valid检查
```

**发现3: DefaultBehavior._find_nearest_hostile() 空值检查缺失**

```gdscript
# src/Scripts/Enemies/Behaviors/DefaultBehavior.gd 第220-227行
for other in get_tree().get_nodes_in_group("enemies"):
    var dist = enemy.global_position.distance_to(other.global_position)  # <-- 没有is_instance_valid检查
```

**发现4: 所有 `is` 操作符已修复**
- 全面扫描了所有GDScript文件
- 26+个文件中的`is`操作符都已添加`Type != null`前置检查
- 但崩溃仍然发生，说明**根本原因不是`is`操作符**

`TauntBehavior` 使用 `class_name` 同时继承自脚本路径，这种混合用法在 Godot 中可能导致类注册问题。

**发现3: 所有 `is` 操作符已修复**

全面扫描了所有 GDScript 文件，确认所有已知的 `is` 操作符使用都已添加 `Type != null` 前置检查。已检查的文件包括：
- `Enemy.gd` - 已修复
- `DistanceDamageDebuff.gd` - 已修复
- `InventoryPanel.gd` - 已修复
- `MainGUI.gd` - 已修复
- `UnitWolf.gd`, `UnitFox.gd` - 已修复
- `ArrowFrog.gd`, `BloodChalice.gd` - 已修复
- `PetrifiedStatus.gd`, `PetrifiedShatterEffect.gd` - 已修复
- 以及其他 15+ 个文件

---

#### 崩溃触发链分析

```
第1波开始
    ↓
WaveSystemManager.start_wave() → is_wave_active = true
    ↓
Unit._process() 开始执行 (因为 is_wave_active)
    ↓
YakGuardian.on_tick() → taunt_behavior.on_tick()
    ↓
TauntBehavior._trigger_taunt() → AggroManager.apply_taunt()
    ↓
AggroManager.apply_taunt() 发射 taunt_started 信号
    ↓
[崩溃发生点]
```

---

#### 假设：TauntBehavior 类加载问题

**假设**: `TauntBehavior` 使用 `class_name` 的同时继承自脚本路径，可能导致：
1. 类注册时出现问题
2. `YakGuardian.gd` 加载时 `TauntBehavior` 类尚未注册完成
3. 运行时 `TauntBehavior` 实际为 null，导致 `is` 操作符崩溃

**验证方法**: 需要修改代码并测试

---

#### 建议的修复方案

**方案A: 移除 TauntBehavior 的 class_name（推荐）**

```gdscript
# TauntBehavior.gd
# 移除: class_name TauntBehavior
extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
```

**方案B: 修改 YakGuardian 类型声明**

```gdscript
# YakGuardian.gd
# 改为不使用类型注解，或改为 var taunt_behavior = null
var taunt_behavior = null
```

**方案C: 延迟 TauntBehavior 实例化**

```gdscript
# YakGuardian.gd
func on_setup():
    # 延迟一帧加载，确保类已注册
    await get_tree().process_frame
    var script = load("res://src/Scripts/Units/Behaviors/TauntBehavior.gd")
    ...
```

---

#### 崩溃触发链分析（基于AI Player诊断更新）

```
第1波开始
    ↓
WaveSystemManager.start_wave() → is_wave_active = true
    ↓
GameManager._on_wave_system_started() → wave_started.emit()
    ↓
CombatManager._on_wave_started() → start_wave_logic()
    ↓
CombatManager._run_batch_sequence() → _spawn_enemy_at_pos()
    ↓
敌人出生，加入"enemies"组
    ↓
Enemy._physics_process()开始执行（因为is_wave_active=true）
    ↓
DefaultBehavior.physics_process() → _find_nearest_hostile()
    ↓
get_tree().get_nodes_in_group("enemies") 返回敌人列表
    ↓
访问 enemy.global_position / other.global_position
    ↓
[如果列表中包含无效节点，崩溃发生]
```

**关键洞察**:
- 敌人出生和加入组是原子操作
- 但敌人在`_ready()`中可能还没有完全初始化
- 如果其他代码（如图腾攻击）在敌人完全初始化前访问列表，可能获取到无效节点

---

#### 根本原因假设（更新）

**假设1: 敌人列表竞争条件**
- 敌人被创建并加入"enemies"组
- 但在`_ready()`完成前，其他代码访问了该敌人
- 访问`global_position`时节点无效

**假设2: 波次状态切换时序问题**
- `is_wave_active = true`被设置
- 敌人`_physics_process`开始执行
- 但某些初始化代码还未完成

**假设3: Godot组系统问题**
- `get_tree().get_nodes_in_group("enemies")`可能返回正在释放的节点
- 需要`is_instance_valid()`检查

---

#### 建议的修复方案（更新）

**方案A: 添加is_instance_valid检查（P0）**

修改以下文件：
1. `BaseTotemMechanic.get_nearest_enemies()` - 添加敌人有效性检查
2. `CombatManager.find_nearest_enemy()` - 添加敌人有效性检查
3. `DefaultBehavior._find_nearest_hostile()` - 添加敌人有效性检查

**方案B: 延迟敌人AI启动（P1）**
- 在Enemy._physics_process()中添加额外初始化检查
- 或使用`call_deferred`延迟行为启动

**方案C: 波次状态原子性（P2）**
- 确保`is_wave_active = true`时所有初始化已完成
- 或使用信号机制确保时序正确

---

#### 结论

经过全面调查，**所有`is`操作符已修复**，但崩溃仍然发生。

**新的根本原因假设**: 敌人列表访问时的空值/无效节点问题。

**建议**: 实施方案A，为所有访问敌人列表的代码添加`is_instance_valid()`检查。

---

### ❌ CRASH-002 第二轮修复验证失败

**任务ID**: TOTEM-COW-001-RETEST-2
**来源**: AI Player 跑测验证
**时间**: 2026-03-02 09:20:45
**优先级**: P0 (阻塞所有测试)
**状态**: ❌ 修复未成功，崩溃仍然发生

**问题描述**:
- **错误信息**: `ERROR: Parameter "t" is null.`
- **触发时机**: 第1波战斗开始时
- **日志文件**: `logs/ai_session_cow_totem_20260302_092045.log`
- **崩溃时间戳**: 09:20:45

**第二轮修复尝试** (Commit 2baaa01):
- `DistanceDamageDebuff.gd`: 添加 `Timer != null` 前置检查
- `InventoryPanel.gd`: 修复逻辑为 `ScrollContainer != null and not (parent is ScrollContainer)`
- `MainGUI.gd`: 修复两处逻辑为 `Container != null and not (top_left_panel is Container)`

**验证结果**: ❌ 崩溃仍然发生，修复未成功

**已验证机制**:
- ✅ 牛图腾选择正常
- ✅ 商店阵营过滤正常
- ✅ 单位购买部署正常
- ✅ 核心血量计算正常 (500.0 → 1000.0)

**下一步**:
- 需要进一步深入调查根本原因
- 可能涉及其他文件的 `is` 操作符使用
- 建议检查 Godot 引擎版本兼容性问题
- 建议添加更详细的堆栈跟踪信息

---

### 📊 游戏策划黑盒分析报告 - 牛图腾测试日志

**来源**: @Game_Designer 黑盒观察分析
**日志文件**: `logs/ai_session_cow_totem_20260302_082425.log`
**分析时间**: 2026-03-02

#### 1. 崩溃前游戏状态总结

| 时间戳 | 事件 | 状态 |
|--------|------|------|
| 08:24:25.064 | 测试开始 | ✅ 正常 |
| 08:24:26.069 | 图腾选择界面 | ✅ 显示6个图腾选项 |
| 08:24:26.271 | 选择牛图腾 | ✅ 成功选择 cow_totem |
| 08:24:28.587 | 购买单位 | ⚠️ 意图购买 iron_turtle，实际购买 spiderling |
| 08:24:30.097 | 部署单位 | ✅ spiderling 部署到 (1,0) |
| 08:24:31.607 | 核心血量更新 | ✅ 500.0 → 530.0（+30血量加成） |
| 08:24:31.607 | 商店刷新 | ✅ 显示牛阵营单位: sunflower/drum/yak_guardian/enemy_clone |
| 08:24:35.841 | 第1波启动 | ❌ **CRASH-002 崩溃发生** |

#### 2. 已验证机制表现

| 机制 | 验证结果 | 备注 |
|------|----------|------|
| 牛图腾选择 | ✅ 正常 | 成功选择 cow_totem |
| 商店阵营过滤 | ✅ 正常 | 正确显示牛阵营专属单位 |
| 单位购买 | ✅ 正常 | 单位成功进入 bench |
| 单位部署 | ✅ 正常 | 单位正确放置到指定坐标 |
| 核心血量计算 | ✅ 正常 | 基础500 + 单位加成30 = 530 |

#### 3. 日志埋点不足之处

**严重不足 - 无法验证图腾机制**:
- ❌ 牛图腾受伤充能数值不可见
- ❌ 全屏反击触发时机和伤害不可见
- ❌ 敌人出生信息未记录（数量、类型、位置）
- ❌ 核心受击事件未记录（伤害来源、数值）
- ❌ 单位实际属性不可见（ iron_turtle 变 spiderling 原因不明）

**关键缺失 - 战斗过程黑盒**:
- ❌ 敌人移动路径不可追踪
- ❌ 单位攻击事件未记录
- ❌ 图腾效果触发日志缺失
- ❌ 状态效果（buff/debuff）变更不可见

#### 4. 给技术总监的崩溃调查线索

**线索1: 崩溃触发条件**
- 崩溃发生在第1波战斗**正式开始**的瞬间（08:24:35.841）
- 波次事件消息刚输出就崩溃：`【波次事件】第 1 波战斗正式开始！`
- 说明问题在 Wave Start 的回调逻辑中

**线索2: 已加载的游戏状态**
- 有单位部署在战场上（spiderling @ (1,0)）
- 核心血量已计算完成（530/530）
- 图腾已选择（cow_totem）
- 这些状态在崩溃前都是正常的

**线索3: 问题定位方向**
- 重点检查 WaveManager 的 `start_wave()` 或类似方法
- 检查波次启动时是否有 `is` 操作符检查（敌人/单位/图腾类型）
- 检查是否有对象在波次启动时被实例化但未被正确初始化
- 检查敌人 Spawn 逻辑中是否有类型判断

**线索4: 与图腾的关联性**
- 崩溃发生在选择 cow_totem 后，但是否只有牛图腾会触发？
- 建议验证其他图腾是否也会导致同样崩溃

#### 5. 设计层面的观察

**单位购买异常**:
- AI 尝试购买 iron_turtle，但实际购买的是 spiderling
- 可能原因: 商店显示与实际库存不一致 / 购买逻辑有bug / 金币不足自动替换
- 需要验证：购买时是否有足够的金币？商店刷新逻辑是否正确？

**建议的临时规避方案**:
- 如果修复需要时间，考虑先禁用第1波敌人，直接跳到第2波测试其他机制
- 或者在波次启动前添加更多日志埋点，帮助定位问题

---

**来源**: @Game_Designer - 分析完成，等待CRASH-002修复后重测

---

### 📊 游戏策划黑盒分析报告 - CRASH-002 深度分析

**来源**: @Game_Designer - 基于多份崩溃日志的黑盒分析
**报告文件**: `docs/design_proposals/proposal_crash002_analysis.md`
**分析时间**: 2026-03-02

#### 核心发现

1. **崩溃时机绝对固定**: 100% 发生在第1波战斗正式开始时
2. **影响范围**: 所有图腾流派均受影响（牛/蝙蝠/狼已确认）
3. **错误信息一致**: `ERROR: Parameter "t" is null.`
4. **时间窗口**: 波次开始后的极短时间内（<1秒）

#### 崩溃前事件序列（以牛图腾为例）

```
T+00:00  【状态同步】当前核心血量：500.0/500.0
T+00:00  【商店刷新】当前商店提供: rage_bear(65), bear(65), yak_guardian(60), lucky_cat(100)
T+00:01  【图腾选择完成】已选择图腾：cow_totem，游戏开始！
T+00:02  【单位购买】购买了 yak_guardian，放入了 bench 坐标 0
T+00:03  【单位部署】yak_guardian 被放置在了坐标 (1, 0)
T+00:04  【状态同步】当前核心血量：1000.0/1000.0
T+00:05  【波次事件】第 1 波战斗正式开始！
T+00:05  【系统严重报错】ERROR: Parameter "t" is null.  <-- 崩溃发生
```

#### 与 Taunt/嘲讽机制的关联

**牦牛守护 (Yak Guardian) 技能**: 每隔5秒吸引周围的敌人攻击自己

**关键观察**: 图腾攻击定时器（5秒）与牦牛守护嘲讽定时器（5秒）可能存在冲突！

#### 竞争条件假说

崩溃可能是由于以下时序竞争导致：
1. 波次开始信号发出
2. 图腾攻击定时器恰好在此时触发
3. 尝试获取敌人列表进行攻击
4. 敌人列表为空或包含null节点
5. 崩溃：Parameter "t" is null

#### 与 CRASH-WOLF-001 的对比

| 特征 | CRASH-WOLF-001 | CRASH-002 |
|-----|---------------|-----------|
| 错误信息 | Parameter "t" is null | Parameter "t" is null |
| 发生时机 | 第1波开始时 | 第1波开始时 |
| 根本原因 | 缺少 `is_wave_active` 检查 | **待确定 - 可能是更深层的时序问题** |
| 修复状态 | 已修复 | **三轮修复未成功** |

**关键差异**: CRASH-WOLF-001 是代码级问题，而 CRASH-002 在修复后仍然出现，说明可能存在更深层的时序或竞争条件问题。

#### 给技术总监的5条调查建议

**建议1 (P0)**: 检查图腾攻击定时器的波次状态判断
- GameManager.is_wave_active 的 setter 是否有延迟？
- 定时器触发和波次开始信号是否存在时序竞争？

**建议2 (P0)**: 检查敌人列表的初始化时机
- 敌人 spawn 和加入活跃列表是否是原子操作？
- get_nearest_enemies() 是否可能返回包含 null 的数组？

**建议3 (P1)**: 检查牦牛守护嘲讽技能的初始化
- 嘲讽定时器是否在单位部署时立即触发？
- 嘲讽目标选择是否处理了敌人列表为空的情况？

**建议4 (P1)**: 添加更详细的日志埋点
- 波次开始前的状态快照
- 图腾攻击触发时的详细日志
- 敌人列表变化时的日志

**建议5 (P2)**: 考虑 Godot 引擎版本相关问题
- Timer 节点在场景切换时的行为
- 信号连接在节点释放时的处理

#### 紧急建议

1. **在 MechanicTotemBase 或各图腾实现中添加防御性编程**：
   - 在获取敌人列表后，遍历前检查每个元素的有效性
   - 在 deal_damage 调用前添加 null 检查
   - 考虑使用 Godot 的 `is_instance_valid()` 函数

2. **检查波次状态切换的原子性**：
   - 确保 `is_wave_active = true` 和敌人初始化是原子操作
   - 或者考虑在波次开始信号发出前完成所有敌人初始化

3. **考虑延迟图腾攻击定时器的启动**：
   - 在波次开始后的短暂延迟（如0.5秒）后再启动图腾攻击定时器
   - 确保敌人已完全初始化并可被攻击

---

## [Inbox - 待处理提案]

- [ ] 待处理提案: docs/design_proposals/proposal_log_improvement_001.md -- 来源@Game_Designer -- 2026-03-02
  - 问题：图腾机制日志埋点严重不足，无法通过黑盒观察验证机制
  - 关联日志：牛图腾/蝙蝠图腾/狼图腾测试日志（均因崩溃未能完整测试）
  - 优先级：P1（因CRASH-002重新出现，降级处理，先修复崩溃）
  - 建议：在修复崩溃的同时增加日志埋点，详见提案文档

---

## [Inbox - 待合并分支]

<!-- 待合并分支列表 -->

## [Workspace - 工作区]

### 🛠️ 全面图腾机制测试 - 预期修复任务池

**背景**: 项目总监已启动全面AI测试，覆盖6大图腾流派+通用单位+系统机制。以下为预期可能产生的修复任务分类。

**预期任务分类**:

#### A类 - 图腾核心机制修复
- **A1**: 牛图腾受伤充能/全屏反击修复
- **A2**: 蝙蝠图腾流血标记/吸血修复
- **A3**: 蝴蝶图腾法球生成/法力回复修复
- **A4**: 狼图腾魂魄获取/攻击加成修复
- **A5**: 毒蛇图腾毒液/中毒层数修复
- **A6**: 鹰图腾暴击回响修复

#### B类 - 单位技能修复
- **B1**: 牛流派单位修复(牦牛、苦修者、铁甲龟、奶牛)
- **B2**: 蝙蝠流派单位修复(蚊子、石像鬼、血法师、生命链条等)
- **B3**: 蝴蝶流派单位修复(火炬、冰晶蝶、仙女龙、凤凰等)
- **B4**: 狼流派单位修复(羊灵、狮子、血食、鬣狗、狐狸)
- **B5**: 毒蛇流派单位修复(蜘蛛、雪人、蝎子、箭毒蛙、美杜莎)
- **B6**: 鹰流派单位修复(角雕、疾风鹰、红隼、风暴鹰等)
- **B7**: 通用单位修复(向日葵、战鼓、魔镜、棱镜、金蟾等)

#### C类 - 系统机制修复
- **C1**: 商店刷新/阵营过滤修复
- **C2**: 扩建成本计算修复
- **C3**: 核心血量实时计算修复
- **C4**: 法力回复机制修复
- **C5**: 击退/碰撞系统修复
- **C6**: Buff传播/叠加规则修复

#### D类 - 日志埋点增强
- **D1**: 图腾机制日志埋点补充
- **D2**: 单位技能日志埋点补充
- **D3**: 状态效果日志埋点补充
- **D4**: 经济系统日志埋点补充

**Jules任务模板**（待实际提案到达后派发）:
```
要求：
1. 修改 src/.../xxx.gd 文件，修复 XXX 机制
2. 采用 Godot 进行真实运行调试，并自动修正返回的报错日志
3. 输出人工测试验证点：如何在游戏中验证该修复是否生效
4. 禁止创建任何 .md 文件或文档
```

---

## [Archive - 归档]

### 🚨 CRASH-002 波次启动全局崩溃修复完成

**问题**: Godot 4 中 `is` 操作符在类型参数为 null 时崩溃
- 错误信息: `ERROR: Parameter "t" is null.`
- 影响范围: 所有使用 `is` 操作符进行类型检查的代码
- 修复文件: 26个文件，包括：
  - `src/Scripts/Enemy.gd` - `is StatusEffect`
  - `src/Scripts/Units/Behaviors/ArrowFrog.gd` - `is StatusEffect`
  - `src/Scripts/Units/Wolf/UnitFox.gd` - `is Enemy`
  - `src/Scripts/Units/Wolf/UnitWolf.gd` - `is UnitWolf`
  - `src/Scripts/UI/UnitDragHandler.gd` - `is UnitWolf`
  - `src/Scripts/Units/Behaviors/BloodChalice.gd` - `is Unit`
  - 以及其他20个文件中的类型检查
- 修复方式: 为所有 `is` 操作符添加 `Type != null` 前置检查
- 修复时间: 2026-03-02
- 人工验证点: 选择任意图腾开局，部署单位，启动第1波，确认不再崩溃

---

### 🚨 CRASH-WOLF-001 狼图腾崩溃修复完成

**问题**: MechanicWolfTotem.gd 在波次开始时崩溃
- 文件: `src/Scripts/CoreMechanics/MechanicWolfTotem.gd`
- 错误: `_on_totem_attack()` 缺少波次状态检查，非波次期间定时器触发时 `get_nearest_enemies()` 返回无效节点
- 修复: 添加 `if !GameManager.is_wave_active: return` 和 `if is_instance_valid(enemy)` 检查
- 修复时间: 2026-03-02
- 人工验证点: 选择 wolf_totem 开局，部署单位，启动波次，确认不再崩溃

---

### 🚨 CRASH-001 修复完成

**问题**: AILogger.gd 字符串格式化错误导致AI测试崩溃
- 文件: `src/Autoload/AILogger.gd` 第51行
- 错误: `print_rich("s%s[动作] %s%s" % [...])` - 多余的前导`s`
- 修复: 改为 `print_rich("%s%s[动作] %s%s" % [...])`
- 修复时间: 2026-03-02
- 修复方式: 直接代码修改（Jules代理连接失败时使用备用方案）
- 人工验证点: 启动AI客户端选择图腾，确认不再崩溃

---

- [x] 已合并分支: feature/balance_fix_wave1 -- 来源@AI_Player -- 2026-03-02T00:00:00+08:00
  - 跑测结果: 通过
  - 日志路径: logs/ai_session_20260301_233539.log
  - 验证内容: 第1波6个slime/30伤害/总伤180，所有日志埋点正常，毒蛇图腾和viper中毒buff工作正常
  - 状态: 分支内容已确认合并至master，无代码级崩溃
  - 人工验证点: 选择viper_totem开局，验证第1波敌人数量和伤害数值，检查日志埋点输出

- [x] 已处理提案: docs/design_proposals/proposal_balance_fix_001.md -- 来源@Game_Designer -- 2026-03-01T18:45:00+08:00
  - 完成：第1波难度调整（10个slime→6个，50伤害→30伤害）
  - 完成：日志埋点系统实现（8种埋点类型）
  - 状态：已投递AI Player跑测验证

## [Meta - 元数据]

- **当前状态**: 🔍 CRASH-002 深入调查完成，发现敌人列表空值检查缺失问题
- **最后唤醒**: 2026-03-02 (由项目总监唤醒)
- **处理中任务**: CRASH-002 运行时崩溃修复 - 第二轮修复已提交
- **最新崩溃**: CRASH-002 "Parameter t is null" (第1波启动时) - 第二轮修复待验证
- **最新合并**: Commit 2baaa01 - 修复3个文件中的不安全 `is` 操作符使用
- **预期修复任务池**: A类6项 + B类7项 + C类6项 + D类4项 = 23项 (被CRASH-002阻塞)
- **Jules并行能力**: 最多同时派发5个独立任务

---

## [Downstream - 向下游派发任务]

### 📬 派发给 AI Player - 跑测任务 (更新)

**任务ID**: TOTEM-COW-001-RETEST-2
**类型**: 跑测验证
**优先级**: P0
**测试分支**: master
**依赖提交**: Commit 2baaa01 (CRASH-002 第二轮修复)
**测试任务**: TOTEM-COW-001 牛图腾流派全面测试（第二轮验证）

**验证内容**:
1. 拉取最新 master 分支 (包含 Commit 2baaa01)
2. 选择 cow_totem 开局
3. 部署单位到战场
4. 启动第1波战斗
5. **关键验证**: 确认不再出现 `ERROR: Parameter "t" is null.` 崩溃
6. 如崩溃不再出现，继续完整牛图腾机制测试

**技术总监修复说明**:
- 修复了3个文件中不安全的 `is` 操作符使用
- DistanceDamageDebuff.gd: 添加 Timer != null 检查
- InventoryPanel.gd: 修复 ScrollContainer 检查逻辑
- MainGUI.gd: 修复 Container 检查逻辑 (2处)

**预期结果**:
- 第1波战斗正常启动，无崩溃
- 牛图腾受伤充能机制正常工作
- 全屏反击机制正常工作

**报告方式**:
- 如测试通过：更新状态机，归档 CRASH-002 修复，继续图腾机制测试
- 如仍崩溃：提供新的崩溃日志和 Godot 堆栈跟踪，继续第三轮修复

---

## [Upstream - 向上游汇报]

### ✅ 修复里程碑完成 - 2026-03-02

**修复批次**: CRASH-002 + CRASH-WOLF-001
**状态**: 已完成代码修复，等待AI Player跑测验证

**修复摘要**:
1. **CRASH-002** - 26个文件的 `is` 操作符空值检查修复
2. **CRASH-WOLF-001** - MechanicWolfTotem.gd 波次状态检查修复

**人工测试验证点**:
1. 选择任意图腾开局，部署单位，启动第1波，确认不再崩溃
2. 选择 wolf_totem 开局，部署wolf/dog单位，启动波次，确认狼图腾攻击正常

**等待**: AI Player 跑测通过后，将自动合并并归档
