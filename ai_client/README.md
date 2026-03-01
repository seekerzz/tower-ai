# Godot AI 游戏客户端 - HTTP REST API 网关

外部 AI 控制 Godot 游戏的 HTTP REST API 方案。支持动态端口、Headless/GUI 双模式、崩溃检测。

> ⚠️ **【强制阅读】AI Agent 必须阅读的文件**
>
> 在控制游戏之前，**AI 必须阅读 `docs/GameDesign.md`**，否则将因不了解以下机制而做出错误决策：
> - 血量计算规则（单位 HP 影响核心血量）
> - 放置规则（扩建限制、相邻规则）
> - BUFF 传播机制（范围 1 格，需手动选择目标）
> - 击退抗性与碰撞伤害
> - 敌人属性查表方式
>
> **如未阅读该文档，请勿开始游戏。**

## 功能特性

- **HTTP REST API**: 通过 HTTP 接收动作请求，返回游戏状态
- **动态端口分配**: 自动寻找可用端口，避免冲突
- **双模式启动**: 支持 Headless（无头）和 GUI（图形界面）模式
- **崩溃检测**: 实时监控 Godot 输出，捕获 SCRIPT ERROR 等崩溃
- **进程管理**: 自动启动、监控和清理 Godot 进程

## 目录结构

```
ai_client/
├── README.md                    # 本文件
├── API_DOCUMENTATION.md         # 完整 API 参考
├── ai_game_client.py            # 主程序（HTTP 网关）
├── godot_process.py             # Godot 进程管理器
├── http_server.py               # HTTP REST 服务器
└── utils.py                     # 工具函数
```

## 快速开始

### 方式1：Headless 模式（推荐用于训练）

```bash
cd /mnt/f/Desktop/tower-ai
python3 ai_client/ai_game_client.py
```

输出示例：
```
============================================================
Godot AI 客户端已启动 - Headless 模式
============================================================
HTTP 端口: 10000
Godot WebSocket 端口: 10001

使用示例:
  curl -X POST http://127.0.0.1:10000/action \
       -H "Content-Type: application/json" \
       -d '{"actions": [{"type": "start_wave"}]}'

按 Ctrl+C 停止
============================================================
```

### 方式2：GUI 模式（用于调试观察）

```bash
python3 ai_client/ai_game_client.py --visual
```

### 使用 curl 发送请求

```bash
# 获取状态
curl http://127.0.0.1:<port>/status

# 发送动作
curl -X POST http://127.0.0.1:<port>/action \
  -H "Content-Type: application/json" \
  -d '{"actions": [{"type": "select_totem", "totem_id": "wolf_totem"}]}'
```

## HTTP API

### POST /action

发送游戏动作，返回游戏状态。

**请求体：**
```json
{
  "actions": [
    {"type": "buy_unit", "shop_index": 0},
    {"type": "start_wave"}
  ]
}
```

**响应（请求已透传给游戏，不等待结果）：**
```json
{
  "status": "ok",
  "message": "Actions sent"
}
```

> **注意：** 该 API 不再同步返回游戏状态，游戏状态流将通过 Python 控制台标准输出 (stdout) 或保存在 `logs/ai_session_*.log` 日志文件里，供 AI 实时读取。

**崩溃响应：**
```json
{
  "event": "SystemCrash",
  "error_type": "SCRIPT ERROR: ...",
  "stack_trace": "..."
}
```

### GET /status

获取服务器和 Godot 进程状态。

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

### GET /health

健康检查。

**响应：**
```json
{"status": "ok"}
```

## 命令行参数

```
python3 ai_game_client.py [选项]

选项:
  --visual, --gui       启用 GUI 模式（显示游戏窗口）
  --project PATH, -p PATH
                        Godot 项目路径 (默认: /mnt/f/Desktop/tower-ai)
  --scene PATH, -s PATH
                        启动场景路径 (默认: res://src/Scenes/UI/CoreSelection.tscn)
  --http-port PORT      HTTP 服务器端口 (0=自动分配)
  --godot-port PORT     Godot WebSocket 端口 (0=自动分配)
```

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

### 作弊指令（测试用）

| 动作 | 示例 | 说明 |
|------|------|------|
| 添加金币 | `{"type": "cheat_add_gold", "amount": 100}` | 添加指定数量金币 |
| 添加法力 | `{"type": "cheat_add_mana", "amount": 100}` | 添加指定数量法力 |
| 生成单位 | `{"type": "cheat_spawn_unit", "unit_type": "wolf", "level": 1, "zone": "bench", "pos": 0}` | 在指定位置生成单位 |
| 设置商店单位 | `{"type": "cheat_set_shop_unit", "shop_index": 0, "unit_key": "wolf"}` | 设置商店指定槽位为单位 |
| 设置时间流速 | `{"type": "cheat_set_time_scale", "scale": 2.0}` | 设置游戏时间流速（0.1-10.0） |

### 技能指令

| 动作 | 示例 | 说明 |
|------|------|------|
| 使用技能 | `{"type": "use_skill", "grid_pos": {"x": 0, "y": 1}}` | 触发指定位置单位的主动技能 |
| 获取单位信息 | `{"type": "get_unit_info", "grid_pos": {"x": 0, "y": 1}}` | 获取单位的详细属性、技能和 buff 信息 |

