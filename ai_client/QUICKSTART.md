# AI 客户端快速入门指南

## 1. 环境准备

### 安装 Python 依赖
```bash
cd ai_client
pip install websockets
```

### 启动 Godot 游戏
在另一个终端中：
```bash
cd /path/to/tower
godot --headless --path .
```

或使用 Godot 编辑器直接运行项目。

## 2. 运行 AI 客户端

### 使用示例 AI
```bash
python3 ai_game_client.py
```

你会看到类似输出：
```
============================================================
Godot AI 游戏客户端
============================================================
请确保 Godot 游戏已启动并运行在 ws://localhost:9090
按 Ctrl+C 停止
============================================================
2024-02-27 21:30:00 - INFO - [连接成功] ws://localhost:9090
2024-02-27 21:30:01 - INFO - ========== 回合 1 ==========
2024-02-27 21:30:01 - INFO - [收到状态] 事件: WaveEnded
2024-02-27 21:30:01 - INFO - [AI] 处理购买阶段，金币: 150
2024-02-27 21:30:01 - INFO - [发送动作] 3 个动作
...
```

## 3. 编写自己的 AI

创建一个新文件 `my_ai.py`：

```python
#!/usr/bin/env python3
from ai_game_client import AIGameClient, SimpleAI, ActionBuilder, run_ai_game

class MyAI(SimpleAI):
    async def make_decision(self, state):
        actions = []

        # 波次结束，购买阶段
        if state.event == "WaveEnded":
            # 购买第一个可用的单位
            shop = self.client.get_shop_units()
            for slot in shop:
                if slot.unit_key and not slot.locked:
                    actions.append(ActionBuilder.buy_unit(slot.index))
                    break

            # 开始下一波
            actions.append(ActionBuilder.start_wave())

        # 战斗中
        elif state.is_wave_active:
            # 每秒观察一次
            actions.append(ActionBuilder.resume(wait_time=1.0))

        else:
            actions.append(ActionBuilder.resume())

        return actions

if __name__ == "__main__":
    asyncio.run(run_ai_game(ai_class=MyAI))
```

运行：
```bash
python3 my_ai.py
```

## 4. 常用动作示例

### 购买单位
```python
# 购买商店第 0 个槽位的单位
ActionBuilder.buy_unit(0)
```

### 移动单位
```python
# 从备战区移动到网格
ActionBuilder.move_unit(
    "bench", 0,           # 从备战区索引 0
    "grid", {"x": 1, "y": 1}  # 移动到网格位置 (1,1)
)

# 从网格撤回备战区
ActionBuilder.move_unit(
    "grid", {"x": 1, "y": 1},
    "bench", 0
)
```

### 出售单位
```python
# 出售备战区单位
ActionBuilder.sell_unit("bench", 0)

# 出售网格单位
ActionBuilder.sell_unit("grid", {"x": 1, "y": 1})
```

### 刷新商店
```python
ActionBuilder.refresh_shop()
```

### 锁定/解锁商店槽位
```python
ActionBuilder.lock_shop_slot(2)      # 锁定第 2 个槽位
ActionBuilder.unlock_shop_slot(2)    # 解锁第 2 个槽位
```

### 开始波次
```python
ActionBuilder.start_wave()
```

### 恢复游戏（带延时）
```python
# 直接恢复
ActionBuilder.resume()

# 恢复后 0.5 秒再次暂停
ActionBuilder.resume(wait_time=0.5)
```

## 5. 查询游戏状态

