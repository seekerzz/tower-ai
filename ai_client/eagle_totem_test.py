#!/usr/bin/env python3
"""
鹰图腾流派测试脚本 (TOTEM-EAGLE-001)
"""

import asyncio
import json
import time
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))
import aiohttp


class EagleTester:
    def __init__(self, http_port: int = 8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.log_file: Optional[Path] = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = Path(f"logs/ai_session_eagle_totem_{timestamp}.log")
        self.log_file.parent.mkdir(exist_ok=True)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message: str, event_type: str = "INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] [{event_type}] {message}"
        print(log_line)
        if self.log_file:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(log_line + "\n")

    async def send_actions(self, actions: List[Dict[str, Any]]) -> Dict[str, Any]:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": actions},
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败: {e}", "ERROR")
            return {"status": "error", "message": str(e)}

    async def get_observations(self) -> List[str]:
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                data = await resp.json()
                return data.get("observations", [])
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            for o in obs:
                self.log(o, "GAME")
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 30.0) -> bool:
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(
                    f"{self.base_url}/status",
                    timeout=aiohttp.ClientTimeout(total=2)
                ) as resp:
                    data = await resp.json()
                    if data.get("godot_running") and data.get("ws_connected"):
                        self.log("游戏已就绪", "SYSTEM")
                        return True
            except:
                pass
            await asyncio.sleep(0.5)
        return False

    async def run_test(self):
        self.log("=" * 60, "SYSTEM")
        self.log("开始鹰图腾流派测试 (TOTEM-EAGLE-001)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        if not await self.wait_for_game_ready():
            self.log("游戏未就绪", "ERROR")
            return False

        # 选择鹰图腾
        self.log("选择鹰图腾...", "ACTION")
        await self.send_actions([{"type": "select_totem", "totem_id": "eagle_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        # 购买单位
        self.log("购买单位...", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)

        # 部署单位
        self.log("部署单位到战场...", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)

        # 开始第1波
        self.log("开始第1波...", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        obs = await self.poll_observations(10.0)

        # 检查暴击/回响相关日志
        for o in obs:
            if "暴击" in o or "crit" in o.lower():
                self.log("✅ 发现暴击机制日志", "VALIDATION")
            if "回响" in o or "echo" in o.lower():
                self.log("✅ 发现回响机制日志", "VALIDATION")

        # 继续波次
        for wave in range(2, 5):
            self.log(f"开始第{wave}波...", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)
            await self.poll_observations(8.0)

        self.log("测试完成", "SYSTEM")
        return True


async def main():
    http_port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    async with EagleTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
