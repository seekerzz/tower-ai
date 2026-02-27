#!/usr/bin/env python3
"""
带作弊功能的AI示例 - 快速看到效果

这个AI会在游戏开始时添加金币、生成单位，然后观察战斗
用于快速测试和演示AI控制功能
"""

import asyncio
import websockets
import json
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def ai_with_cheats():
    """带作弊功能的AI"""
    uri = "ws://localhost:9090"

    logger.info("连接到Godot游戏...")
    async with websockets.connect(uri) as ws:
        logger.info("已连接! 等待游戏状态...")

        turn = 0
        initialized = False

        while True:
            turn += 1
            logger.info(f"\n========== 回合 {turn} ==========")

            # 接收状态
            message = await ws.recv()
            state = json.loads(message)

            event = state.get("event")
            global_data = state.get("global", {})

            logger.info(f"事件: {event}")
            logger.info(f"波次: {global_data.get('wave')}, "
                       f"金币: {global_data.get('gold')}, "
                       f"核心血量: {global_data.get('core_health')}/{global_data.get('max_core_health')}")

            # 检查是否在战斗阶段
            is_wave_active = global_data.get("is_wave_active", False)
            if is_wave_active:
                logger.info("状态: 战斗中")
            else:
                logger.info("状态: 准备阶段")

            # 决策
            actions = []

            if event == "GameOver":
                logger.info("游戏结束!")
                break

            elif not initialized and event == "WaveEnded":
                # 第一次进入，使用作弊指令快速设置
                logger.info("【作弊模式】添加资源并生成单位...")
                actions = [
                    {"type": "cheat_add_gold", "amount": 500},
                    {"type": "cheat_spawn_unit", "unit_type": "wolf", "level": 3, "zone": "grid", "pos": {"x": 0, "y": 0}},
                    {"type": "cheat_spawn_unit", "unit_type": "wolf", "level": 3, "zone": "grid", "pos": {"x": 1, "y": 0}},
                    {"type": "cheat_spawn_unit", "unit_type": "bat", "level": 2, "zone": "grid", "pos": {"x": 2, "y": 0}},
                    {"type": "start_wave"}
                ]
                initialized = True

            elif event == "WaveEnded":
                # 波次结束，生成更多单位然后继续
                logger.info("波次结束，生成新单位...")
                actions = [
                    {"type": "cheat_spawn_unit", "unit_type": "wolf", "level": 2, "zone": "grid", "pos": {"x": 0, "y": 1}},
                    {"type": "start_wave"}
                ]

            elif is_wave_active:
                # 战斗中，定期观察
                logger.info("观察战斗中... (0.5秒后更新)")
                actions = [{"type": "resume", "wait_time": 0.5}]

            else:
                # 其他情况
                actions = [{"type": "resume", "wait_time": 1.0}]

            # 发送动作
            if actions:
                await ws.send(json.dumps({"actions": actions}))
                logger.info(f"发送 {len(actions)} 个动作")


if __name__ == "__main__":
    print("=" * 60)
    print("Godot AI 客户端 - 作弊模式")
    print("=" * 60)
    print("功能:")
    print("  - 自动添加金币")
    print("  - 生成高级单位")
    print("  - 自动开始战斗")
    print("=" * 60)
    print()

    try:
        asyncio.run(ai_with_cheats())
    except KeyboardInterrupt:
        print("\n\n已停止")
    except Exception as e:
        logger.error(f"错误: {e}")
