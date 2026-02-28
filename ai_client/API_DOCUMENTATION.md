# Godot AI 客户端 API 参考

完整的通信协议参考文档。

## HTTP REST API（新）

### 启动方式

#### Headless 模式（默认，推荐用于训练）
```bash
python3 ai_client/ai_game_client.py
```

#### GUI 模式（用于调试观察）
```bash
python3 ai_game_client.py --visual
```

### HTTP 端点

#### POST /action

发送游戏动作，返回游戏状态。

**请求：**
```bash
curl -X POST http://127.0.0.1:<port>/action \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {"type": "buy_unit", "shop_index": 0},
      {"type": "start_wave"}
    ]
  }'
```

**正常响应：**
```json
{
  "event": "WaveStarted",
  "event_data": {"wave": 1},
  "timestamp": 1234567890,
  "global": {...},
  "board": {...}
}
```

**崩溃响应：**
```json
{
  "event": "SystemCrash",
  "error_type": "SCRIPT ERROR: ...",
  "stack_trace": "..."
}
```

#### GET /status

获取服务器状态。

**响应：**
```json
{
  "godot_running": true,
  "ws_connected": true,
  "http_port": 12345,
  "godot_ws_port": 45678,
  "visual_mode": false,
  "crashed": false
}
```

#### GET /health

健康检查。

**响应：**
```json
{"status": "ok"}
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--visual`, `--gui` | 启用 GUI 模式 | false (headless) |
| `--project`, `-p` | Godot 项目路径 | /home/zhangzhan/tower |
| `--scene`, `-s` | 启动场景 | res://src/Scenes/UI/CoreSelection.tscn |
| `--http-port` | HTTP 服务器端口 | 0 (自动分配) |
| `--godot-port` | Godot WebSocket 端口 | 0 (自动分配) |

---

## 旧版 WebSocket API

### 连接信息

| 项目 | 值 |
|------|-----|
| 协议 | WebSocket |
| 地址 | `ws://localhost:45678` |
| 消息格式 | JSON |

### 通信流程

```
游戏事件触发 → 游戏暂停 → 服务端发送状态 → 客户端决策 → 客户端发送动作 → 服务端执行 → 游戏恢复
```

---

## 服务端 → 客户端：状态消息

当游戏发生关键事件时，服务端自动暂停游戏并发送状态。

### 消息格式

```json
{
  "event": "WaveEnded",
  "event_data": {"wave": 3},
  "timestamp": 1709050000.123,
  "global": {
    "wave": 3,
    "gold": 250,
    "mana": 500.0,
    "max_mana": 1000.0,
    "core_health": 450.0,
    "max_core_health": 500.0,
    "is_wave_active": false,
    "shop_refresh_cost": 10
  },
  "board": {
    "shop": [
      {"index": 0, "unit_key": "wolf", "locked": false},
      {"index": 1, "unit_key": null, "locked": false},
      {"index": 2, "unit_key": "bat", "locked": true},
      {"index": 3, "unit_key": "meat", "locked": false}
    ],
    "bench": [
      {"index": 0, "unit": {"key": "wolf", "level": 1, "grid_pos": null}},
      {"index": 1, "unit": null},
      ...
    ],
    "grid": [
      {"position": {"x": 0, "y": 0}, "unit": {"key": "wolf", "level": 2, "grid_pos": {"x": 0, "y": 0}}}
    ]
  },
  "enemies": [
    {
      "type": "slime",
      "hp": 80.0,
      "max_hp": 100.0,
      "position": {"x": 120.5, "y": 200.0},
      "speed": 40.0,
      "state": "move",
      "debuffs": [{"type": "poison"}, {"type": "bleed", "stacks": 5}]
    }
  ]
}
```

### 字段说明

#### event (string)

