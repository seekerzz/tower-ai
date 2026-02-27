# AI 系统测试进度报告

## 测试日期
2026-02-28

## 已完成的工作

### 1. 资源导入修复
- 使用 `godot --headless --path . --import` 导入所有资源文件
- 修复了 `bg_battle.png`、`tile_sheet.png`、`tile_spawn.png` 等资源加载失败问题

### 2. 场景切换通知修复
- **问题**: 场景切换后 AI 客户端不知道场景已加载完成
- **解决**: 在 `MainGame.gd` 的 `_ready()` 中添加发送 `TotemSelected` 事件给 AI

### 3. AI 客户端增强
- 添加自动重连机制
- 修复端口不匹配问题 (45678)
- 添加更详细的事件处理逻辑

### 4. AI 购买放置逻辑
- 在 `TotemSelected` 事件后添加购买单位和放置到网格的逻辑
- 现在 AI 会尝试购买商店第一个单位并放置到 (0,0) 位置

## 发现的问题

### 严重问题
1. **ActionError 未处理**
   - AI 发送购买/移动/开始波次动作后收到 `ActionError`
   - 需要查看具体错误原因

2. **游戏结束检测失效**
   - 核心血量降为 0 后，`is_wave_active` 变为 False
   - 但游戏没有发送 `GameOver` 或 `WaveEnded` 事件
   - 导致 AI 无限循环接收 `AI_Wakeup` 事件

3. **单位放置失败**
   - AI 尝试购买 torch 单位并放置到网格
   - 但收到 ActionError，可能是：
     - 购买失败（单位不存在或金币不足）
     - 移动失败（备战区为空或网格位置不可放置）

### 中等问题
4. **场景切换时 WebSocket 连接断开**
   - 虽然添加了重连机制，但断连的根本问题仍需解决

5. **资源文件 .import 缓存**
   - 需要运行 `godot --import` 来生成 `.godot/imported/` 目录

## 待修复事项

1. [ ] 处理 ActionError，查看具体错误信息
2. [ ] 修复游戏结束检测（核心血量为0时发送 GameOver）
3. [ ] 验证单位购买和移动动作的前置条件
4. [ ] 检查网格位置 (0,0) 是否可放置
5. [ ] 添加更健壮的 AI 策略（购买便宜单位、检查放置位置等）

## 如何运行测试

```bash
# 1. 导入资源（首次运行需要）
godot --headless --path . --import

# 2. 启动 Godot 服务器
godot --path . res://src/Scenes/UI/CoreSelection.tscn --ai-mode

# 3. 在另一个终端运行 AI 客户端
cd ai_client && python3 example_minimal.py
```

## 文件修改记录

1. `ai_client/example_minimal.py` - 添加重连逻辑、购买放置逻辑
2. `src/Scripts/MainGame.gd` - 添加 TotemSelected 事件发送
3. `src/Autoload/AIManager.gd` - 端口统一为 45678

## 下一步计划

1. 在 AIManager 或 AIActionExecutor 中添加 ActionError 详细日志
2. 检查 GameManager 的 game_over 信号是否正确触发
3. 验证 BoardController 的 buy_unit 和 try_move_unit 动作
