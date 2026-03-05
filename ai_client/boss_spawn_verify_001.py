#!/usr/bin/env python3
"""
VERIFY-BOSS-SPAWN-001: Boss生成修复验证测试

验证内容:
1. 第6/12/18/24波Boss生成时是否有[BOSS生成]日志
2. 日志格式是否正确: [BOSS生成] Boss {type_key} 生成 | 波次:{wave} | 位置:{pos} | HP:{hp}
3. 日志信息是否完整(type_key, wave, pos, hp)

修复来源: Technical Director (Git: 35a4967)
输出报告: docs/player_reports/qa_report_boss_spawn_verify_001.md
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


class BossSpawnVerifyTester:
    """Boss生成修复验证测试器"""

    BOSS_WAVES = [6, 12, 18, 24]

    def __init__(self, http_port=9997):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_spawn_verify_{timestamp}.log"

        # 验证结果
        self.validation = {
            # 各波次Boss生成验证
            "wave_6_boss_spawn": False,
            "wave_12_boss_spawn": False,
            "wave_18_boss_spawn": False,
            "wave_24_boss_spawn": False,

            # 日志格式验证
            "log_format_correct": False,
            "has_type_key": False,
            "has_wave": False,
            "has_position": False,
            "has_hp": False,
        }

        # 检测到的Boss生成日志
        self.boss_spawn_logs = {
            6: [],
            12: [],
            18: [],
            24: [],
        }

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
        self.log("启动AI客户端...", "SYSTEM")
        project_dir = Path(__file__).parent.parent
        client_script = project_dir / "ai_client" / "ai_game_client.py"

        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"

        self.client_process = subprocess.Popen(
            [
                sys.executable,
                str(client_script),
                "--project", str(project_dir),
                "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
                "--http-port", str(self.http_port)
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            cwd=str(project_dir),
            env=env
        )
        time.sleep(12)
        self.log(f"AI客户端已启动 (PID: {self.client_process.pid})", "SYSTEM")

    def stop_ai_client(self):
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.client_process = None

    def parse_logs(self, obs: str):
        """解析Boss生成日志"""

        # 检测[BOSS生成]日志
        boss_spawn_pattern = r"\[BOSS生成\].*?Boss\s+(\w+)\s+生成.*?波次:(\d+).*?位置:(.+?)\|.*?HP:(\d+)"
        match = re.search(boss_spawn_pattern, obs)

        if match:
            type_key = match.group(1)
            wave = int(match.group(2))
            position = match.group(3)
            hp = match.group(4)

            self.log(f"👹 检测到[BOSS生成]日志: {type_key} | 波次:{wave} | HP:{hp}", "DETECTION")

            # 记录到对应波次
            if wave in self.BOSS_WAVES:
                self.boss_spawn_logs[wave].append({
                    "type_key": type_key,
                    "wave": wave,
                    "position": position,
                    "hp": hp,
                    "raw_log": obs
                })
                self.validation[f"wave_{wave}_boss_spawn"] = True

            # 验证日志格式
            self.validation["log_format_correct"] = True
            self.validation["has_type_key"] = bool(type_key)
            self.validation["has_wave"] = bool(wave)
            self.validation["has_position"] = bool(position)
            self.validation["has_hp"] = bool(hp)

        # 也检测其他可能的Boss生成日志格式
        alt_patterns = [
            r"BOSS生成.*?Boss",
            r"\[BOSS\].*?生成",
            r"Boss.*?生成.*?波次",
        ]
        for pattern in alt_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                if not match:  # 如果之前没有匹配到标准格式
                    self.log(f"👹 检测到可能的Boss生成日志(非标准格式): {obs[:100]}", "DETECTION")
                break

    async def wait_for_game_ready(self, timeout: float = 60.0) -> bool:
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(f"{self.base_url}/status", timeout=aiohttp.ClientTimeout(total=3)) as resp:
                    data = await resp.json()
                    if data.get("godot_running") and data.get("ws_connected"):
                        self.log("游戏已就绪", "SYSTEM")
                        return True
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择牛图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_set_god_mode(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 设置上帝模式", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log(f"set_core_hp结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(1.0)
        self.log("✅ 上帝模式设置完成", "VALIDATION")

    async def step_test_boss_wave(self, wave: int):
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤: 测试第{wave}波Boss生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 跳转到指定波次
        result = await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
        self.log(f"skip_to_wave({wave})结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)

        # 开始波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察Boss生成
        self.log(f"观察第{wave}波Boss生成...", "SYSTEM")
        observe_duration = 30
        start_time = time.time()

        while time.time() - start_time < observe_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"⚠️ 游戏结束", "WARNING")
                    return False

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"✅ 第{wave}波完成", "EVENT")
                    return True

        self.log(f"✅ 第{wave}波观察完成", "VALIDATION")
        return True

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("VERIFY-BOSS-SPAWN-001: Boss生成修复验证", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")
        self.log(f"验证波次: {self.BOSS_WAVES}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_set_god_mode()

            # 测试每个Boss波次
            for wave in self.BOSS_WAVES:
                await self.step_test_boss_wave(wave)
                await asyncio.sleep(2.0)

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
            "# QA测试报告: Boss生成修复验证 (VERIFY-BOSS-SPAWN-001)",
            "",
            f"**任务ID**: VERIFY-BOSS-SPAWN-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P0修复验证测试",
            f"**修复来源**: Technical Director (Git: 35a4967)",
            "",
            "---",
            "",
            "## 验证内容",
            "",
            "验证Boss生成日志埋点修复:",
            "1. 第6/12/18/24波Boss生成时是否有`[BOSS生成]`日志",
            "2. 日志格式是否正确: `[BOSS生成] Boss {type_key} 生成 | 波次:{wave} | 位置:{pos} | HP:{hp}`",
            "3. 日志信息是否完整(type_key, wave, pos, hp)",
            "",
            "---",
            "",
            "## 验证结果汇总",
            "",
            "### 各波次Boss生成验证",
            "",
            "| 波次 | Boss生成日志 | 状态 |",
            "|------|-------------|------|",
        ]

        for wave in self.BOSS_WAVES:
            detected = self.validation[f"wave_{wave}_boss_spawn"]
            status = "✅ 检测到" if detected else "❌ 未检测到"
            log_count = len(self.boss_spawn_logs[wave])
            report_lines.append(f"| 第{wave}波 | {log_count} 条 | {status} |")

        report_lines.extend([
            "",
            "### 日志格式验证",
            "",
            "| 验证项 | 状态 |",
            "|--------|------|",
        ])

        format_checks = [
            ("log_format_correct", "标准格式匹配"),
            ("has_type_key", "包含type_key"),
            ("has_wave", "包含wave"),
            ("has_position", "包含position"),
            ("has_hp", "包含HP"),
        ]

        for key, desc in format_checks:
            status = "✅ 是" if self.validation[key] else "❌ 否"
            report_lines.append(f"| {desc} | {status} |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 检测到的Boss生成日志详情",
            "",
        ])

        for wave in self.BOSS_WAVES:
            logs = self.boss_spawn_logs[wave]
            report_lines.append(f"### 第{wave}波")
            report_lines.append("")
            if logs:
                for log in logs:
                    report_lines.append(f"- **Boss类型**: {log['type_key']}")
                    report_lines.append(f"- **波次**: {log['wave']}")
                    report_lines.append(f"- **位置**: {log['position']}")
                    report_lines.append(f"- **HP**: {log['hp']}")
                    report_lines.append("")
            else:
                report_lines.append("*未检测到Boss生成日志*")
                report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## 测试结论",
            "",
        ])

        # 统计结果
        detected_waves = sum([
            self.validation["wave_6_boss_spawn"],
            self.validation["wave_12_boss_spawn"],
            self.validation["wave_18_boss_spawn"],
            self.validation["wave_24_boss_spawn"],
        ])

        if detected_waves == 4:
            report_lines.append("✅ **修复验证通过** - 所有波次(6/12/18/24)均检测到[BOSS生成]日志")
            report_lines.append("")
            report_lines.append("### 验证详情")
            report_lines.append(f"- 检测到的波次: {detected_waves}/4")
            report_lines.append(f"- 日志格式正确: {'是' if self.validation['log_format_correct'] else '否'}")
            report_lines.append(f"- 日志信息完整: {'是' if all([self.validation['has_type_key'], self.validation['has_wave'], self.validation['has_position'], self.validation['has_hp']]) else '否'}")
        elif detected_waves > 0:
            report_lines.append(f"⚠️ **部分验证通过** - 检测到{detected_waves}/4个波次的Boss生成日志")
            report_lines.append("")
            report_lines.append("### 未检测到的波次")
            for wave in self.BOSS_WAVES:
                if not self.validation[f"wave_{wave}_boss_spawn"]:
                    report_lines.append(f"- 第{wave}波")
        else:
            report_lines.append("❌ **修复验证失败** - 未检测到任何[BOSS生成]日志")
            report_lines.append("")
            report_lines.append("### 可能原因")
            report_lines.append("1. 修复尚未部署到测试环境")
            report_lines.append("2. 日志标记格式与预期不符")
            report_lines.append("3. 需要检查技术总监的修复提交是否已合并")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_boss_spawn_verify_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9997
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossSpawnVerifyTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
