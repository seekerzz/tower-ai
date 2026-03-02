#!/usr/bin/env python3
"""
TOTEM-COW-001-RETEST-3 验证测试脚本

CRASH-002 修复后的牛图腾全面验证测试
验证重点:
1. 第1波是否正常启动，无崩溃
2. 牛图腾受伤充能机制
3. 全屏反击机制
4. 嘲讽联动机制
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


class TotemCowRetest3:
    """牛图腾修复验证测试器"""

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.log_file = None
        self.crashed = False
        self.crash_info = None
        self.wave_completed = False
        self.mechanics_verified = {
            "wave_start": False,
            "injury_charge": False,
            "counter_attack": False,
            "taunt_mechanic": False,
        }

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_cow_totem_{timestamp}.log"

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message, level="INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    async def send_actions(self, actions):
        """发送动作"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": actions},
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败: {e}", "ERROR")
            return {"error": str(e)}

    async def get_observations(self):
        """获取观测数据"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                data = await resp.json()
                return data.get("observations", [])
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def get_status(self):
        """获取游戏状态"""
        try:
            async with self.session.get(
                f"{self.base_url}/status",
                timeout=aiohttp.ClientTimeout(total=2)
            ) as resp:
                return await resp.json()
        except:
            return {}

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        """轮询观测数据"""
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            for o in obs:
                self.log(f"[OBS] {o}", "OBS")
                all_obs.append(o)
                # 检测崩溃
                if "崩溃" in o or "CRASH" in o or "ERROR" in o:
                    self.crashed = True
                    self.crash_info = o
                    self.log(f"检测到崩溃: {o}", "CRASH")
                # 检测波次完成
                if "波次完成" in o or "第 1 波" in o and "完成" in o:
                    self.wave_completed = True
                # 检测机制
                if "充能" in o or "charge" in o.lower():
                    self.mechanics_verified["injury_charge"] = True
                if "反击" in o or "counter" in o.lower():
                    self.mechanics_verified["counter_attack"] = True
                if "嘲讽" in o or "taunt" in o.lower():
                    self.mechanics_verified["taunt_mechanic"] = True
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 30.0) -> bool:
        """等待游戏就绪"""
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            status = await self.get_status()
            if status.get("godot_running") and status.get("ws_connected"):
                self.log("游戏已就绪", "SYSTEM")
                return True
            if status.get("crashed"):
                self.log("游戏已崩溃!", "ERROR")
                self.crashed = True
                return False
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def run_cow_totem_test(self):
        """运行牛图腾全面测试"""
        self.log("=" * 60, "TEST")
        self.log("TOTEM-COW-001-RETEST-3 牛图腾修复验证", "TEST")
        self.log("=" * 60, "TEST")

        # 1. 选择牛图腾
        self.log("【步骤1】选择牛图腾 (cow_totem)", "ACTION")
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        if self.crashed:
            self.log("❌ 选择图腾阶段崩溃", "RESULT")
            return False
        self.log("✅ 选择图腾成功", "RESULT")

        # 2. 购买牛图腾单位（牦牛守护 - 有嘲讽）
        self.log("【步骤2】购买牦牛守护（带嘲讽技能）", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        # 3. 部署单位到战场
        self.log("【步骤3】部署牦牛守护到战场", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        if self.crashed:
            self.log("❌ 部署单位阶段崩溃", "RESULT")
            return False
        self.log("✅ 部署单位成功", "RESULT")

        # 4. 启动第1波（关键验证点）
        self.log("【步骤4】启动第1波 - 关键验证点", "ACTION")
        self.log("观察是否发生崩溃...", "TEST")
        await self.send_actions([{"type": "start_wave"}])

        # 长时间观察波次进行
        for i in range(10):  # 观察约20秒
            if self.crashed:
                break
            await self.poll_observations(2.0)
            self.log(f"波次进行中... ({i+1}/10)", "PROGRESS")

        self.mechanics_verified["wave_start"] = not self.crashed

        if self.crashed:
            self.log("❌ 第1波启动时崩溃 - CRASH-002未修复", "RESULT")
            return False

        self.log("✅ 第1波正常启动，无崩溃", "RESULT")
        return True

    async def generate_report(self, success: bool):
        """生成验证报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("TOTEM-COW-001-RETEST-3 验证报告", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "TOTEM-COW-001-RETEST-3 验证报告",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]

        if self.crashed:
            report_lines.extend([
                "❌ CRASH-002 修复验证: 失败",
                f"崩溃信息: {self.crash_info}",
            ])
        else:
            report_lines.append("✅ CRASH-002 修复验证: 通过 - 第1波正常启动")

        report_lines.extend([
            "",
            "机制验证状态:",
            f"  第1波启动: {'✅' if self.mechanics_verified['wave_start'] else '❌'}",
            f"  受伤充能: {'✅' if self.mechanics_verified['injury_charge'] else '⏳'}",
            f"  全屏反击: {'✅' if self.mechanics_verified['counter_attack'] else '⏳'}",
            f"  嘲讽联动: {'✅' if self.mechanics_verified['taunt_mechanic'] else '⏳'}",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        return success and not self.crashed

    async def run_all_tests(self):
        """运行所有验证测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("TOTEM-COW-001-RETEST-3 验证测试开始", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        if not await self.wait_for_game_ready():
            return False

        # 运行牛图腾测试
        success = await self.run_cow_totem_test()

        return await self.generate_report(success)


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with TotemCowRetest3(http_port) as tester:
        success = await tester.run_all_tests()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
