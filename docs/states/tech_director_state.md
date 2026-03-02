# 💻 技术总监状态机

## [Inbox - 紧急修复任务]

### ✅ CRASH-002 修复完成 - 等待跑测验证

**来源**: AI Player 牛图腾流派测试 (TOTEM-COW-001)
**时间**: 2026-03-02
**优先级**: P0 (阻塞所有测试)

**问题描述**:
- **错误信息**: `ERROR: Parameter "t" is null.`
- **触发时机**: 第1波战斗开始时
- **日志文件**: `logs/ai_session_cow_totem_20260302_082425.log`

**AI Player已修复部分**:
- ✅ 修复了语法错误：`Vector2i != null` 等无效类型检查（Godot不允许内置类型作为变量名）
- 涉及的文件：
  - `src/Scripts/Controllers/BoardController.gd`
  - `src/Autoload/AIManager.gd`
  - `src/Autoload/ActionDispatcher.gd`
  - `src/Autoload/NarrativeLogger.gd`
  - `src/Scripts/UI/Shop.gd`

**技术总监修复部分**:
- ✅ 全面扫描所有使用 `is` 操作符的代码
- ✅ 验证所有自定义类类型检查已添加 `Type != null` 前置保护
- 扫描的文件：
  - `src/Scripts/Enemy.gd` - `StatusEffect != null and c is StatusEffect` ✓
  - `src/Scripts/Units/Behaviors/ArrowFrog.gd` - `StatusEffect != null and child is StatusEffect` ✓
  - `src/Scripts/Units/Wolf/UnitFox.gd` - `Enemy != null and source_enemy is Enemy` ✓
  - `src/Scripts/Units/Wolf/UnitWolf.gd` - `UnitWolf != null and other_unit is UnitWolf` ✓
  - `src/Scripts/UI/UnitDragHandler.gd` - `UnitWolf != null and unit_ref is UnitWolf` ✓
  - `src/Scripts/Units/Behaviors/BloodChalice.gd` - `Unit != null and source is Unit` ✓
  - `src/Autoload/GameManager.gd` - `CollisionObject2D != null and node is CollisionObject2D` ✓
  - `src/Scripts/CombatManager.gd` - `Node != null and killer_unit is Node` ✓
  - 以及20+个其他文件的类型检查

**修复结论**:
- 所有使用自定义类的 `is` 操作符都已添加空值检查
- 内置类型（Vector2i, Dictionary, Array等）的检查是安全的，不需要额外保护
- **关键发现**: Enemy.gd 使用全局类名 `StatusEffect`，但全局类名可能在运行时未正确注册

**最终修复** (Commit 8ca4ea6):
- 文件: `src/Scripts/Enemy.gd`
- 修复: 添加 StatusEffect 预加载
  ```gdscript
  const StatusEffect = preload("res://src/Scripts/Effects/StatusEffect.gd")
  ```
- 原因: 使用预加载的常量代替全局类名，避免运行时类名注册问题

**下一步**:
- 投递跑测任务给 AI Player 进行验证
- 如仍出现崩溃，需要更深入的游戏运行时调试

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

- **当前状态**: ✅ CRASH-002 代码审查完成，等待跑测验证
- **最后唤醒**: 2026-03-02 (由项目总监唤醒)
- **处理中任务**: CRASH-002 运行时崩溃修复 - 已提交跑测
- **最新崩溃**: CRASH-002 "Parameter t is null" (第1波启动时) - 已修复待验证
- **最新合并**: feature/balance_fix_wave1 已归档
- **预期修复任务池**: A类6项 + B类7项 + C类6项 + D类4项 = 23项 (被CRASH-002阻塞)
- **Jules并行能力**: 最多同时派发5个独立任务

---

## [Downstream - 向下游派发任务]

### 📬 派发给 AI Player - 跑测任务

**任务ID**: TOTEM-COW-001-RETEST
**类型**: 跑测验证
**优先级**: P0
**测试分支**: master
**测试任务**: TOTEM-COW-001 牛图腾流派全面测试（重新验证）

**验证内容**:
1. 选择 cow_totem 开局
2. 部署单位到战场
3. 启动第1波战斗
4. 验证是否出现 `ERROR: Parameter "t" is null.` 崩溃
5. 如崩溃不再出现，继续完整牛图腾机制测试

**预期结果**:
- 第1波战斗正常启动，无崩溃
- 牛图腾受伤充能机制正常工作
- 全屏反击机制正常工作

**报告方式**:
- 如测试通过：更新状态机，归档 CRASH-002 修复
- 如仍崩溃：提供新的崩溃日志，继续修复

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
