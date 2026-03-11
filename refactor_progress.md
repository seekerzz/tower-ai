# Refactor Progress (GridManager / Unit)

## Goal
逐步消除 `src/Scripts/GridManager.gd` 与 `src/Scripts/Unit.gd` 的上帝类问题，采用“保持外部接口不变、内部渐进下沉”的策略。

## Baseline Problems
- `GridManager` 同时承担网格、交互、Buff、扩张、UI 图标等职责。
- `Unit` 仍承担大量编排 + 视觉细节，尤其是 Buff 视觉反馈逻辑耦合在实体层。

## Completed Steps

### Step G1（已完成）
- 抽离 `GridBuffService` / `GridExpansionService`。
- `GridManager` 对 buff 重算与扩张主流程转委托。
- 已加入 headless 与静态委托回归测试。

**人工验证现象**
- 进入扩张模式时，幽灵地块正常出现/清除。
- 触发重算（移动、交换）后，单位 Buff 数值与视觉正常更新。

### Step G2（已完成）
- 修复 `GridManager` 对 `Unit._get_buff_icon` 的私有调用，改为公共 API 链路。
- `Unit` 暴露 `get_buff_icon`，`GridManager` 经 resolver 安全获取图标。

**人工验证现象**
- 放置提供 Buff 的单位不再报 `Invalid call ... _get_buff_icon`。
- 交互 Buff 图标与飘字仍然显示。

### Step G3（已完成）
- 将 `GridManager` 的以下 Buff 职责继续下沉到 `GridBuffService`：
  - `_apply_buff_to_neighbors`
  - `show_provider_icons`
  - `_spawn_provider_icon_at`
  - `hide_provider_icons`
  - `resolve_buff_icon`

**人工验证现象**
- 鼠标悬停/交互时提供者图标仍正常显示。
- 邻域 Buff 仍正确应用，无明显缺失。

### Step U1（本次完成）
- 将 `Unit.gd` 中 Buff 视觉反馈逻辑下沉到 `UnitVisualComponent.gd`：
  - `play_buff_receive_anim`
  - `spawn_buff_effect`
- `Unit.gd` 保留稳定委托壳，避免外部调用点改动。

**人工验证现象（请重点验证）**
1. 单位吃到 Buff 时仍有“放大再回弹”反馈动画。
2. 单位触发 `spawn_buff_effect` 时，emoji 飘字仍出现并淡出。
3. 连续触发 Buff 时，不出现节点泄漏/报错（尤其是 Tween 相关）。

## Current Architecture Snapshot
- `GridManager`: 以 orchestration + delegation 为主。
- `GridBuffService`: Buff 计算、邻域应用、provider 图标展示。
- `GridExpansionService`: 扩张模式与 ghost 地块处理。
- `Unit`: 保留实体编排；Buff 视觉反馈由 `UnitVisualComponent` 负责。

## Next Planned Steps

### Step U2（下一步）
- 继续瘦身 `Unit.gd`：将 `get_buff_icon` 也下沉为纯 visual_component API（Unit 只保留转发）。
- 评估并迁移其它纯视觉函数到 `UnitVisualComponent`（保持行为不变）。

### Step U3（后续）
- 将 `Unit` 里与拖拽/放置输入强相关的细节进一步归并到 `UnitInteractionComponent`。
- 增加最小回归测试，覆盖“拖拽 -> 放置 -> Buff 更新”链路。

### Step G4（后续）
- 拆分 `GridManager` 交互状态机（skill targeting / interaction selection / trap placement）到独立 Interaction Controller。

## Validation Strategy
- 先静态委托断言，再 headless 脚本验证，最后人工场景验证。
- 每一步都保持对外函数签名不变，降低回归风险。