```python
# 获取金币
gold = self.client.get_gold()

# 获取商店
shop = self.client.get_shop_units()
for slot in shop:
    print(f"槽位 {slot.index}: {slot.unit_key}, 锁定: {slot.locked}")

# 获取备战区单位
bench = self.client.get_bench_units()
for unit in bench:
    print(f"槽位 {unit.index}: {unit.unit.key} LV{unit.unit.level}")

# 获取网格单位
grid = self.client.get_grid_units()
for gu in grid:
    print(f"位置 ({gu.position.x}, {gu.position.y}): {gu.unit.key}")

# 获取敌人列表
enemies = self.client.get_enemies()
for enemy in enemies:
    print(f"敌人 {enemy.type}: HP {enemy.hp}/{enemy.max_hp}")

# 查找空备战区槽位
empty_slot = self.client.find_empty_bench_slot()
if empty_slot != -1:
    print(f"空槽位: {empty_slot}")

# 查找特定单位
wolf_index = self.client.find_shop_unit("wolf")
if wolf_index is not None:
    print(f"wolf 在商店槽位 {wolf_index}")
```

## 6. 作弊指令（调试用）

```python
# 添加金币
ActionBuilder.cheat_add_gold(1000)

# 添加法力
ActionBuilder.cheat_add_mana(500)

# 生成单位
ActionBuilder.cheat_spawn_unit("wolf", 2, "grid", {"x": 0, "y": 0})

# 设置游戏速度（2倍速）
ActionBuilder.cheat_set_time_scale(2.0)
```

## 7. 事件类型

游戏会触发以下事件：

| 事件 | 说明 | 处理建议 |
|------|------|---------|
| `WaveEnded` | 波次结束 | 购买单位、调整阵容 |
| `WaveStarted` | 波次开始 | 观察战斗 |
| `BossSpawned` | Boss 出现 | 密切观察 |
| `CoreCritical` | 核心危急 | 紧急处理 |
| `AI_Wakeup` | 唤醒 | 继续观察或行动 |
| `GameOver` | 游戏结束 | 停止 AI |

## 8. 调试技巧

### 查看 Godot 日志
Godot 服务端会输出彩色中文日志：
- 🔵 蓝色：网络日志
- 🟢 绿色：事件日志
- 🟠 橙色：动作日志
- 🔴 红色：错误日志

### 打印接收到的状态
```python
async def make_decision(self, state):
    print(f"事件: {state.event}")
    print(f"波次: {state.wave}, 金币: {state.gold}")
    print(f"核心: {state.core_health}/{state.max_core_health}")
    # ...
```

### 动作执行失败
如果动作执行失败，服务端会返回 `ActionError` 事件：
```python
if state.event == "ActionError":
    print(f"错误: {state.event_data.get('error_message')}")
    print(f"失败动作: {state.event_data.get('failed_action')}")
```

## 9. 故障排除

### 连接失败
- 确认 Godot 游戏已启动
- 检查端口 9090 是否被占用
- 检查防火墙设置

### 收不到状态
- 游戏需要触发事件才会发送状态
- 尝试在游戏中手动开始波次

### 动作不执行
- 检查前置条件（非战斗阶段、金币足够等）
- 查看 Godot 日志中的错误信息

## 10. 进阶示例

### 智能购买策略
```python
async def make_decision(self, state):
    if state.event == "WaveEnded":
        actions = []
        gold = self.client.get_gold()

        # 优先购买 wolf，其次 bat
        priority = ["wolf", "bat", "viper"]
        for unit_type in priority:
            while gold >= 10:
                idx = self.client.find_shop_unit(unit_type)
                if idx is None:
                    break
                if self.client.find_empty_bench_slot() == -1:
                    break
                actions.append(ActionBuilder.buy_unit(idx))
                gold -= 10

        # 部署到网格
        # ...

        actions.append(ActionBuilder.start_wave())
        return actions
```

### 根据敌人调整策略
```python
async def make_decision(self, state):
    if state.is_wave_active:
        enemies = self.client.get_enemies()

        # 如果有 Boss，密切观察
        has_boss = any(e.type == "boss" for e in enemies)
        wait_time = 0.3 if has_boss else 1.0

        return [ActionBuilder.resume(wait_time=wait_time)]
```

---

更多详细信息请参考 [API_DOCUMENTATION.md](API_DOCUMENTATION.md) 和 [README.md](README.md)
