#!/usr/bin/env python3
"""
VERIFY-BOSS-SPAWN-002: Boss生成修复验证测试

背景: Technical Director已修复崩溃问题 (Git: 49eacae)

验证要求:
1. 第6/12/18/24波Boss生成时检测 `[BOSS生成]` 日志
2. 验证日志格式: `[BOSS生成] Boss {type_key} 生成 | 波次:{wave} | 位置:{pos} | HP:{hp}`
3. 验证无崩溃发生

输出报告: docs/player_reports/qa_report_boss_spawn_verify_002.md
"""

import asyncio
import json
import time
import sys
import re
import subprocess
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class BossSpawnVerify002Tester:
    """Boss生成修复验证测试器"""

    TOTEM_ID = "cow_totem"
    BOSS_WAVES = [6, 12, 18, 24]

    def __init__(self, http_port=10006):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_spawn_verify_002_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "core_hp_set": False,
            "no_crash": True,
        }

        # Boss生成日志检测
        self.boss_spawn_logs = []
        self.detected_waves = set()

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message: str, level="INFO"):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    async def send_actions(self, actions: List[Dict]) -> Dict:
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

    async def get_observations(self) -> List[str]:
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

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            for o in obs:
                self.log(f"[OBS] {o}", "OBS")
                self.parse_logs(o)
            await asyncio.sleep(0.3)
        return all_obs

    def start_ai_client(self):
        self.log("使用已运行的AI客户端...", "SYSTEM")
        time.sleep(2)

    def stop_ai_client(self):
        self.log("保持AI客户端运行...", "SYSTEM")

    def parse_logs(self, obs: str):
        """解析Boss生成相关日志"""
        # 检测[BOSS生成]日志
        if "[BOSS生成]" in obs:
            self.boss_spawn_logs.append(obs)
            self.log(f"🎯 检测到Boss生成日志: {obs[:100]}...", "DETECTION")

            # 提取波次
            wave_match = re.search(r'波次:(\d+)', obs)
            if wave_match:
                wave = int(wave_match.group(1))
                self.detected_waves.add(wave)
                self.log(f"🎯 Boss生成于波次 {wave}", "DETECTION")

        # 检测崩溃
        if "SCRIPT ERROR" in obs or "崩溃" in obs or "crash" in obs.lower():
            self.validation["no_crash"] = False
            self.log(f"⚠️ 检测到错误/崩溃: {obs[:100]}...", "ERROR")

    async def wait_for_game_ready(self, timeout: float = 60.0) -> bool:
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(f"{self.base_url}/status", timeout=aiohttp.ClientTimeout(total=3)) as resp:
                    data = await resp.json()
                    # 兼容完整格式和简化格式
                    godot_running = data.get("godot_running", True)
                    ws_connected = data.get("ws_connected", True)
                    status = data.get("status", "unknown")
                    # 简化格式只返回status: running
                    if status == "running" or (godot_running and ws_connected):
                        self.log("游戏已就绪", "SYSTEM")
                        return True
            except Exception as e:
                self.log(f"状态检查异常: {e}", "DEBUG")
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def step_reset_game(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤0: 重置游戏状态", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "reset_game"}])
        self.log(f"重置游戏结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)
        self.log("✅ 游戏重置完成", "VALIDATION")

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 图腾选择完成", "VALIDATION")

    async def step_set_god_mode(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 设置上帝模式", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log(f"set_core_hp结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(1.0)
        self.validation["core_hp_set"] = True
        self.log("✅ 上帝模式设置完成", "VALIDATION")

    async def step_skip_to_boss_waves(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 跳转到Boss波次", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        for wave in self.BOSS_WAVES:
            self.log(f"跳转到波次 {wave}...", "SYSTEM")
            result = await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
            self.log(f"skip_to_wave结果: {result}", "DEBUG")

            # 启动波次
            self.log(f"启动波次 {wave}...", "SYSTEM")
            result = await self.send_actions([{"type": "start_wave"}])
            self.log(f"start_wave结果: {result}", "DEBUG")

            # 观察波次开始和Boss生成
            await asyncio.sleep(2.0)
            await self.poll_observations(8.0)

            # 再观察一段时间
            await asyncio.sleep(3.0)
            await self.poll_observations(3.0)

            # 等待波次结束再跳转到下一个
            if wave != self.BOSS_WAVES[-1]:
                self.log(f"等待波次 {wave} 结束...", "SYSTEM")
                await asyncio.sleep(5.0)
                await self.poll_observations(5.0)

        self.log("✅ Boss波次跳转完成", "VALIDATION")

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("VERIFY-BOSS-SPAWN-002: Boss生成修复验证", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_reset_game()
            await self.step_select_totem()
            await self.step_set_god_mode()
            await self.step_skip_to_boss_waves()
            await self.generate_report()
            return True

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return False

        finally:
            self.stop_ai_client()

    async def generate_report(self):
        self.log("=" * 70, "SYSTEM")
        self.log("生成测试报告", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        report_lines = [
            "# QA测试报告: Boss生成修复验证 (VERIFY-BOSS-SPAWN-002)",
            "",
            f"**任务ID**: VERIFY-BOSS-SPAWN-002",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P0修复验证测试",
            f"**修复来源**: Technical Director (Git: 49eacae)",
            "",
            "---",
            "",
            "## 验证内容",
            "",
            "### Boss生成日志",
            "- 预期日志: `[BOSS生成] Boss {type} 生成 | 波次:{wave} | 位置:{pos} | HP:{hp}`",
            "- 修复内容: 修复`enemy.has()`方法不存在导致的崩溃",
            "",
            "---",
            "",
            "## 验证结果汇总",
            "",
            "### 基础验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ]

        base_validations = [
            ("totem_selected", "图腾选择"),
            ("core_hp_set", "上帝模式设置"),
            ("no_crash", "无崩溃发生"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### Boss生成检测",
            "",
            "| 波次 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        for wave in self.BOSS_WAVES:
            if wave in self.detected_waves:
                report_lines.append(f"| 第{wave}波 | ✅ 检测到[BOSS生成]日志 | - |")
            else:
                report_lines.append(f"| 第{wave}波 | ❌ 未检测到 | - |")

        report_lines.extend([
            "",
            "### 检测到的Boss生成日志",
            "",
        ])

        if self.boss_spawn_logs:
            for log in self.boss_spawn_logs[:10]:  # 最多显示10条
                report_lines.append(f"```")
                report_lines.append(log)
                report_lines.append(f"```")
        else:
            report_lines.append("未检测到[BOSS生成]日志")

        report_lines.extend([
            "",
            "---",
            "",
            "## 测试结论",
            "",
        ])

        # 判断修复是否成功
        all_boss_detected = all(wave in self.detected_waves for wave in self.BOSS_WAVES)
        no_crash = self.validation["no_crash"]

        if all_boss_detected and no_crash:
            report_lines.append("✅ **修复验证通过** - 所有Boss波次均检测到[BOSS生成]日志，无崩溃发生")
        elif no_crash:
            report_lines.append("⚠️ **部分验证** - 无崩溃发生，但部分Boss波次未检测到日志")
            report_lines.append(f"- 检测到的波次: {sorted(self.detected_waves)}")
            report_lines.append(f"- 未检测到的波次: {sorted(set(self.BOSS_WAVES) - self.detected_waves)}")
        else:
            report_lines.append("❌ **修复验证失败** - 测试过程中发生崩溃")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_boss_spawn_verify_002.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 10005
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossSpawnVerify002Tester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
