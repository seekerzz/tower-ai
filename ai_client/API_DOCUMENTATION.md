# AI Client API 参考文档

Tower-AI HTTP/WebSocket 网关完整 API 参考。

**设计原则**:
- `/action` 仅做"意图提交"，立即返回 ACK
- 真实执行结果、游戏事件、错误信息均从 `/observations` 获取
- `/observations` 支持 `after_seq` cursor，断线可续拉

---

## 基础 URL

```
http://127.0.0.1:8080  (默认端口，可通过 --http-port 修改)
```

---

## POST /action

提交动作意图到异步调度队列。

### 请求

**Headers**:
```
Content-Type: application/json
```

**Body**:
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

**字段说明**:

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `request_id` | string | 否 | 自定义请求 ID，用于追踪 |
| `apply_mode` | string | 否 | 应用模式，目前仅支持 `next_safe_tick` |
| `ttl_ms` | int | 否 | 动作过期时间（毫秒），默认 30000 |
| `actions` | array | 是 | 动作列表，按顺序执行 |

### 响应（成功）

```json
{
  "status": "accepted",
  "request_id": "c1f...",
  "accepted_at": 1730000000000,
  "queue_depth": 2,
  "estimated_apply_tick": "next_safe_tick"
}
```

### 响应（拒绝）

```json
{
  "status": "rejected",
  "reason": "queue_full",
  "request_id": "...",
  "queue_depth": 1000
}
```

**拒绝原因**:
- `queue_full` - 队列已满
- `ws_not_connected` - WebSocket 未连接
- `invalid_actions` - 动作格式无效

---

## GET /observations

拉取结构化事件流。

### Query 参数

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `after_seq` | int | 否 | 返回大于该序号的事件，默认 0 |
| `limit` | int | 否 | 最多返回条数，默认 200，最大 2000 |
| `wait_ms` | int | 否 | 长轮询等待毫秒，默认 0，最大 30000 |

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
    },
    {
      "seq": 102,
      "session_id": "20260101_120000_ab12cd34",
      "ts_ms": 1730000000250,
      "source": "godot_ws",
      "event_type": "game_WaveStarted",
      "payload": {"wave": 1}
    }
  ],
  "next_seq": 103,
  "has_more": false,
  "buffer_tail_seq": 150
}
```

**字段说明**:

| 字段 | 说明 |
|------|------|
| `seq` | 全局递增的事件序号 |
| `ts_ms` | 时间戳（毫秒） |
| `source` | 事件来源：`gateway`, `scheduler`, `godot_ws` |
| `event_type` | 事件类型（见下表） |
| `payload` | 事件负载 |
| `request_id` | 关联的请求 ID（如有） |
| `next_seq` | 下次请求应使用的 `after_seq` |
| `has_more` | 是否还有更多事件 |
| `buffer_tail_seq` | 缓冲区最新事件序号 |

---

## GET /status

查看网关和游戏状态。

### 响应

```json
{
  "godot_running": true,
  "ws_connected": true,
  "session_id": "20260101_120000_ab12cd34",
  "action_queue_depth": 0,
  "event_buffer_size": 120,
  "next_seq": 121,
  "crashed": false
}
```

---

## GET /health

健康检查端点。

### 响应

```json
{
  "status": "ok"
}
```

---

## 事件类型详解

### 网关事件

| 事件类型 | 说明 | payload 示例 |
|---------|------|-------------|
| `godot_ready` | Godot 进程启动完成 | `{"pid": 12345}` |
| `ws_connected` | WebSocket 连接成功 | `{"uri": "ws://127.0.0.1:12345"}` |
| `ws_disconnected` | WebSocket 断开连接 | `{"code": 1000, "reason": ""}` |
| `http_started` | HTTP 服务器启动 | `{"port": 8080}` |

### 调度器事件

| 事件类型 | 说明 | payload 示例 |
|---------|------|-------------|
| `action_submitted` | 动作已提交到队列 | `{"actions": [...], "queue_depth": 1}` |
| `action_forwarded` | 动作已转发到 Godot | `{"actions": [...]}` |
| `action_rejected_expired` | 动作过期被拒绝 | `{"reason": "expired"}` |
| `action_rejected_backpressure` | 队列满被拒绝 | `{"reason": "queue_full"}` |
| `action_rejected_ws_not_connected` | WebSocket 未连接 | `{"reason": "ws_not_connected"}` |
| `action_forward_failed` | 转发到 Godot 失败 | `{"error": "..."}` |

### 游戏事件

| 事件类型 | 说明 |
|---------|------|
| `game_TotemSelected` | 图腾选择成功 |
| `game_WaveStarted` | 波次开始 |
| `game_WaveEnded` | 波次结束 |
| `game_ActionResult` | 动作执行成功 |
| `game_ActionError` | 动作执行失败 |
| `game_DamageDealt` | 造成伤害 |
| `game_EnemyHit` | 敌人受击 |
| `game_SkillActivated` | 技能激活 |
| `game_SkillUsed` | 技能使用 |
| `game_BuffApplied` | 增益应用 |
| `game_DebuffApplied` | 减益应用 |

### 错误事件

| 事件类型 | 说明 |
|---------|------|
| `godot_warning` | Godot 警告信息 |
| `godot_runtime_error` | Godot 运行时错误 |
| `system_crash` | 游戏崩溃 |

---

## 结构化事件负载

### game_ActionResult

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

### game_EnemyHit

```json
{
  "event": "EnemyHit",
  "data": {
    "target_enemy": {"type": "slime", "id": "123456", "position": {"x": 100, "y": 200}},
    "source_unit": {"type": "snowman", "id": "78910", "grid_pos": {"x": -1, "y": 0}},
    "amount": 25.0
  },
  "ts_ms": 12345678
}
```

### system_crash

```json
{
  "event": "SystemCrash",
  "data": {
    "error_type": "NullReference",
    "message": "Attempted to access a null instance",
    "stack_trace": "...",
    "timestamp": "2026-03-16T10:30:00Z"
  },
  "ts_ms": 12345678
}
```

---

## 动作类型参考

### 游戏动作

| 动作类型 | 参数 | 说明 |
|---------|------|------|
| `select_totem` | `totem_id`: string | 选择图腾（wolf_totem, cow_totem, bat_totem 等） |
| `buy_unit` | `shop_index`: int | 购买商店指定位置的单位 |
| `sell_unit` | `grid_pos`: {x, y} | 出售指定位置的单位 |
| `move_unit` | `from_pos`, `to_pos`: {x, y} | 移动单位 |
| `refresh_shop` | - | 刷新商店 |
| `start_wave` | - | 开始波次战斗 |

### 测试作弊动作

| 动作类型 | 参数 | 说明 |
|---------|------|------|
| `cheat_set_shop_unit` | `shop_index`: int, `unit_key`: string | 设置商店单位 |
| `cheat_set_gold` | `amount`: int | 设置金币数量 |
| `cheat_set_mana` | `amount`: int | 设置法力数量 |
| `cheat_upgrade_unit` | `grid_pos`: {x, y} | 升级指定单位 |
| `cheat_set_wave` | `wave_index`: int | 设置当前波次 |
| `cheat_spawn_enemy` | `enemy_type`: string | 生成敌人 |

---

## 使用示例

### Python 完整示例

```python
import json
import urllib.request
import time