| 值 | 说明 | 是否暂停 |
|-----|------|---------|
| `TotemSelection` | 图腾选择阶段 | 是 |
| `TotemSelected` | 图腾已选择 | 否 |
| `WaveStarted` | 波次开始 | 是 |
| `WaveEnded` | 波次结束 | 是 |
| `WaveReset` | 波次重置 | 否 |
| `GameOver` | 游戏结束 | 是 |
| `BossSpawned` | Boss 生成 | 是 |
| `CoreCritical` | 核心血量低于 30% | 是 |
| `AI_Wakeup` | resume 计时器到期 | 是 |
| `ActionError` | 动作执行失败 | - |

#### global (object)

| 字段 | 类型 | 说明 |
|-----|------|------|
| wave | int | 当前波次 |
| gold | int | 当前金币 |
| mana | float | 当前法力值 |
| max_mana | float | 最大法力值 |
| core_health | float | 核心当前血量 |
| max_core_health | float | 核心最大血量 |
| is_wave_active | bool | 是否处于战斗阶段 |
| shop_refresh_cost | int | 商店刷新费用 |

#### board (object)

**shop**: 商店槽位（4个槽位，索引 0-3）
```json
{
  "index": 0,
  "unit_key": "wolf",  // null 表示空
  "locked": false
}
```

**bench**: 备战区（8个槽位，索引 0-7）
```json
{
  "index": 0,
  "unit": {            // null 表示空
    "key": "wolf",
    "level": 1,
    "grid_pos": null   // 如果在网格上则是 {"x": int, "y": int}
  }
}
```

**grid**: 网格上的单位
```json
{
  "position": {"x": 0, "y": 0},
  "unit": {
    "key": "wolf",
    "level": 2,
    "grid_pos": {"x": 0, "y": 0}
  }
}
```

#### enemies (array)

仅在 `is_wave_active` 为 true 时存在。

```json
{
  "type": "slime",
  "hp": 80.0,
  "max_hp": 100.0,
  "position": {"x": 120.5, "y": 200.0},
  "speed": 40.0,
  "state": "move",
  "debuffs": [
    {"type": "poison"},
    {"type": "bleed", "stacks": 5},
    {"type": "slow"}
  ]
}
```

**state 枚举**: `move`, `attack_base`, `stunned`, `support`

**debuff 类型**:
- `{"type": "poison"}`
- `{"type": "burn"}`
- `{"type": "bleed", "stacks": int}`
- `{"type": "slow"}`
- `{"type": "stun", "duration": float}`
- `{"type": "freeze", "duration": float}`
- `{"type": "blind", "duration": float}`
- `{"type": "vulnerable"}`

---

## 客户端 → 服务端：动作消息

```json
{
  "actions": [
    {"type": "buy_unit", "shop_index": 0},
    {"type": "move_unit", "from_zone": "bench", "from_pos": 0, "to_zone": "grid", "to_pos": {"x": 2, "y": 2}},
    {"type": "resume", "wait_time": 1.0}
  ]
}
```

---

## 动作类型详解

### select_totem

选择图腾类型（游戏开始时）。

```json
{"type": "select_totem", "totem_id": "wolf_totem"}
```

**参数**:
- `totem_id`: 图腾类型，可选值：
  - `wolf_totem` - 狼图腾（进攻型）
  - `cow_totem` - 牛图腾（防御型）
  - `bat_totem` - 蝙蝠图腾（敏捷型）
  - `viper_totem` - 毒蛇图腾（毒素型）
  - `butterfly_totem` - 蝴蝶图腾（辅助型）
  - `eagle_totem` - 鹰图腾（远程型）

**前置条件**:
- 图腾选择阶段
- 战斗未开始

---

### buy_unit

购买商店单位到备战区。

```json
{"type": "buy_unit", "shop_index": 0}
```

**前置条件**:
- 非战斗阶段
- 商店槽位不为空
- 金币足够
- 备战区有空位

**错误**:
- 商店索引越界
- 战斗阶段无法购买
- 商店槽位为空
- 金币不足
- 备战区已满

---

### sell_unit

出售单位获得金币（原价的 50%）。

```json
{"type": "sell_unit", "zone": "bench", "pos": 0}
{"type": "sell_unit", "zone": "grid", "pos": {"x": 1, "y": 1}}
```

**参数**:
- `zone`: `"bench"` 或 `"grid"`
- `pos`: 备战区索引(int) 或 网格坐标 `{"x": int, "y": int}`

