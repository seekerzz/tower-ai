# 💻 技术总监状态机

## [Inbox - 待处理提案]

### 🚨 CRASH-002 - 波次启动全局崩溃修复任务

**来源**: AI_Player -- 2026-03-02T00:26:00+08:00
**优先级**: P0 (阻塞所有图腾流派测试)
**状态**: 待修复

**问题描述**:
游戏在启动第1波战斗时发生崩溃，错误信息 `ERROR: Parameter "t" is null.`
该崩溃影响所有图腾流派测试（牛图腾、狼图腾、蝙蝠图腾等均受影响）。

**崩溃日志**:
```
【波次事件】第 1 波战斗正式开始！
【系统严重报错】检测到 Godot 引擎崩溃：
错误类型：ERROR: Parameter "t" is null.
堆栈：
ERROR: Parameter "t" is null.
```

**根因分析**:
- 崩溃发生在波次启动时，可能与CombatManager.gd或敌人初始化相关
- 错误信息"Parameter t is null"暗示某个类型参数为null
- 需要检查波次启动流程中的节点初始化、敌人生成、定时器设置等

**可能的修复位置**:
- `src/Scripts/CombatManager.gd` - 波次启动逻辑
- `src/Scripts/GridManager.gd` - 网格/敌人管理
- `src/Autoload/GameManager.gd` - 游戏状态管理

**人工验证点**:
1. 选择任意图腾开局（cow_totem/wolf_totem/bat_totem等）
2. 购买任意单位并部署到网格
3. 启动第1波战斗
4. 确认游戏不再崩溃，敌人正常生成
5. 确认波次正常进行，核心受击、单位攻击等机制正常

**关联任务**: TOTEM-COW-001, TOTEM-WOLF-001, TOTEM-BAT-001 等所有图腾测试（全部阻塞中）
**生成日志**: logs/ai_session_cow_totem_20260302_002649.log

---

### 🚨 CRASH-WOLF-001 - 狼图腾崩溃修复任务

**来源**: AI_Player -- 2026-03-02T00:25:00+08:00
**优先级**: P0 (阻塞狼图腾全面测试)
**状态**: 待修复

**问题描述**:
狼图腾(MechanicWolfTotem.gd)在波次开始时发生崩溃，错误信息 `ERROR: Parameter "t" is null.`

**根因分析**:
`_on_totem_attack()` 函数缺少波次状态检查，当定时器在非波次期间触发时，
`get_nearest_enemies()` 可能返回包含无效节点的数组，导致 `deal_damage()` 崩溃。

**对比参考**:
蝙蝠图腾(MechanicBatTotem.gd)的实现正确处理了此问题:
```gdscript
func _on_totem_attack():
    if !GameManager.is_wave_active: return  # 狼图腾缺少此行
    var targets = get_nearest_enemies(target_count)
    ...
```

**修复文件**: `src/Scripts/CoreMechanics/MechanicWolfTotem.gd`

**修复代码**:
```gdscript
func _on_totem_attack():
    if !GameManager.is_wave_active: return
    var targets = get_nearest_enemies(3)
    var soul_bonus = TotemManager.get_resource(TOTEM_ID)
    for enemy in targets:
        if is_instance_valid(enemy):
            var damage = base_damage + soul_bonus
            deal_damage(enemy, damage)
```

**人工验证点**:
1. 选择 wolf_totem 开局
2. 购买 wolf 或 dog 单位并部署
3. 启动第1波战斗
4. 确认游戏不再崩溃，波次正常进行
5. 观察狼图腾定时攻击是否正常触发

**关联任务**: TOTEM-WOLF-001 狼图腾全面测试 (阻塞中)
**生成日志**: logs/ai_session_wolf_totem_20260302_002530.log

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

- **当前状态**: 处理紧急崩溃修复
- **最后唤醒**: 2026-03-02 (由项目总监唤醒)
- **处理中任务**: CRASH-002 波次启动全局崩溃修复（最高优先级）
- **最新崩溃**: CRASH-002 波次启动时崩溃 (ERROR: Parameter "t" is null.)
- **最新合并**: feature/balance_fix_wave1 已归档
- **预期修复任务池**: A类6项 + B类7项 + C类6项 + D类4项 = 23项
- **Jules并行能力**: 最多同时派发5个独立任务
