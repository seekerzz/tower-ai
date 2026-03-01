# Godot AI 客户端 (Hybrid Gateway)

这是一个作为 HTTP REST 网关的 AI 游戏客户端。它负责启动 Godot 进程、通过 WebSocket 连接到 Godot 游戏引擎，并为外部的 AI Agent 提供一个统一且简单的 HTTP API，使得 AI 能够以**极简、非阻塞**的方式进行交互和控制。

本项目现已完全采用**自然语言纯文本流**交互框架，彻底移除了所有的 JSON 解析与硬编码字段，更加贴近小说阅读体验和直观的模型观测。

## 架构

基于 "Hybrid Gateway" 架构：
- **下行（读）**：WebSocket 接收 Godot 推送的日志、纯文本战报以及系统提示后，直接存入内存队列缓冲中。完全没有复杂的 JSON 解析，百分百纯文本处理。
- **上行（写）**：接收外部 AI 的 HTTP POST 请求并直接转发到 WebSocket，实现完全非阻塞返回。
- 此外，此网关同时监听 Godot 进程输出。当引擎发生崩溃或报错时，会自动提取底层的堆栈信息，并以纯净文本直接推送到观测流中，供模型实时分析。

## 启动

客户端支持 Headless 模式（无头模式）和 GUI 模式。

```bash
# 进入游戏根目录
cd /path/to/project

# 启动 Headless 模式（推荐自动训练时使用）
python3 ai_client/ai_game_client.py --project . --scene res://src/Scenes/UI/CoreSelection.tscn --http-port 8080

# 启动 GUI 模式（用于可视化 Debug）
python3 ai_client/ai_game_client.py --project . --scene res://src/Scenes/UI/CoreSelection.tscn --http-port 8080 --visual
```

## API 接口

### 1. 发送动作 `POST /action`

AI Agent 使用此接口以非阻塞的方式发送操作指令，请求一旦收到就会立即返回 HTTP 200，绝不阻塞！

**请求示例 (Curl)**:
```bash
curl -X POST http://127.0.0.1:8080/action \
     -H "Content-Type: application/json" \
     -d '{"actions": [{"type": "start_wave"}]}'
```

**响应示例**:
```json
{
  "status": "ok",
  "message": "Actions sent"
}
```

### 2. 获取实时战报与观测流 `GET /observations`

AI Agent 需要通过**高频轮询**此接口，获取当前游戏的最新事件。此接口会返回包含纯自然语言描述的游戏战报、心跳状态（如基地血量）以及报错堆栈在内的纯文本流。

每一次请求都会返回自上次请求以来所有新发生的纯净文本事件，同时服务器会在此时将这些文本追加写入到 log 日志文件中，随后清空队列。**返回数据读后即焚**。如果在落盘的 log 中查阅，只会呈现出小说式的自然语言体验，没有 `[RAW JSON]` 或大括号干扰。

**请求示例 (Curl)**:
```bash
curl -X GET http://127.0.0.1:8080/observations
```

**响应示例**:
```json
{
  "observations": [
    "[Combat] 核心受到 15 点伤害",
    "[Shop] 刷新出：剑士，法师",
    "【系统严重报错】检测到 Godot 引擎崩溃：\n错误类型：SCRIPT ERROR: Division by zero\n堆栈：\nAt: res://src/test.gd:42"
  ]
}
```

### 3. 健康检查 `GET /health` 与 状态获取 `GET /status`

用于监控服务器是否健康运行及当前的进程配置和状态。

**请求示例 (Curl)**:
```bash
curl -X GET http://127.0.0.1:8080/health
```

**响应示例**:
```json
{
  "status": "ok"
}
```
