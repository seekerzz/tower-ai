# Godot AI 客户端 (Hybrid Gateway)

这是一个作为 HTTP REST 网关的 AI 游戏客户端。它负责启动 Godot 进程、通过 WebSocket 连接到 Godot 游戏引擎，并为外部的 AI Agent 提供一个统一且简单的 HTTP API，使得 AI 能够以**极简、非阻塞**的纯文本流方式进行交互和控制。

---

## ⚠️ AI Agent 必读前置 ⚠️

**警告：本游戏具有极其特殊的反直觉生存机制和数值设定。**

在你（AI Agent）进行任何决策、购买单位或排兵布阵之前，**你必须首先读取并严格理解位于本项目根目录下的核心设计文档：**
👉 **`docs/GameDesign.md`**

如果你未阅读该文档，你将极大概率因为误判（例如误以为单位会死亡、不知道如何提升核心最大血量、不知道扩建规则）而导致游戏迅速失败。请务必根据该文档的设定，结合当前的图腾流派来构建你的卡组和操作逻辑。

---

## 架构

基于 "Hybrid Gateway" 架构：
- **下行（读）**：WebSocket 接收 Godot 推送的日志、纯文本战报以及系统提示后，直接存入内存队列缓冲中。完全没有复杂的 JSON 解析，百分百纯文本处理，贴近小说阅读体验。
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
API 接口
```
1. 发送动作 POST /action
AI Agent 使用此接口以非阻塞的方式发送操作指令，请求一旦收到就会立即返回 HTTP 200，绝不阻塞。

请求示例 (Curl):

```bash
curl -X POST http://127.0.0.1:8080/action \
     -H "Content-Type: application/json" \
     -d '{
          "actions": [
            {"type": "buy_unit", "shop_index": 0},
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid", "from_pos": 0, "to_pos": {"x": 1, "y": 0}},
            {"type": "refresh_shop"},
            {"type": "start_wave"}
          ]
        }'
```
支持的 Action 类型字典（必须严格遵守）：

**select_totem**: 选择图腾（游戏开始时使用）。需提供 `totem_id` 字段，可选值：`wolf_totem`, `cow_totem`, `bat_totem`, `viper_totem`, `butterfly_totem`, `eagle_totem`。

**buy_unit**: 购买商店中的单位（需提供 `shop_index` 字段，值为 0-3 的整数，对应商店从左到右的4个槽位）。

**sell_unit**: 卖出场上或备战席的单位。需提供 `zone` 字段（"bench" 或 "grid"）和 `pos` 字段（bench时为整数索引，grid时为 {"x": int, "y": int}）。

**move_unit**: 移动单位。需提供 `from_zone`, `to_zone`, `from_pos`, `to_pos` 字段。`from_zone` 和 `to_zone` 可以是 "bench" 或 "grid"。注意：(0,0) 是核心位置，不能部署单位。

**refresh_shop**: 花费金币刷新商店。

**lock_shop_slot**: 锁定商店槽位。需提供 `shop_index` 字段（0-3）。

**unlock_shop_slot**: 解锁商店槽位。需提供 `shop_index` 字段（0-3）。

**start_wave**: 结束备战，立刻开始下一波怪物的进攻。

**retry_wave**: 重新尝试当前波次（失败后使用）。

**use_skill**: 使用单位技能。需提供 `grid_pos` 字段 {"x": int, "y": int}。

2. 获取实时战报与观测流 GET /observations
AI Agent 需要通过高频轮询此接口，获取当前游戏的最新事件。此接口会返回包含纯自然语言描述的游戏战报、心跳状态以及报错堆栈在内的纯文本流。

每一次请求都会返回自上次请求以来所有新发生的纯净文本事件，返回数据读后即焚。

请求示例 (Curl):

Bash
curl -X GET [http://127.0.0.1:8080/observations](http://127.0.0.1:8080/observations)
响应示例:

```json
{
  "observations": [
    "【状态同步】当前核心血量：500.0/500.0",
    "【战斗】血法师 释放了 血池降临！",
    "【核心受击】图腾核心受到了 15.5 点伤害！当前血量 584.5/600.0",
    "【系统严重报错】检测到 Godot 引擎崩溃：\n错误类型：SCRIPT ERROR: Division by zero\n堆栈：\nAt: res://src/test.gd:42"
  ]
}
```
3. 健康检查 GET /health 与 状态获取 GET /status
用于监控服务器是否健康运行及当前的进程配置和状态。

请求示例 (Curl):

```bash
curl -X GET [http://127.0.0.1:8080/status](http://127.0.0.1:8080/status)
```
响应示例:

```json
{
  "godot_running": true,
  "ws_connected": true,
  "http_port": 8080,
  "godot_ws_port": 45678,
  "visual_mode": false,
  "crashed": false
}
```
