# Godot AI 客户端 API 参考（Non-Blocking）

本版本协议强调：**游戏主循环不等待 AI，不暂停战斗**。

## 启动

```bash
python3 ai_client/ai_game_client.py --project . --scene res://src/Scenes/UI/CoreSelection.tscn --http-port 8080
```

## 设计原则

- `/action` 仅做“意图提交”，立即返回 ACK。
- 真实执行结果、游戏事件、错误信息均从 `/observations` 获取。
- `/observations` 支持 `after_seq` cursor，断线可续拉。

---

## POST /action

提交动作意图到异步调度队列。

### 请求体

```json
{
  "request_id": "optional-custom-id",
  "apply_mode": "next_safe_tick",
  "ttl_ms": 30000,
  "actions": [
    {"type": "buy_unit", "shop_index": 0},
    {"type": "start_wave"}
  ]
}
```

### 响应

```json
{
  "status": "accepted",
  "request_id": "c1f...",
  "accepted_at": 1730000000000,
  "queue_depth": 2,
  "estimated_apply_tick": "next_safe_tick"
}
```

可能的拒绝：

```json
{
  "status": "rejected",
  "reason": "queue_full",
  "request_id": "...",
  "queue_depth": 1000
}
```

---

## GET /observations

拉取结构化事件流。

### Query

- `after_seq`：返回大于该序号的事件（默认 0）
- `limit`：最多返回条数（默认 200，最大 2000）
- `wait_ms`：长轮询等待毫秒（默认 0，最大 30000）

### 响应

```json
{
  "session_id": "20260101_120000_ab12cd34",
  "events": [
    {
      "seq": 101,
      "session_id": "20260101_120000_ab12cd34",
      "ts_ms": 1730000000201,
      "source": "gateway",
      "event_type": "action_submitted",
      "payload": {"actions": [{"type": "start_wave"}]},
      "request_id": "req-1"
    }
  ],
  "next_seq": 101,
  "has_more": false,
  "buffer_tail_seq": 101
}
```

---

## GET /status

```json
{
  "godot_running": true,
  "ws_connected": true,
  "session_id": "...",
  "action_queue_depth": 0,
  "event_buffer_size": 120,
  "next_seq": 121,
  "crashed": false
}
```

---

## 关键事件类型

- `action_submitted`
- `action_forwarded`
- `action_rejected_expired`
- `action_rejected_ws_not_connected`
- `action_forward_failed`
- `game_TotemSelected`
- `game_WaveStarted`
- `game_WaveEnded`
- `game_ActionResult`
- `game_ActionError`
- `godot_warning`
- `godot_runtime_error`
- `system_crash`

### 结构化事件负载（新增）

Godot 侧现在会主动发送 JSON 事件：

```json
{
  "event": "ActionResult",
  "data": {
    "request_id": "req-1",
    "action_index": 0,
    "action_type": "buy_unit",
    "action": {"type": "buy_unit", "shop_index": 0},
    "result": {"success": true},
    "snapshot": {
      "wave": 1,
      "is_wave_active": false,
      "gold": 8,
      "mana": 0,
      "core_health": 100
    }
  },
  "request_id": "req-1",
  "ts_ms": 12345678
}
```

在网关 `/observations` 中会映射为 `event_type = "game_ActionResult"`（或 `game_ActionError`）。

---

## 第一波覆盖测试

使用 `first_wave_coverage_runner.py` 执行图腾 × 单位组合测试并生成报告：

```bash
python3 ai_client/first_wave_coverage_runner.py --base-url http://127.0.0.1:8080
```

输出文件默认：`logs/coverage_report.json`。
