# AI图腾选择模式运行指南

这个模式让AI客户端可以像玩家一样选择图腾，然后进入游戏。

## 运行方式

### 方式1：AI自动选择图腾（推荐）

**启动AI自动图腾选择场景：**
```bash
cd /home/zhangzhan/tower
godot --headless --path . tests/AIAutoTotemSelect.tscn
```

**运行AI客户端：**
```bash
cd ai_client
python3 example_minimal.py
```

AI将会：1. 收到 `TotemSelection` 事件
2. 选择第一个可用图腾（如 `wolf_totem`）
3. 进入游戏主场景
4. 开始购买单位和战斗

### 方式2：使用完整客户端库
```python
from ai_game_client import AIGameClient, ActionBuilder

async def main():
    client = AIGameClient()
    await client.connect()

    state = await client.receive_state()
    if state.event == "TotemSelection":
        # AI选择图腾
        await client.send_actions([
            ActionBuilder.select_totem("wolf_totem")
        ])

    # 继续游戏流程...
```

## 可用图腾

- `wolf_totem` - 狼图腾（进攻型）
- `bat_totem` - 蝙蝠图腾（敏捷型）
- `viper_totem` - 毒蛇图腾（毒素型）
- `butterfly_totem` - 蝴蝶图腾（辅助型）
- `eagle_totem` - 鹰图腾（远程型）

## 完整游戏流程

```
AI连接 → 收到TotemSelection → 选择图腾 → 进入游戏
                                           ↓
游戏结束 ← 收到GameOver ← 战斗 ← 布置单位 ← 购买单位 ← 收到WaveEnded
```

## 测试不同图腾

修改 `example_minimal.py` 中的选择逻辑：

```python
if event == "TotemSelection":
    available = state.get("available_totems", [])
    # 选择特定图腾
    selected = "bat_totem"  # 改为想要的图腾
    actions = [{"type": "select_totem", "totem_id": selected}]
```