**单位信息返回示例：**
```json
{
  "event": "ActionsCompleted",
  "unit_info": {
    "type_key": "tiger",
    "level": 2,
    "hp": 150,
    "max_hp": 200,
    "damage": 45,
    "atk_speed": 1.2,
    "range": 120,
    "crit_rate": 0.15,
    "skill": {
      "name": "roar",
      "cooldown": 0,
      "max_cooldown": 15.0,
      "mana_cost": 50,
      "ready": true
    },
    "buffs": ["range", "speed"],
    "temporary_buffs": [{"stat": "damage", "amount": 10, "duration": 5.0}]
  }
}
```

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
| `CoreDamaged` | 核心受到攻击（血量 >= 30%） |
| `CoreCritical` | 核心血量低于 30% |
| `TrapPlaced` | 毒陷阱已放置 |
| `TrapTriggered` | 毒陷阱被触发 |
| `AI_Wakeup` | resume 延时到期 |
| `GameOver` | 游戏结束 |
| `SystemCrash` | Godot 崩溃（Python 端检测） |

## 敌人信息

仅在 `is_wave_active` 为 true 时，状态消息会包含 `enemies` 数组。

**设计理念：** 只传递敌人的**名字**和**动态信息**，AI 可通过查表获取敌人的静态属性。

```json
{
  "enemies": [
    {
      "name": "slime",
      "hp": 80.0,
      "position": {"x": 120.5, "y": 200.0},
      "state": "move",
      "split_generation": 0,
      "debuffs": [
        {"type": "poison", "stacks": 3},
        {"type": "bleed", "stacks": 5}
      ]
    }
  ]
}
```

**传递的字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | **敌人名字**，用于查表获取完整属性 |
| `hp` | float | 当前血量（动态） |
| `position` | object | 位置坐标 {"x": float, "y": float}（动态） |
| `state` | string | 状态：move, attack_base, stunned, support（动态） |
| `is_charmed` | bool | 是否被魅惑（动态） |
| `split_generation` | int | 史莱姆分裂代数（动态） |
| `debuffs` | array | Debuff 列表，包含 type 和 stacks（动态） |

**debuff 类型：**
- `poison` - 中毒
- `burn` - 燃烧
- `bleed` - 流血
- `slow` - 减速
- `stun` - 眩晕
- `freeze` - 冻结
- `blind` - 失明
- `vulnerable` - 易伤

**AI 查表获取的静态属性：**

通过 `name` 字段查询 `data/game_data.json` 中的 `ENEMY_TYPES`，可获取：
- `max_hp` - 最大血量
- `damage` - 攻击力
- `speed` - 移动速度
- `attack_speed` - 攻击速度
- `attack_type` - 攻击类型（melee/ranged）
- `range` - 远程射程
- `is_boss` - 是否为 Boss
- `is_suicide` - 是否自爆
- `radius` - 碰撞半径
- 等等...

## 测试

### 崩溃检测测试

```bash
# 使用 TestCrash 场景（主动触发 GDScript 错误）
python3 ai_client/ai_game_client.py --scene res://src/Scenes/Test/TestCrash.tscn --visual
```

预期输出包含 `SystemCrash` 事件。

### 完整测试套件

```bash
python3 tests/test_crash_detection.py
```

## AI 玩家必读

**⚠️ 以下机制必须在阅读 `docs/GameDesign.md` 后才能理解，AI 不得在未阅读的情况下做出决策：**

| 机制类别 | 关键信息 |
|----------|----------|
| **核心机制** | 血量计算公式（500 + 单位HP总和）、法力回复规则（战斗中10/秒，波次结束回满）、金币获取（击杀+1，波次结束20+波次×5） |
| **放置规则** | 初始5×5中心区域可扩建，每次扩建+10金币成本，只能扩建与已解锁格子相邻的位置 |
| **BUFF系统** | 范围1格内传播，放置后需手动选择目标单位赋予；部分BUFF可叠加（bounce/split），部分不可 |
| **击退机制** | 不同敌人有不同击退抗性（Boss/坦克抗性10.0），击退可触发墙撞伤害和连锁碰撞 |
| **单位强度** | 商店价格反映基础强度，升级规则：3个同名同等级单位自动合成，吞噬传承属性比例 |
| **敌人威胁** | 通过 `name` 查表 `data/game_data.json` 获取静态属性（max_hp, damage, speed, is_boss等） |

## 文档导航

| 需求 | 阅读文档 |
|------|----------|
| 完整协议参考 | [API_DOCUMENTATION.md](API_DOCUMENTATION.md) |
| 游戏机制详解 | [../docs/GameDesign.md](../docs/GameDesign.md) |

## 架构 (Hybrid Gateway)

```
┌─────────────────────────────────────────────────────────────┐
│                    ai_game_client.py                        │
│                                                             │
│  [上行链路：动作执行]                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  HTTP Server │◄───│  POST /action│◄───│ 外部 curl    │   │
│  │  (动态分配)  │    │  即刻返回 200│    │ (无状态发送) │   │
│  └──────────────┘    └──────┬───────┘    └──────────────┘   │
│                             │                               │
│  [下行链路：状态观测]       │                               │
│  ┌──────────────┐    ┌──────▼───────┐                       │
│  │ Stdout/Logs  │◄───│ WebSocket    │                       │
│  │ (AI 读取状态)│    │ Client       │                       │
│  └──────────────┘    └──────┬───────┘                       │
│                             │                               │
│  ┌──────────────────────────┼──────────────────────────┐    │
│  │    Godot 子进程          │                          │    │
│  │  ┌───────────────────────┴──────────────────────┐   │    │
│  │  │   AIManager.gd / WebSocket Srv               │   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 调试技巧

Godot 服务端输出彩色中文日志：
- 🔵 蓝色：网络日志
- 🟢 绿色：事件日志
- 🟠 橙色：动作日志
- 🔴 红色：错误日志