BASE_URL = "http://127.0.0.1:8080"

def http_json(method, path, data=None):
    url = f"{BASE_URL}{path}"
    raw = None if data is None else json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=raw, method=method)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))

def wait_for_event(event_type, timeout=30):
    """轮询等待指定事件"""
    after_seq = 0
    start = time.time()
    while time.time() - start < timeout:
        resp = http_json("GET", f"/observations?after_seq={after_seq}&wait_ms=1000")
        for evt in resp.get("events", []):
            if evt['event_type'] == event_type:
                return evt
        after_seq = resp.get("next_seq", after_seq)
    return None

# 1. 选择图腾并验证
http_json("POST", "/action", {
    "request_id": "test-1",
    "actions": [{"type": "select_totem", "totem_id": "wolf_totem"}]
})
evt = wait_for_event("game_TotemSelected")
print(f"图腾选择: {evt}")

# 2. 购买单位并验证
http_json("POST", "/action", {
    "request_id": "test-2",
    "actions": [
        {"type": "cheat_set_shop_unit", "shop_index": 0, "unit_key": "wolf"},
        {"type": "buy_unit", "shop_index": 0}
    ]
})
evt = wait_for_event("game_ActionResult")
print(f"购买结果: {evt}")

# 3. 开始波次并等待结束
http_json("POST", "/action", {
    "request_id": "test-3",
    "actions": [{"type": "start_wave"}]
})
evt = wait_for_event("game_WaveEnded", timeout=60)
print(f"波次结束: {evt}")
```

### curl 示例

```bash
# 检查状态
curl http://127.0.0.1:8080/status

# 选择图腾
curl -X POST http://127.0.0.1:8080/action \
  -H "Content-Type: application/json" \
  -d '{"actions":[{"type":"select_totem","totem_id":"wolf_totem"}]}'

# 拉取事件（长轮询5秒）
curl "http://127.0.0.1:8080/observations?after_seq=0&limit=200&wait_ms=5000"
```

---

*文档版本: 2.0*
*最后更新: 2026-03-16*
