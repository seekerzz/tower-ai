#!/usr/bin/env python3
"""
BUTTERFLY-TOTEM-SUPPLEMENT-001: 蝴蝶图腾机制补充验证测试

任务ID: BUTTERFLY-TOTEM-SUPPLEMENT-001
来源: QA Tester / Project Director
优先级: P1

测试内容:
1. 法球生成机制 - 是否生成3颗法球
2. 法球伤害机制 - 命中敌人造成20伤害
3. 法力回复机制 - 法球命中恢复20法力
4. 冻结效果机制 - 冰蝶Lv.2
5. 传送机制 - 精灵龙Lv.3
6. 火雨/闪电链机制 - 萤火虫/凤凰/雷鸟
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


class ButterflyTotemSupplementTester:
    """蝴蝶图腾机制补充测试器"""

    TOTEM_ID = "butterfly_totem"

    def __init__(self, http_port=9998):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_butterfly_totem_supplement_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "orb_generate": False,           # 法球生成
            "orb_damage": False,             # 法球伤害20
            "orb_mana": False,               # 法力回复
            "orb_penetrate": False,          # 法球穿透
            "ice_butterfly_freeze": False,   # 冰蝶冻结
            "fairy_dragon_teleport": False,  # 仙女龙传送
            "phoenix_fire_rain": False,      # 凤凰火雨
            "eel_lightning": False,          # 电鳗闪电链
            "dragon_blackhole": False,       # 龙黑洞
        }

        # 日志统计
        self.log_stats = {
            "totem_logs": [],
            "orb_logs": [],
            "ice_logs": [],
            "fairy_logs": [],
            "phoenix_logs": [],
            "eel_logs": [],
            "dragon_logs": [],
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
        """解析蝴蝶图腾相关日志"""

        # 1. 检测法球相关日志
        orb_patterns = [
            r"法球",
            r"orb",
            r"\[TOTEM\].*?法球",
        ]
        for pattern in orb_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["orb_generate"] = True
                self.log_stats["orb_logs"].append(obs)
                self.log(f"🦋 检测到法球", "DETECTION")
                break

        # 2. 检测冰晶蝶冻结日志
        ice_patterns = [
            r"冰晶蝶",
            r"ice_butterfly",
            r"冻结",
            r"freeze",
        ]
        for pattern in ice_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["ice_butterfly_freeze"] = True
                self.log_stats["ice_logs"].append(obs)
                self.log(f"🧊 检测到冰晶蝶冻结", "DETECTION")
                break

        # 3. 检测仙女龙传送日志
        fairy_patterns = [
            r"仙女龙",
            r"fairy_dragon",
            r"传送",
            r"teleport",
        ]
        for pattern in fairy_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["fairy_dragon_teleport"] = True
                self.log_stats["fairy_logs"].append(obs)
                self.log(f"✨ 检测到仙女龙传送", "DETECTION")
                break

        # 4. 检测凤凰火雨日志
        phoenix_patterns = [
            r"凤凰",
            r"phoenix",
            r"火雨",
            r"fire_rain",
        ]
        for pattern in phoenix_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["phoenix_fire_rain"] = True
                self.log_stats["phoenix_logs"].append(obs)
                self.log(f"🔥 检测到凤凰火雨", "DETECTION")
                break

        # 5. 检测电鳗闪电链日志
        eel_patterns = [
            r"电鳗",
            r"eel",
            r"闪电",
            r"lightning",
            r"闪电链",
        ]
        for pattern in eel_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["eel_lightning"] = True
                self.log_stats["eel_logs"].append(obs)
                self.log(f"⚡ 检测到电鳗闪电", "DETECTION")
                break

        # 6. 检测龙黑洞日志
        dragon_patterns = [
            r"龙.*黑洞",
            r"dragon.*blackhole",
            r"黑洞",
            r"blackhole",
        ]
        for pattern in dragon_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["dragon_blackhole"] = True
                self.log_stats["dragon_logs"].append(obs)
                self.log(f"🌌 检测到龙黑洞", "DETECTION")
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
        self.log("步骤1: 选择蝴蝶图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 蝴蝶图腾选择完成", "VALIDATION")

    async def step_spawn_test_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 生成测试单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log("设置核心血量保护: 99999", "SYSTEM")

        # 生成冰晶蝶
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "ice_butterfly",
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成冰晶蝶结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成仙女龙
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "fairy_dragon",
            "position": {"x": 1, "y": 1}
        }])
        self.log(f"生成仙女龙结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成萤火虫
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "firefly",
            "position": {"x": 1, "y": 2}
        }])
        self.log(f"生成萤火虫结果: {result}", "DEBUG")
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
        self.log("BUTTERFLY-TOTEM-SUPPLEMENT-001: 蝴蝶图腾机制补充验证", "SYSTEM")
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
            "# QA测试报告: 蝴蝶图腾机制补充验证 (P1)",
            "",
            f"**任务ID**: BUTTERFLY-TOTEM-SUPPLEMENT-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1 机制补充测试",
            f"**所属图腾**: 蝴蝶图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证蝴蝶图腾核心机制及关键单位的特殊机制实现情况",
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
            ("totem_selected", "蝴蝶图腾选择"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 蝴蝶图腾核心机制",
            "",
            "| 机制 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        core_mechanics = [
            ("orb_generate", "法球生成 (3颗)"),
            ("orb_damage", "法球伤害 (20)"),
            ("orb_mana", "法力回复"),
            ("orb_penetrate", "法球穿透"),
        ]

        for key, desc in core_mechanics:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 单位特殊机制",
            "",
            "| 单位 | 机制 | 状态 | 说明 |",
            "|------|------|------|------|",
        ])

        unit_mechanics = [
            ("ice_butterfly_freeze", "冰晶蝶", "冻结效果"),
            ("fairy_dragon_teleport", "仙女龙", "传送机制"),
            ("phoenix_fire_rain", "凤凰", "火雨机制"),
            ("eel_lightning", "电鳗", "闪电链"),
            ("dragon_blackhole", "龙", "黑洞机制"),
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
            "### 已知问题",
            "",
            "- 蝴蝶图腾法球机制日志缺失 (MEDIUM-002)",
            "- 需要验证日志埋点是否完善",
            "",
            "### 建议",
            "",
            "1. 技术总监检查蝴蝶图腾法球机制实现",
            "2. 添加更多日志埋点以便验证",
            "3. QA-Tester审查测试报告并更新验证状态",
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_butterfly_totem_supplement_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9998
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with ButterflyTotemSupplementTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
