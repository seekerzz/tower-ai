# Godot AI 游戏客户端

外部 AI 控制 Godot 游戏的完整方案。

## 目录结构

```
ai_client/                       # Python 客户端代码
├── README.md                    # 本文件（主入口）
├── API_DOCUMENTATION.md         # 完整 API 参考
├── QUICKSTART.md                # 快速入门指南
├── run_visual.py                # 一键启动脚本（游戏窗口+AI）
├── ai_game_client.py            # 完整客户端实现（可直接使用）
├── example_minimal.py           # 极简示例（30行代码）
└── example_with_cheats.py       # 作弊模式示例（快速体验）

src/Autoload/                    # Godot 服务端代码
├── AILogger.gd                 # 中文日志系统
├── AIManager.gd                # WebSocket 服务端
└── AIActionExecutor.gd         # 动作执行器
```

## 快速开始

### 方式1：可视化运行（推荐）
同时看到游戏画面和 AI 决策日志：

```bash
cd ai_client

# 使用脚本一键启动（自动启动 Godot 游戏窗口 + AI 客户端）
# 默认从 CoreSelection.tscn 场景开始，AI 会选择图腾后进入游戏
python3 run_visual.py

# 或者指定其他场景
python3 run_visual.py --scene res://src/Scenes/Game/MainGame.tscn

# 或者带作弊功能快速体验
python3 run_visual.py --ai cheat
```

### 方式2：手动运行（带UI版本）

如果你想同时看到游戏画面和AI决策过程，使用以下步骤：

**步骤1 - 启动 Godot 游戏（带图形界面）：**
```bash
cd /home/zhangzhan/tower
# 从CoreSelection场景开始，AI会自动选择图腾
godot --path . res://src/Scenes/UI/CoreSelection.tscn --ai-mode
```
*注意：这会启动AI图腾选择场景，等待AI连接*

**步骤2 - 在另一个终端运行 AI 客户端：**
```bash
cd /home/zhangzhan/tower/ai_client
python3 example_minimal.py
```

**你会看到：**
- Godot窗口：显示图腾选择 → 进入游戏 → 波次战斗
- 终端输出：彩色中文日志，显示AI接收事件和发送动作

**手动操作验证步骤：**
1. 启动Godot后，等待"等待AI客户端连接..."消息
2. 启动AI客户端，观察连接成功日志
3. 在Godot窗口中你应该看到：
   - 图腾选择界面（自动跳过，AI选择）
   - 主游戏场景加载
   - 商店界面和战斗场景
4. 在终端中观察AI决策过程（选择图腾、开始波次等）

### 方式3：无界面运行（仅 AI 测试）
```bash
# 终端1
godot --headless --path .

# 终端2
cd ai_client
python3 example_minimal.py
```

## 核心概念

### 通信流程
1. 游戏事件触发 → 游戏暂停 → 服务端发送状态 JSON
2. AI 客户端接收状态 → 做出决策 → 发送动作 JSON
3. 服务端执行动作 → 返回结果 → 恢复游戏

### 连接信息
- 地址: `ws://localhost:9090`
- 格式: JSON

### 完整游戏流程示例
```python
import asyncio, websockets, json

async def ai():
    async with websockets.connect("ws://localhost:9090") as ws:
        while True:
            state = json.loads(await ws.recv())
            event = state["event"]
            actions = []

            if event == "TotemSelection":
                # 1. 选择图腾（游戏开始）
                available = state.get("available_totems", [])
                selected = available[0] if available else "wolf_totem"
                print(f"选择图腾: {selected}")
                actions = [{"type": "select_totem", "totem_id": selected}]

            elif event == "WaveEnded":
                # 2. 购买单位并布置
                print(f"金币: {state['global']['gold']}")
                actions = [
                    {"type": "buy_unit", "shop_index": 0},
                    {"type": "move_unit", "from_zone": "bench", "from_pos": 0,
                     "to_zone": "grid", "to_pos": {"x": 0, "y": 0}},
                    {"type": "start_wave"}
                ]

            elif event == "GameOver":
                print("游戏结束!")
                break

            else:
                actions = [{"type": "resume", "wait_time": 1.0}]

            await ws.send(json.dumps({"actions": actions}))

asyncio.run(ai())
```

