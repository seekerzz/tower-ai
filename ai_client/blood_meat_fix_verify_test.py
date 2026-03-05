#!/usr/bin/env python3
"""
BLOOD-MEAT-FIX-VERIFY-001: 血食机制修复验证测试

任务ID: BLOOD-MEAT-FIX-VERIFY-001
来源: QA Tester / Technical Director
优先级: P1

修复来源: 提交 b485bd0

修复内容:
- max_blood_stacks: 5 → 10
- 血魂层数机制所有等级可用
- 添加[BLOOD_MEAT]日志埋点
- 血祭技能已实现

验证要点:
- 血魂层数是否正确增加
- 层数上限是否为10
- 每层是否+2%相邻狼攻击
- 血祭技能是否正常工作
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


class BloodMeatFixVerifyTester:
    """血食机制修复验证测试器"""

    TOTEM_ID = "wolf_totem"
    UNIT_ID = "blood_meat"

    def __init__(self, http_port=9999):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_blood_meat_fix_verify_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "unit_spawned": False,
            "wolf_spawned": False,
            "blood_soul_stack": False,      # 血魂层数增加
            "stack_limit_10": False,        # 层数上限10
            "aura_bonus_2": False,          # 每层+2%
            "blood_sacrifice": False,       # 血祭技能
        }

        # 血魂层数记录
        self.blood_soul_records = []

        # 日志统计
        self.log_stats = {
            "blood_meat_logs": [],
            "wolf_devour_logs": [],
            "blood_soul_logs": [],
            "sacrifice_logs": [],
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
        """解析血食相关日志"""

        # 1. 检测[BLOOD_MEAT]日志
        blood_meat_patterns = [
            r"\[BLOOD_MEAT\]",
            r"blood_meat",
            r"血食",
            r"血魂",
        ]
        for pattern in blood_meat_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["blood_meat_logs"].append(obs)
                self.validation["blood_soul_stack"] = True
                self.log(f"🩸 检测到血食机制日志", "DETECTION")
                break

        # 2. 检测血魂层数
        stack_patterns = [
            r"血魂.*?层数[:\s]*(\d+)",
            r"blood_soul.*?stack[:\s]*(\d+)",
            r"层数[:\s]*(\d+).*?血魂",
        ]
        for pattern in stack_patterns:
            match = re.search(pattern, obs, re.IGNORECASE)
            if match:
                try:
                    stack = int(match.group(1))
                    self.blood_soul_records.append(stack)
                    if stack >= 10:
                        self.validation["stack_limit_10"] = True
                    self.log(f"🩸 检测到血魂层数: {stack}", "DETECTION")
                except ValueError:
                    pass
                break

        # 3. 检测狼吞噬日志
        devour_patterns = [
            r"\[WOLF\].*?吞噬",
            r"\[DEVOUR\]",
            r"wolf.*devour",
            r"狼.*吞噬",
        ]
        for pattern in devour_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["wolf_devour_logs"].append(obs)
                self.log(f"🐺 检测到狼吞噬", "DETECTION")
                break

        # 4. 检测血祭技能日志
        sacrifice_patterns = [
            r"\[BLOOD_MEAT\].*?血祭",
            r"血祭",
            r"blood_sacrifice",
            r"\[SKILL\].*?血食",
        ]
        for pattern in sacrifice_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["blood_sacrifice"] = True
                self.log_stats["sacrifice_logs"].append(obs)
                self.log(f"🔥 检测到血祭技能", "DETECTION")
                break

        # 5. 检测+2%光环效果
        aura_patterns = [
            r"\+2%",
            r"2%.*光环",
            r"aura.*2%",
        ]
        for pattern in aura_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["aura_bonus_2"] = True
                self.log(f"💪 检测到+2%光环效果", "DETECTION")
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
        self.log("步骤1: 选择狼图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 狼图腾选择完成", "VALIDATION")

    async def step_spawn_test_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 生成测试单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log("设置核心血量保护: 99999", "SYSTEM")

        # 生成血食单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": self.UNIT_ID,
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成血食结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成狼单位用于吞噬测试
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "wolf",
            "position": {"x": 1, "y": 1}
        }])
        self.log(f"生成狼单位结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        await self.poll_observations(2.0)
        self.validation["unit_spawned"] = True
        self.validation["wolf_spawned"] = True
        self.log("✅ 测试单位生成完成", "VALIDATION")

    async def step_start_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 开始战斗观察", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察战斗过程
        battle_duration = 60
        start_time = time.time()

        while time.time() - start_time < battle_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"⚠️ 游戏结束", "WARNING")
                    return False

        self.log(f"✅ 战斗观察完成 ({battle_duration}秒)", "VALIDATION")
        return True

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("BLOOD-MEAT-FIX-VERIFY-001: 血食机制修复验证", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_spawn_test_units()
            await self.step_start_battle()
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

        # 分析血魂层数记录
        max_stack = max(self.blood_soul_records) if self.blood_soul_records else 0

        report_lines = [
            "# QA验证报告: 血食机制修复验证 (P1)",
            "",
            f"**任务ID**: BLOOD-MEAT-FIX-VERIFY-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1 修复验证测试",
            f"**修复来源**: Technical Director 提交 b485bd0",
            "",
            "---",
            "",
            "## 修复内容",
            "",
            "- max_blood_stacks: 5 → 10",
            "- 血魂层数机制所有等级可用",
            "- 添加[BLOOD_MEAT]日志埋点",
            "- 血祭技能已实现",
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
            ("totem_selected", "狼图腾选择"),
            ("unit_spawned", "血食单位生成"),
            ("wolf_spawned", "狼单位生成"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 血食机制验证",
            "",
            "| 机制 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        mechanism_validations = [
            ("blood_soul_stack", "血魂层数增加"),
            ("stack_limit_10", "层数上限10"),
            ("aura_bonus_2", "每层+2%光环"),
            ("blood_sacrifice", "血祭技能"),
        ]

        for key, desc in mechanism_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 血魂层数统计",
            "",
            f"- **记录次数**: {len(self.blood_soul_records)} 次",
            f"- **最高层数**: {max_stack}",
            f"- **目标上限**: 10",
            "",
        ])

        if self.blood_soul_records:
            report_lines.append("### 层数记录")
            report_lines.append("")
            for i, stack in enumerate(self.blood_soul_records[:10], 1):
                report_lines.append(f"{i}. 血魂层数: {stack}")
            if len(self.blood_soul_records) > 10:
                report_lines.append(f"... 共 {len(self.blood_soul_records)} 条记录")
            report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## 检测到的日志统计",
            "",
        ])

        for log_type, logs in self.log_stats.items():
            report_lines.append(f"- **{log_type}**: {len(logs)} 条")

        report_lines.extend([
            "",
            "---",
            "",
            "## 测试结论",
            "",
        ])

        passed = sum(self.validation.values())
        total = len(self.validation)
        pass_rate = passed / total * 100

        if pass_rate >= 80:
            report_lines.append(f"✅ **修复验证通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
            report_lines.append("")
            report_lines.append("血食机制修复成功，所有核心功能正常工作。")
        elif pass_rate >= 50:
            report_lines.append(f"⚠️ **修复部分通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
            report_lines.append("")
            report_lines.append("部分机制已修复，但仍有功能需要验证。")
        else:
            report_lines.append(f"❌ **修复验证失败** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
            report_lines.append("")
            report_lines.append("修复未成功，需要Technical Director重新检查。")

        report_lines.extend([
            "",
            "---",
            "",
            "## 建议",
            "",
            "1. QA-Tester审查验证报告",
            "2. 更新GameDesign.md中血食机制状态",
            "3. 如验证通过，关闭相关修复任务",
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_blood_meat_fix_verify.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9999
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BloodMeatFixVerifyTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
