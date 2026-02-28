# Godot AI 客户端 - HTTP REST API 网关

重构后的 AI 客户端，支持 HTTP REST API、动态端口分配、Godot 进程管理和崩溃检测。

## 功能特性

- **HTTP REST API**: 通过 HTTP 接收动作请求，返回游戏状态
- **动态端口分配**: 自动寻找可用端口，避免冲突
- **双模式启动**: 支持 Headless（无头）和 GUI（图形界面）模式
- **崩溃检测**: 实时监控 Godot 输出，捕获 SCRIPT ERROR 等崩溃
- **进程管理**: 自动启动、监控和清理 Godot 进程

## 快速开始

### 1. Headless 模式（默认，用于训练）

```bash
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

### 2. GUI 模式（用于调试观察）

```bash
python3 ai_client/ai_game_client.py --visual
```

### 3. 使用 curl 发送请求

```bash
# 获取状态
curl http://127.0.0.1:<port>/status

# 发送动作
curl -X POST http://127.0.0.1:<port>/action \
  -H "Content-Type: application/json" \
  -d '{"actions": [{"type": "select_totem", "totem_id": "wolf"}]}'
```

## 命令行参数

```
python3 ai_game_client.py [选项]

选项:
  --visual, --gui       启用 GUI 模式（显示游戏窗口）
  --project PATH, -p PATH
                        Godot 项目路径 (默认: /home/zhangzhan/tower)
  --scene PATH, -s PATH
                        启动场景路径 (默认: res://src/Scenes/UI/CoreSelection.tscn)
  --http-port PORT      HTTP 服务器端口 (0=自动分配)
  --godot-port PORT     Godot WebSocket 端口 (0=自动分配)
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
  "error_type": "SCRIPT ERROR: Invalid call...",
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

## 测试

### 运行崩溃检测测试

```bash
python3 tests/test_crash_detection.py
```

### 手动测试崩溃捕获

```bash
# 使用 TestCrash 场景（会主动触发 GDScript 错误）
python3 ai_client/ai_game_client.py --scene res://src/Scenes/Test/TestCrash.tscn --visual
```

预期输出包含 `SystemCrash` 事件。

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    ai_game_client.py                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  HTTP Server │◄───│  请求路由    │◄───│ 外部 curl    │  │
│  │  (随机端口)  │    │  /action     │    │ 调用         │  │
│  └──────────────┘    └──────┬───────┘    └──────────────┘  │
│                             │                               │
│                        ┌────┴────┐                         │
│                        │ WebSocket│ ← 内部转发              │
│                        │ Client   │                         │
│                        └────┬────┘                         │
│                             │                               │
│  ┌──────────────────────────┼──────────────────────────┐   │
│  │    Godot 子进程          │                          │   │
│  │  ┌───────────────────────┼──────────────────────┐   │   │
│  │  │   AIManager.gd        ▼                      │   │   │
│  │  │  ┌──────────────┐  ┌──────────────┐         │   │   │
│  │  │  │WebSocket Srv │  │ --ai-port    │         │   │   │
│  │  │  │ (随机端口)   │  │ 参数解析     │         │   │   │
│  │  │  └──────────────┘  └──────────────┘         │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  │           ▲                                        │   │
│  │           │ stdout/stderr 流监控                   │   │
│  │           │ (SCRIPT ERROR 检测)                    │   │
│  │           ▼                                        │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  崩溃处理器: kill() + 返回 SystemCrash JSON │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 文件结构

```
ai_client/
├── ai_game_client.py       # 主程序（HTTP 网关）
├── ai_game_client_legacy.py # 旧版 WebSocket 客户端（备份）
├── godot_process.py         # Godot 进程管理器
├── http_server.py           # HTTP REST 服务器
├── utils.py                 # 工具函数（端口分配、错误检测）
├── API_DOCUMENTATION.md     # API 文档
└── README_NEW.md           # 本文件
```

## 与旧版对比

| 特性 | 新版 | 旧版 |
|------|------|------|
| 通信方式 | HTTP REST | WebSocket |
| 进程管理 | 自动启动 Godot | 需手动启动 |
| 端口配置 | 动态分配 | 硬编码 45678/9090 |
| 崩溃检测 | 自动捕获 | 无 |
| 启动模式 | Headless/GUI | 仅 GUI |
| 使用方式 | curl / HTTP 客户端 | Python WebSocket 连接 |
