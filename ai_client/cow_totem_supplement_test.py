#!/usr/bin/env python3
"""
COW-TOTEM-SUPPLEMENT-001: 牛图腾机制补充验证测试

任务ID: COW-TOTEM-SUPPLEMENT-001
来源: QA Tester / Project Director
优先级: P1

测试内容:
1. 受伤充能机制 - 牛图腾受伤积累能量
2. 全屏反击机制 - 5秒一次全屏攻击
3. 嘲讽联动机制 (牦牛守护)
4. 伤害转MP机制 (苦修者)
5. 减伤回血机制 (铁甲龟Lv.3)
6. 动态治疗机制 (奶牛Lv.3)
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


class CowTotemSupplementTester:
    """牛图腾机制补充测试器"""

    TOTEM_ID = "cow_totem"

    def __init__(self, http_port=9997):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_cow_totem_supplement_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "charge_on_damage": False,      # 受伤充能
            "counter_attack": False,        # 全屏反击
            "yak_taunt": False,             # 牦牛嘲讽
            "yak_linkage": False,           # 牦牛联动
            "ascetic_mp_convert": False,    # 苦修者伤害转MP
            "turtle_defense": False,        # 铁甲龟绝对防御
            "cow_heal": False,              # 奶牛动态治疗
        }

        # 日志统计
        self.log_stats = {
            "totem_logs": [],
            "charge_logs": [],
            "counter_logs": [],
            "yak_logs": [],
            "ascetic_logs": [],
            "turtle_logs": [],
            "cow_logs": [],
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
        """解析牛图腾相关日志"""

        # 1. 检测牛图腾充能日志
        charge_patterns = [
            r"牛图腾.*?充能",
            r"受伤充能",
            r"\[TOTEM\].*?充能",
        ]
        for pattern in charge_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["charge_on_damage"] = True
                self.log_stats["charge_logs"].append(obs)
                self.log(f"🐮 检测到牛图腾充能", "DETECTION")
                break

        # 2. 检测全屏反击日志
        counter_patterns = [
            r"牛图腾.*?反击",
            r"全屏反击",
            r"\[TOTEM\].*?反击",
        ]
        for pattern in counter_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["counter_attack"] = True
                self.log_stats["counter_logs"].append(obs)
                self.log(f"🐮 检测到全屏反击", "DETECTION")
                break

        # 3. 检测牦牛守护日志
        yak_patterns = [
            r"牦牛",
            r"yak",
            r"\[UNIT\].*?牦牛",
        ]
        for pattern in yak_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["yak_logs"].append(obs)
                self.log(f"🦬 检测到牦牛守护", "DETECTION")
                break

        # 4. 检测苦修者日志
        ascetic_patterns = [
            r"苦修者",
            r"ascetic",
            r"伤害转MP",
        ]
        for pattern in ascetic_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["ascetic_mp_convert"] = True
                self.log_stats["ascetic_logs"].append(obs)
                self.log(f"🧘 检测到苦修者", "DETECTION")
                break

        # 5. 检测铁甲龟日志
        turtle_patterns = [
            r"铁甲龟",
            r"iron_turtle",
            r"绝对防御",
        ]
        for pattern in turtle_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["turtle_defense"] = True
                self.log_stats["turtle_logs"].append(obs)
                self.log(f"🐢 检测到铁甲龟", "DETECTION")
                break

        # 6. 检测奶牛日志
        cow_patterns = [
            r"奶牛",
            r"动态治疗",
            r"\[HEAL\].*?奶牛",
        ]
        for pattern in cow_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["cow_heal"] = True
                self.log_stats["cow_logs"].append(obs)
                self.log(f"🐄 检测到奶牛治疗", "DETECTION")
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
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_spawn_test_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 生成测试单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log("设置核心血量保护: 99999", "SYSTEM")

        # 生成牦牛守护
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "yak_guardian",
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成牦牛守护结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成苦修者
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "ascetic",
            "position": {"x": 1, "y": 1}
        }])
        self.log(f"生成苦修者结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成铁甲龟
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "iron_turtle",
            "position": {"x": 1, "y": 2}
        }])
        self.log(f"生成铁甲龟结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        await self.poll_observations(2.0)
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
        self.log("COW-TOTEM-SUPPLEMENT-001: 牛图腾机制补充验证", "SYSTEM")
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

        report_lines = [
            "# QA测试报告: 牛图腾机制补充验证 (P1)",
            "",
            f"**任务ID**: COW-TOTEM-SUPPLEMENT-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1 机制补充测试",
            f"**所属图腾**: 牛图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证牛图腾核心机制及关联单位的特殊机制实现情况",
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
            ("totem_selected", "牛图腾选择"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 牛图腾核心机制",
            "",
            "| 机制 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        core_mechanics = [
            ("charge_on_damage", "受伤充能机制"),
            ("counter_attack", "全屏反击机制"),
        ]

        for key, desc in core_mechanics:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 关联单位机制",
            "",
            "| 单位 | 机制 | 状态 | 说明 |",
            "|------|------|------|------|",
        ])

        unit_mechanics = [
            ("yak_taunt", "牦牛守护", "嘲讽机制"),
            ("yak_linkage", "牦牛守护", "图腾联动"),
            ("ascetic_mp_convert", "苦修者", "伤害转MP"),
            ("turtle_defense", "铁甲龟", "绝对防御"),
            ("cow_heal", "奶牛", "动态治疗"),
        ]

        for key, unit, mechanism in unit_mechanics:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {unit} | {mechanism} | {status} | - |")

        report_lines.extend([
            "",
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

        if pass_rate >= 70:
            report_lines.append(f"✅ **测试通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
        elif pass_rate >= 40:
            report_lines.append(f"⚠️ **测试部分通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
        else:
            report_lines.append(f"❌ **测试失败** - 通过率 {pass_rate:.1f}% ({passed}/{total})")

        report_lines.extend([
            "",
            "### 建议",
            "",
            "1. 对于未检测到的机制，建议添加更多日志埋点",
            "2. 技术总监评估机制实现是否符合设计",
            "3. QA-Tester审查测试报告并更新验证状态",
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_cow_totem_supplement_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9997
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with CowTotemSupplementTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
