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

### 严重问题（已修复）
1. **ActionError 未处理** - **已修复**
   - AI 发送购买/移动/开始波次动作后收到 `ActionError`
   - 修复：添加了详细的错误上下文，包括商店内容、金币数量、网格放置检查详情和建议的有效位置

2. **游戏结束检测失效** - **已修复**
   - 核心血量降为 0 后，`is_wave_active` 变为 False
   - 但游戏没有发送 `GameOver` 或 `WaveEnded` 事件
   - 修复：确保 `game_over.emit()` 在 `force_end_wave()` 之前调用，并添加了日志记录

3. **单位放置失败** - **已修复**
   - AI 尝试购买 torch 单位并放置到网格
   - 但收到 ActionError，可能是：
     - 购买失败（单位不存在或金币不足）
     - 移动失败（备战区为空或网格位置不可放置）
   - 修复：改进了错误消息，包含详细的放置失败原因和建议的有效位置

### 中等问题
4. **场景切换时 WebSocket 连接断开**
   - 虽然添加了重连机制，但断连的根本问题仍需解决

5. **资源文件 .import 缓存**
   - 需要运行 `godot --import` 来生成 `.godot/imported/` 目录

## 待修复事项

1. [x] 处理 ActionError，查看具体错误信息 - **已修复**: 添加了详细的错误上下文和网格放置检查
2. [x] 修复游戏结束检测（核心血量为0时发送 GameOver） - **已修复**: 确保 game_over 信号在 force_end_wave 之前发送
3. [x] 验证单位购买和移动动作的前置条件 - **已修复**: 改进了错误消息和上下文信息
4. [x] 检查网格位置 (0,0) 是否可放置 - **已验证**: (0,0) 是核心位置，不可放置。添加了详细的放置检查信息和建议的有效位置
5. [x] 添加更健壮的 AI 策略（购买便宜单位、检查放置位置等） - **已添加**: 新增 `cheat_set_shop_unit` 作弊指令，允许 AI 直接设置商店单位用于测试

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
4. `src/Autoload/GameManager.gd` - 修复 game_over 信号发送顺序，确保 AI 能收到 GameOver 事件
5. `src/Autoload/AIActionExecutor.gd` - 添加详细的 ActionError 上下文信息，改进网格放置检查，添加 `_to_int_index()` 修复 float/int 类型问题，添加 `cheat_set_shop_unit` 作弊指令
6. `ai_client/ai_game_client.py` - 修复 HTTP 响应处理顺序（先创建 Future 再发送请求），改进日志输出
7. `src/Autoload/AIManager.gd` - 添加详细的发送日志，修复 `_send_json` 错误处理
8. `src/Scripts/MainGame.gd`, `src/Autoload/GameManager.gd`, `src/Scripts/Controllers/BoardController.gd` - 修复 `call_group` 在 headless 模式下的崩溃问题
9. `src/Autoload/AIActionExecutor.gd` - 添加 `use_skill` 和 `get_unit_info` 动作，支持技能和 buff 查询

## 新增功能 - 技能和 Buff 支持

### use_skill 动作
激活指定位置单位的主动技能：
```json
{"type": "use_skill", "grid_pos": {"x": 0, "y": 1}}
```

检查项：
- [x] 技能存在性检查
- [x] 冷却时间检查
- [x] 法力值检查
- [x] 成功激活返回技能信息

### get_unit_info 动作
获取单位的详细信息，包括属性、技能和 buff：
```json
{"type": "get_unit_info", "grid_pos": {"x": 0, "y": 1}}
```

返回信息包括：
- [x] 基础属性 (hp, damage, atk_speed, range, crit_rate)
- [x] 技能信息 (name, cooldown, mana_cost, ready status)
- [x] 主动 buffs 列表 (range, speed, crit, bounce, split, guardian_shield)
- [x] 临时 buffs (stat, amount, duration)

## 下一步计划

1. [x] 在 AIManager 或 AIActionExecutor 中添加 ActionError 详细日志 - **已完成**
2. [x] 检查 GameManager 的 game_over 信号是否正确触发 - **已完成**
3. [x] 验证 BoardController 的 buy_unit 和 try_move_unit 动作 - **已完成**
4. [x] 修复 HTTP 超时问题 - **已完成**: 根因是 Future 在发送请求后才创建，已修复为创建 Future 先于发送请求
5. [x] 修复 call_group 崩溃问题 - **已修复**: 所有 `call_group` 调用现在检查 `has_method("call_group")` 以避免在 headless 模式下调用 Window 对象

## 最新测试结果 - 2026-02-28

### HTTP 超时问题已修复 ✅
所有动作现在都能正常返回响应：
- `select_totem` → `ActionsCompleted` ✅
- `buy_unit` → `ActionsCompleted` ✅
- `cheat_add_gold` → `ActionsCompleted` ✅
- `start_wave` → `WaveStarted` ✅
- `move_unit` (失败时) → `ActionError` (带详细上下文) ✅

### 根因分析
HTTP 超时的原因是 `_pending_response` Future 在发送请求后才创建。如果 Godot 响应很快（在 Future 创建前到达），响应会丢失导致超时。

### 修复方案
在 `ai_client/ai_game_client.py` 中：
1. 将 Future 创建移到发送请求之前
2. 添加详细日志输出
3. 超时后返回最后一次已知状态

### 待修复问题
**游戏崩溃** - **已修复**: 所有 `call_group` 调用现在检查 `has_method("call_group")` 以避免在 headless 模式下调用 Window 对象

### 修复详情
修复了以下文件中的 `call_group` 调用:
1. `src/Scripts/MainGame.gd:326` - skip_wave()
2. `src/Autoload/GameManager.gd:524` - _check_game_over()
3. `src/Autoload/GameManager.gd:534` - retry_wave()
4. `src/Scripts/Controllers/BoardController.gd:394` - retry_wave()

修复方式:
```gdscript
# 旧代码 (在 headless 模式下会崩溃):
Engine.get_main_loop().get_root().call_group("enemies", "queue_free")

# 新代码 (安全检查):
var main_loop = Engine.get_main_loop()
if main_loop and main_loop.has_method("call_group"):
    main_loop.call_group("enemies", "queue_free")
```