## 文档导航

| 需求 | 阅读文档 |
|------|----------|
| 5分钟快速上手 | [QUICKSTART.md](QUICKSTART.md) |
| 完整协议参考 | [API_DOCUMENTATION.md](API_DOCUMENTATION.md) |
| 使用完整客户端库 | [ai_game_client.py](ai_game_client.py) |

## 核心动作

| 动作 | 示例 |
|------|------|
| 选择图腾 | `{"type": "select_totem", "totem_id": "wolf_totem"}` |
| 购买单位 | `{"type": "buy_unit", "shop_index": 0}` |
| 移动单位 | `{"type": "move_unit", "from_zone": "bench", "from_pos": 0, "to_zone": "grid", "to_pos": {"x": 0, "y": 0}}` |
| 出售单位 | `{"type": "sell_unit", "zone": "bench", "pos": 0}` |
| 刷新商店 | `{"type": "refresh_shop"}` |
| 开始波次 | `{"type": "start_wave"}` |
| 恢复游戏 | `{"type": "resume", "wait_time": 0.5}` |

### 可用图腾

| 图腾 | 类型 |
|------|------|
| `wolf_totem` | 狼图腾（进攻型） |
| `cow_totem` | 牛图腾（防御型） |
| `bat_totem` | 蝙蝠图腾（敏捷型） |
| `viper_totem` | 毒蛇图腾（毒素型） |
| `butterfly_totem` | 蝴蝶图腾（辅助型） |
| `eagle_totem` | 鹰图腾（远程型） |

## 游戏事件

| 事件 | 说明 |
|------|------|
| `TotemSelection` | 图腾选择阶段（游戏开始） |
| `TotemSelected` | 图腾已选择（可开始第一波） |
| `WaveEnded` | 波次结束（购买阶段） |
| `WaveStarted` | 波次开始 |
| `BossSpawned` | Boss 生成 |
| `CoreCritical` | 核心血量低于 30% |
| `AI_Wakeup` | resume 延时到期 |
| `GameOver` | 游戏结束 |

## 完整客户端使用

```python
from ai_client.ai_game_client import AIGameClient, ActionBuilder, run_ai_game, SimpleAI

# 方式1: 使用内置 AI
asyncio.run(run_ai_game())

# 方式2: 自定义 AI
class MyAI(SimpleAI):
    async def make_decision(self, state):
        actions = []
        if state.event == "WaveEnded":
            # 只买 wolf
            shop = self.client.get_shop_units()
            for slot in shop:
                if slot.unit_key == "wolf":
                    actions.append(ActionBuilder.buy_unit(slot.index))
            actions.append(ActionBuilder.start_wave())
        elif state.is_wave_active:
            actions.append(ActionBuilder.resume(wait_time=1.0))
        return actions

asyncio.run(run_ai_game(ai_class=MyAI))
```

## 状态结构

```json
{
  "event": "WaveEnded",
  "global": {
    "wave": 3,
    "gold": 250,
    "mana": 500,
    "max_mana": 1000,
    "core_health": 450,
    "max_core_health": 500,
    "is_wave_active": false
  },
  "board": {
    "shop": [{"index": 0, "unit_key": "wolf", "locked": false}],
    "bench": [{"index": 0, "unit": {"key": "wolf", "level": 1}}],
    "grid": [{"position": {"x": 0, "y": 0}, "unit": {"key": "bat", "level": 2}}]
  },
  "enemies": [
    {"type": "slime", "hp": 80, "max_hp": 100, "position": {"x": 100, "y": 200}}
  ]
}
```

## 调试技巧

Godot 服务端输出彩色中文日志：
- 🔵 蓝色：网络日志
- 🟢 绿色：事件日志
- 🟠 橙色：动作日志
- 🔴 红色：错误日志