**前置条件**:
- 非战斗阶段
- 指定位置有单位

---

### move_unit

移动单位。

```json
{"type": "move_unit", "from_zone": "bench", "from_pos": 0, "to_zone": "grid", "to_pos": {"x": 0, "y": 0}}
```

**移动规则**:
- `bench` → `bench`: 可以交换位置
- `bench` → `grid`: 放置到网格
- `grid` → `bench`: 撤回备战区
- `grid` → `grid`: 不支持
- 相同单位（同 key + 同 level）自动合并升级

**前置条件**:
- 非战斗阶段
- 来源位置有单位
- 目标位置为空或可合并
- 网格坐标必须有效且已解锁

---

### refresh_shop

刷新商店（被锁定的槽位保留）。

```json
{"type": "refresh_shop"}
```

**前置条件**:
- 非战斗阶段
- 金币足够（默认 10）

---

### lock_shop_slot / unlock_shop_slot

锁定/解锁商店槽位。

```json
{"type": "lock_shop_slot", "shop_index": 2}
{"type": "unlock_shop_slot", "shop_index": 2}
```

---

### start_wave

开始下一波战斗。

```json
{"type": "start_wave"}
```

**前置条件**:
- 不在战斗阶段

---

### retry_wave

重试当前波次。

```json
{"type": "retry_wave"}
```

**效果**:
- 完全恢复核心血量
- 清除所有敌人

---

### resume

恢复游戏。

```json
{"type": "resume"}
{"type": "resume", "wait_time": 0.5}
```

**参数**:
- `wait_time` (可选): 秒数，计时器到期后自动触发 `AI_Wakeup` 事件

---

## 作弊指令

### cheat_add_gold

```json
{"type": "cheat_add_gold", "amount": 1000}
```

### cheat_add_mana

```json
{"type": "cheat_add_mana", "amount": 500}
```

### cheat_spawn_unit

```json
{
  "type": "cheat_spawn_unit",
  "unit_type": "wolf",
  "level": 2,
  "zone": "grid",
  "pos": {"x": 0, "y": 0}
}
```

**参数**:
- `unit_type`: 单位类型（如 "wolf", "bat", "viper"）
- `level`: 1-3
- `zone`: `"bench"` 或 `"grid"`
- `pos`: 位置

### cheat_set_time_scale

```json
{"type": "cheat_set_time_scale", "scale": 2.0}
```

**参数**:
- `scale`: 0.1 - 10.0

---

## 错误处理

动作执行失败时返回：

```json
{
  "event": "ActionError",
  "error_message": "商店索引越界: 99 (有效范围: 0-3)",
  "failed_action": {
    "type": "buy_unit",
    "shop_index": 99
  }
}
```

**规则**:
- 动作数组按顺序执行
- 任一动作失败，整个数组立即停止
- 失败动作用 `ActionError` 返回

---

## 代码示例

### Python 基础示例

```python
import asyncio
import websockets
import json

async def ai_client():
    async with websockets.connect("ws://localhost:9090") as ws:
        while True:
            # 接收状态
            state = json.loads(await ws.recv())
            print(f"Event: {state['event']}")

            # 决策
            if state['event'] == 'WaveEnded':
                actions = [
                    {"type": "buy_unit", "shop_index": 0},
                    {"type": "start_wave"}
                ]
            elif state['event'] == 'GameOver':
                break
            else:
                actions = [{"type": "resume", "wait_time": 1.0}]

            # 发送动作
            await ws.send(json.dumps({"actions": actions}))

asyncio.run(ai_client())
```

### 使用完整客户端库

```python
from ai_client.ai_game_client import AIGameClient, ActionBuilder

async def main():
    client = AIGameClient()
    await client.connect()

    state = await client.receive_state()
    print(f"Gold: {client.get_gold()}")

    await client.send_actions([
        ActionBuilder.buy_unit(0),
        ActionBuilder.move_unit("bench", 0, "grid", {"x": 0, "y": 0}),
        ActionBuilder.start_wave()
    ])
```
