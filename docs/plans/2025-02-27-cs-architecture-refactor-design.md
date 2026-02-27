# C/S 架构重构设计文档

## 目标
将 Godot 塔防项目改造为 C/S 架构，为后续接入外部 Python AI Agent（基于 WebSocket 驱动）做准备。

## 当前问题
1. `GameManager` 是"上帝对象"，有42个信号和全局引用
2. UI 直接访问 GameManager 获取和修改状态
3. `MainGame` 持有所有子系统的直接引用
4. 没有正式的状态机，使用布尔标志（`is_wave_active`）
5. UI 与核心逻辑严重耦合

## 设计方案：纯数据层分离

### 1. SessionData（数据层）

**职责：** 存储单个战局的所有纯数据状态

**核心属性：**
```gdscript
# 资源
var gold: int
var mana: int
var max_mana: int
var core_health: int
var max_core_health: int

# 波次状态
var wave: int
var is_wave_active: bool

# 棋盘状态
var grid_units: Dictionary  # Vector2i -> UnitData
var bench_units: Dictionary  # int (0-7) -> UnitData

# 商店状态
var shop_units: Array[UnitData]  # 4个槽位
var shop_refresh_cost: int

# 遗物/物品
var artifacts: Array[ArtifactData]
```

**信号：**
- `gold_changed(new_amount: int)`
- `mana_changed(current: int, maximum: int)`
- `core_health_changed(current: int, maximum: int)`
- `wave_state_changed(wave: int, is_active: bool)`

### 2. BoardController（逻辑层）

**职责：** 提供纯逻辑 API，处理所有游戏操作

**核心 API：**
```gdscript
# 商店操作
func buy_unit(shop_index: int) -> bool
func refresh_shop() -> bool
func expand_shop() -> bool

# 单位移动
func try_move_unit(from_zone: String, from_pos: Vector2i,
                   to_zone: String, to_pos: Vector2i) -> bool

# 出售单位
func sell_unit(zone: String, pos: Vector2i) -> bool

# 波次控制
func start_wave() -> bool
func retry_wave() -> void
```

**信号：**
- `unit_moved(from_zone, from_pos, to_zone, to_pos, unit_data)`
- `shop_updated(shop_units: Array[UnitData])`
- `unit_sold(zone, pos, gold_refund)`

### 3. UI 层改造

**改造原则：**
- UI 只调用 BoardController API，不直接修改数据
- UI 只监听信号来更新显示
- 删除所有直接修改 GameManager 状态的代码

**改造文件：**
- `Shop.gd` - 点击购买 → 调用 `BoardController.buy_unit()`
- `Bench.gd` - 拖拽释放 → 调用 `BoardController.try_move_unit()`
- `MainGUI.gd` - 监听 `SessionData` 信号更新资源显示

## 数据流

```
User Action -> UI Layer -> BoardController API -> SessionData (修改数据)
                                               -> 发射信号
                                               -> GridManager (实际放置/移动单位)

SessionData (数据变化) -> 发射信号 -> UI Layer (更新显示)
```

## AI Agent API

AI Agent 可以通过 WebSocket 调用 BoardController 的 API：
- `buy_unit(shop_index: int) -> bool`
- `refresh_shop() -> bool`
- `try_move_unit(from_zone, from_pos, to_zone, to_pos) -> bool`
- `sell_unit(zone, pos) -> bool`

所有 API 返回 bool 表示操作是否成功，AI 可以通过信号监听状态变化。
