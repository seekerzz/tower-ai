#!/usr/bin/env python3
"""
极简 AI 客户端示例 - 完整游戏流程（带自动重连）

运行:
    python3 example_minimal.py
"""

import asyncio
import websockets
import json
import time


async def simple_ai():
    """最简单的 AI 客户端 - 自动购买和放置单位"""
    uri = "ws://localhost:45678"
    reconnect_delay = 2.0

    while True:
        try:
            print(f"\n连接到 Godot 游戏... {uri}")
            async with websockets.connect(uri, ping_interval=5, ping_timeout=10) as ws:
                print("已连接!")
                await game_loop(ws)
        except websockets.exceptions.ConnectionClosed as e:
            print(f"连接断开: {e}")
            print(f"{reconnect_delay}秒后重连...")
            await asyncio.sleep(reconnect_delay)
        except Exception as e:
            print(f"错误: {e}")
            print(f"{reconnect_delay}秒后重连...")
            await asyncio.sleep(reconnect_delay)


async def game_loop(ws):
    """游戏主循环"""
    totem_selected = False
    wave_started_count = 0

    while True:
        # 1. 接收游戏状态
        message = await ws.recv()
        state = json.loads(message)

        event = state.get("event")
        global_data = state.get("global", {})
        board_data = state.get("board", {})

        print(f"\n[收到事件] {event}")
        if global_data:
            print(f"  金币: {global_data.get('gold', 0)}, 波次: {global_data.get('wave', 0)}, 核心血量: {global_data.get('core_health', 0)}")

        # 2. 根据事件做出决策
        actions = []

        if event == "TotemSelection":
            # 图腾选择阶段
            available = state.get("available_totems", [])
            print(f"可用图腾: {available}")
            selected = available[0] if available else "wolf_totem"
            print(f"选择图腾: {selected}")
            actions = [{"type": "select_totem", "totem_id": selected}]
            totem_selected = True

        elif event == "TotemSelected":
            # 图腾已选择，先购买单位并放置，再开始第一波
            totem_id = state.get("event_data", {}).get("totem_id", "unknown")
            print(f"图腾已选择: {totem_id}")

            # 获取商店和金币信息
            gold = global_data.get("gold", 0)
            shop = board_data.get("shop", [])
            print(f"当前金币: {gold}")
            print(f"商店: {[s.get('unit_key') for s in shop]}")

            # 购买第一个可用单位
            for slot in shop:
                if slot.get('unit_key') and gold >= 10:
                    print(f"购买商店槽位 {slot['index']} 的单位: {slot['unit_key']}")
                    actions.append({"type": "buy_unit", "shop_index": slot['index']})
                    gold -= 10
                    break

            # 放置到网格位置 (0,0)
            actions.append({
                "type": "move_unit",
                "from_zone": "bench",
                "from_pos": 0,
                "to_zone": "grid",
                "to_pos": {"x": 0, "y": 0}
            })

            # 开始第一波
            actions.append({"type": "start_wave"})
            print("开始第一波...")

        elif event == "WaveEnded":
            # 波次结束，购买单位并放置到网格
            print("波次结束，进入购买阶段")
            gold = global_data.get("gold", 0)
            shop = board_data.get("shop", [])
            bench = board_data.get("bench", [])
            grid = board_data.get("grid", [])

            print(f"当前金币: {gold}")
            print(f"商店: {[s.get('unit_key') for s in shop]}")
            print(f"备战区: {[b.get('unit', {}).get('key') if b.get('unit') else None for b in bench]}")
            print(f"网格上的单位: {len(grid)}")

            # 策略：购买第一个可用单位（如果有金币）
            for slot in shop:
                if slot.get('unit_key') and gold >= 10:
                    print(f"购买商店槽位 {slot['index']} 的单位: {slot['unit_key']}")
                    actions.append({"type": "buy_unit", "shop_index": slot['index']})
                    gold -= 10
                    break

            # 如果有单位在备战区，移动第一个到网格
            bench_units = [(i, b) for i, b in enumerate(bench) if b.get('unit')]
            if bench_units:
                bench_idx, unit_data = bench_units[0]
                # 找一个空的网格位置（简单策略：固定位置）
                grid_positions = [
                    {"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0},
                    {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1},
                ]
                # 检查哪些位置已被占用
                occupied = set()
                for g in grid:
                    pos = g.get('position', {})
                    occupied.add((pos.get('x'), pos.get('y')))

                # 找到第一个空位置
                for pos in grid_positions:
                    if (pos['x'], pos['y']) not in occupied:
                        print(f"将备战区单位从槽位 {bench_idx} 移动到网格 {pos}")
                        actions.append({
                            "type": "move_unit",
                            "from_zone": "bench",
                            "from_pos": bench_idx,
                            "to_zone": "grid",
                            "to_pos": pos
                        })
                        break

            # 开始下一波
            actions.append({"type": "start_wave"})
            print("开始下一波")

        elif event == "WaveStarted":
            wave = global_data.get("wave", 0)
            wave_started_count += 1
            print(f"波次 {wave} 开始，观察战斗...")
            actions = [{"type": "resume", "wait_time": 1.0}]

        elif event == "AI_Wakeup":
            # 唤醒后检查当前状态
            is_wave_active = global_data.get("is_wave_active", False)
            wave = global_data.get("wave", 1)
            print(f"AI唤醒 - 波次: {wave}, 战斗中: {is_wave_active}")

            if is_wave_active:
                actions = [{"type": "resume", "wait_time": 1.0}]
            else:
                # 非战斗阶段，可能是购买阶段
                actions = [{"type": "resume", "wait_time": 0.5}]

        elif event == "GameOver":
            print("游戏结束!")
            print(f"存活波次: {global_data.get('wave', 0)}")
            break

        elif event == "BossSpawned":
            print("BOSS出现!")
            actions = [{"type": "resume", "wait_time": 1.0}]

        elif event == "CoreCritical":
            print("核心血量危急!")
            actions = [{"type": "resume", "wait_time": 0.5}]

        else:
            print(f"未处理事件: {event}")
            actions = [{"type": "resume", "wait_time": 0.5}]

        # 3. 发送动作
        if actions:
            await ws.send(json.dumps({"actions": actions}))
            print(f"发送动作: {actions}")


if __name__ == "__main__":
    try:
        asyncio.run(simple_ai())
    except KeyboardInterrupt:
        print("\n已停止")
