# Godot AI 客户端（实时非阻塞网关）

该客户端将 Godot WebSocket 服务包装为 HTTP API，目标是让 AI Agent 在**不打断实时游戏**的前提下做决策、观测和自动化测试。

## 核心能力

- 非阻塞动作提交：`POST /action` 立即 ACK。
- 异步执行调度：动作先进入队列，再在 `next_safe_tick` 转发。
- 结构化事件流：`GET /observations` 支持 cursor (`after_seq`)。涵盖所有游戏动作与机制结算（伤害、Buff、技能施放等）。
- 事件持久化：全部事件实时写入 `logs/ai_session_<session_id>.jsonl`。
- 问题分级：`warning / runtime_error / fatal(system_crash)`。

## 快速启动

### 1) 启动网关

```bash
python3 ai_client/ai_game_client.py --project . --scene res://src/Scenes/UI/CoreSelection.tscn --http-port 8080
```

### 2) 提交动作（异步）

```bash
curl -X POST http://127.0.0.1:8080/action \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "demo-1",
    "apply_mode": "next_safe_tick",
    "ttl_ms": 30000,
    "actions": [
      {"type": "select_totem", "totem_id": "wolf_totem"},
      {"type": "start_wave"}
    ]
  }'
```

### 3) 拉取观测（可回放）

```bash
curl "http://127.0.0.1:8080/observations?after_seq=0&limit=200&wait_ms=200"
```

### 4) 查看状态

```bash
curl http://127.0.0.1:8080/status
```

### 5) 运行第一波覆盖测试

```bash
python3 ai_client/first_wave_coverage_runner.py --base-url http://127.0.0.1:8080
```

报告输出：`logs/coverage_report.json`

---

## API 文档

详细 API 参考参见：[API_DOCUMENTATION.md](API_DOCUMENTATION.md)

### 关键端点概览

| 端点 | 方法 | 说明 |
|------|------|------|
| `/action` | POST | 提交动作意图到异步调度队列 |
| `/observations` | GET | 拉取结构化事件流，支持 `after_seq` 游标 |
| `/status` | GET | 查看网关和游戏状态 |

### 关键事件类型

- `action_submitted` / `action_forwarded` / `action_rejected_*`
- `game_TotemSelected` / `game_WaveStarted` / `game_WaveEnded`
- `game_ActionResult` / `game_ActionError`
- `game_DamageDealt` / `game_EnemyHit`（战斗机制事件）
- `game_SkillActivated` / `game_BuffApplied`
- `godot_warning` / `godot_runtime_error` / `system_crash`
