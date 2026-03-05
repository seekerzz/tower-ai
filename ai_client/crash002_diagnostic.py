#!/usr/bin/env python3
"""
CRASH-002 诊断测试脚本

用于诊断 `ERROR: Parameter "t" is null.` 崩溃问题
测试场景：
A. 无单位部署测试 - 确认是否与单位/Taunt有关
B. 非牛图腾测试 - 确认是否特定于cow_totem
C. 最小化场景测试 - 仅选择图腾+启动波次
"""

import asyncio
import json
import time
import sys
import subprocess
import signal
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class Crash002Diagnostic:
    """CRASH-002 诊断测试器"""

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.log_file = None
        self.crashed = False
        self.crash_info = None

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_diagnostic_{timestamp}.log"

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

    async def test_scenario_a_no_units(self):
        """测试场景A: 无单位部署"""
        self.log("=" * 60, "TEST")
        self.log("测试场景A: 无单位部署 + 启动波次", "TEST")
        self.log("目的: 确认崩溃是否与单位/Taunt机制有关", "TEST")
        self.log("=" * 60, "TEST")

        # 选择牛图腾
        self.log("选择牛图腾 (cow_totem)", "ACTION")
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        # 不购买任何单位，直接启动波次
        self.log("不部署任何单位，直接启动第1波", "ACTION")
        await self.send_actions([{"type": "start_wave"}])

        # 观察是否崩溃
        self.log("观察是否发生崩溃...", "TEST")
        obs = await self.poll_observations(5.0)

        if self.crashed:
            self.log("❌ 场景A结果: 无单位时仍然崩溃 - 与Taunt无关", "RESULT")
            return False
        else:
            self.log("✅ 场景A结果: 无单位时不崩溃 - 可能与Taunt有关", "RESULT")
            return True

    async def test_scenario_b_other_totem(self, totem_id: str):
        """测试场景B: 其他图腾"""
        self.log("=" * 60, "TEST")
        self.log(f"测试场景B: {totem_id} + 部署单位 + 启动波次", "TEST")
        self.log("目的: 确认崩溃是否特定于cow_totem", "TEST")
        self.log("=" * 60, "TEST")

        # 选择其他图腾
        self.log(f"选择图腾 ({totem_id})", "ACTION")
        await self.send_actions([{"type": "select_totem", "totem_id": totem_id}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        # 购买并部署单位
        self.log("购买并部署单位", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        # 启动波次
        self.log("启动第1波", "ACTION")
        await self.send_actions([{"type": "start_wave"}])

        # 观察是否崩溃
        self.log("观察是否发生崩溃...", "TEST")
        obs = await self.poll_observations(5.0)

        if self.crashed:
            self.log(f"❌ 场景B结果: {totem_id} 也崩溃 - 不是cow_totem特定问题", "RESULT")
            return False
        else:
            self.log(f"✅ 场景B结果: {totem_id} 不崩溃 - 可能与cow_totem特定机制有关", "RESULT")
            return True

    async def test_scenario_c_minimal(self):
        """测试场景C: 最小化场景"""
        self.log("=" * 60, "TEST")
        self.log("测试场景C: 最小化场景 - 仅选择图腾", "TEST")
        self.log("目的: 确认崩溃是否发生在选择图腾阶段", "TEST")
        self.log("=" * 60, "TEST")

        # 仅选择图腾，不执行其他操作
        self.log("仅选择牛图腾，不进行其他操作", "ACTION")
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(3.0)

        if self.crashed:
            self.log("❌ 场景C结果: 选择图腾时就崩溃", "RESULT")
            return False
        else:
            self.log("✅ 场景C结果: 选择图腾不崩溃 - 崩溃发生在后续阶段", "RESULT")
            return True

    async def run_all_tests(self):
        """运行所有诊断测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("CRASH-002 诊断测试开始", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        if not await self.wait_for_game_ready():
            return False

        results = {}

        # 场景C: 最小化场景
        self.crashed = False
        results["minimal"] = await self.test_scenario_c_minimal()
        if self.crashed:
            self.log("最小化场景已崩溃，停止后续测试", "SYSTEM")
            return self.generate_report(results)

        # 场景A: 无单位
        self.crashed = False
        results["no_units"] = await self.test_scenario_a_no_units()
        if not self.crashed:
            self.log("无单位时不崩溃，继续测试其他图腾", "SYSTEM")

        # 场景B: 其他图腾
        if not self.crashed:
            for totem in ["viper_totem", "butterfly_totem", "wolf_totem"]:
                self.crashed = False
                results[f"totem_{totem}"] = await self.test_scenario_b_other_totem(totem)
                if self.crashed:
                    break

        return await self.generate_report(results)

    async def generate_report(self, results: Dict[str, bool]):
        """生成诊断报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("CRASH-002 诊断报告", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "CRASH-002 诊断报告",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试结果:",
        ]

        for test_name, passed in results.items():
            status = "✅ 通过" if passed else "❌ 失败/崩溃"
            report_lines.append(f"  {test_name}: {status}")

        report_lines.extend([
            "",
            "诊断结论:",
        ])

        if self.crash_info:
            report_lines.append(f"  崩溃信息: {self.crash_info}")

        # 分析结果
        if "no_units" in results:
            if results["no_units"]:
                report_lines.append("  - 无单位时不崩溃 → 可能与Taunt机制有关")
            else:
                report_lines.append("  - 无单位时也崩溃 → 与Taunt无关，是更底层问题")

        if any(k.startswith("totem_") for k in results):
            other_totems_crashed = [k for k, v in results.items() if k.startswith("totem_") and not v]
            if other_totems_crashed:
                report_lines.append(f"  - 其他图腾也崩溃 ({', '.join(other_totems_crashed)}) → 不是cow_totem特定问题")
            else:
                report_lines.append("  - 只有cow_totem崩溃 → 可能是cow_totem特定机制问题")

        report_lines.extend([
            "",
            "建议调查方向:",
            "  1. 检查AggroManager的初始化时机",
            "  2. 检查波次启动时的敌人生成逻辑",
            "  3. 检查TauntBehavior的空引用问题",
            "  4. 检查YakGuardian的嘲讽触发条件",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        return not self.crashed


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with Crash002Diagnostic(http_port) as tester:
        success = await tester.run_all_tests()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
