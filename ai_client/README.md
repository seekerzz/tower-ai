# Godot AI 客户端网关

Tower-AI 的自动化测试基础设施，通过 HTTP/WebSocket 与 Godot 游戏交互，实现非阻塞的实时游戏测试。

## 架构概览

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          测试脚本层 (Python)                               │
│     first_wave_coverage_runner.py / 自定义测试脚本 / AI Agent              │
├──────────────────────────────────────────────────────────────────────────┤
│                          HTTP REST API (aiohttp)                          │
│                   POST /action  |  GET /observations  |  GET /status       │
├──────────────────────────────────────────────────────────────────────────┤
│                         AI Client 网关 (Python)                           │
│    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │
│    │ GodotProcess │  │  WebSocket   │  │ EventBuffer  │  │ ActionQueue │  │
│    │   进程管理   │  │   客户端     │  │  事件缓冲    │  │   动作队列   │  │
│    └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘  │
├──────────────────────────────────────────────────────────────────────────┤
│                         WebSocket 协议                                    │
├──────────────────────────────────────────────────────────────────────────┤
│                         Godot 游戏核心                                    │
│    AIManager ←→ ActionDispatcher ←→ GameManager / BoardController        │
│         ↓              ↓                        ↓                         │
│    WebSocket      动作路由              AIEventsTracker                   │
│                                                    ↓                      │
│                                              事件收集广播                  │
└──────────────────────────────────────────────────────────────────────────┘
```

## 核心能力

- **非阻塞动作提交**: `POST /action` 立即返回 ACK，不等待执行
- **异步执行调度**: 动作进入队列，在 `next_safe_tick` 时转发到 Godot
- **结构化事件流**: `GET /observations` 支持 cursor (`after_seq`)，可断点续拉
- **事件持久化**: 全部事件实时写入 `logs/ai_session_<session_id>.jsonl`
- **崩溃检测**: 自动检测 Godot 进程崩溃并生成 `system_crash` 事件
- **问题分级**: `warning` / `runtime_error` / `fatal(system_crash)`

## 快速开始

### 1. 启动网关

```bash
python3 ai_client/ai_game_client.py \
  --project . \
  --scene res://src/Scenes/UI/CoreSelection.tscn \
  --http-port 8080
```

参数说明：
- `--project`: Godot 项目路径
- `--scene`: 启动场景（推荐 CoreSelection.tscn）
- `--http-port`: HTTP API 端口（默认 8080）

### 2. 提交动作（异步）

```bash
curl -X POST http://127.0.0.1:8080/action \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "demo-1",
    "apply_mode": "next_safe_tick",
    "ttl_ms": 30000,
    "actions": [
      {"type": "select_totem", "totem_id": "wolf_totem"},
      {"type": "cheat_set_shop_unit", "shop_index": 0, "unit_key": "wolf"},
      {"type": "buy_unit", "shop_index": 0},
      {"type": "start_wave"}
    ]
  }'
```

### 3. 拉取观测事件

```bash
curl "http://127.0.0.1:8080/observations?after_seq=0&limit=200&wait_ms=200"
```

### 4. 查看网关状态

```bash
curl http://127.0.0.1:8080/status
```

### 5. 运行第一波覆盖测试

```bash
# 基础测试（狼图腾 + 老虎单位）
python3 ai_client/first_wave_coverage_runner.py \
  --base-url http://127.0.0.1:8080 \
  --totems "wolf_totem" \
  --combos "wolf|tiger"

# 完整测试（所有图腾 × 多个单位组合）
python3 ai_client/first_wave_coverage_runner.py \
  --base-url http://127.0.0.1:8080
```

报告输出：`logs/coverage_report.json`

## 文件结构

```
ai_client/
├── README.md                   # 本文档（快速开始和架构概览）
├── API_DOCUMENTATION.md        # 完整 API 参考
│
├── ai_game_client.py           # 主网关程序
├── first_wave_coverage_runner.py  # 第一波覆盖测试
├── godot_process.py            # Godot 进程管理
├── http_server.py              # HTTP REST API 服务器
└── utils.py                    # 工具函数
```

## 关键概念

### 动作 (Action)

通过 HTTP POST 提交到 `/action` 的游戏操作指令。常见动作类型：

| 动作类型 | 说明 | 必需参数 |
|---------|------|---------|
| `select_totem` | 选择图腾 | `totem_id` |
| `buy_unit` | 购买商店单位 | `shop_index` |
| `sell_unit` | 出售棋盘单位 | `grid_pos` |
| `move_unit` | 移动单位 | `from_pos`, `to_pos` |
| `refresh_shop` | 刷新商店 | - |
| `start_wave` | 开始波次 | - |
| `cheat_set_shop_unit` | 设置商店单位（测试用） | `shop_index`, `unit_key` |
| `cheat_set_gold` | 设置金币（测试用） | `amount` |
| `cheat_upgrade_unit` | 升级单位（测试用） | `grid_pos` |

### 事件 (Event)

从 `/observations` 获取的游戏状态变化通知。关键事件类型：

**网关事件**:
- `godot_ready` - Godot 进程启动完成
- `ws_connected` / `ws_disconnected` - WebSocket 连接状态

**调度器事件**:
- `action_submitted` - 动作已提交到队列
- `action_forwarded` - 动作已转发到 Godot
- `action_rejected_*` - 动作被拒绝（过期/队列满/未连接）

**游戏事件**:
- `game_TotemSelected` - 图腾选择成功
- `game_WaveStarted` / `game_WaveEnded` - 波次状态变化
- `game_ActionResult` / `game_ActionError` - 动作执行结果
- `game_DamageDealt` / `game_EnemyHit` - 战斗事件
- `game_SkillActivated` / `game_BuffApplied` - 技能/增益事件

**错误事件**:
- `godot_warning` / `godot_runtime_error` - Godot 警告/错误
- `system_crash` - 游戏崩溃

### 游标 (Cursor)

`/observations` 使用 `after_seq` 游标实现断点续拉：

1. 首次请求：`after_seq=0`，获取 seq > 0 的事件
2. 记录返回的 `next_seq` 作为下次请求的 `after_seq`
3. 即使断开连接，也可从上次位置继续拉取

## 调试技巧

1. **查看实时事件日志**:
   ```bash
   tail -f logs/ai_session_*.jsonl | jq '{seq, event_type, source}'
   ```

2. **检查 Godot 输出**:
   网关会打印所有 Godot stdout，查找 `[Godot]` 前缀。

3. **崩溃分析**:
   崩溃时会在事件日志中记录 `system_crash` 事件，包含完整堆栈。

4. **连接问题排查**:
   - 检查 `/status` 端点确认 WebSocket 连接状态
   - 查看 `ws_connected` / `ws_disconnected` 事件

## 详细文档

- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - 完整 API 参考

---

*文档版本: 2.0*
*最后更新: 2026-03-16*
