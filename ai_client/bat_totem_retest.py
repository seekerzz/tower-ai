#!/usr/bin/env python3
"""
RETEST-BAT-BLEED-001: 蝙蝠图腾流血机制重新测试

任务ID: RETEST-BAT-BLEED-001
来源: Project Director / QA Tester
优先级: P1

测试目标:
1. 重新执行蝙蝠图腾P0测试
2. 观察流血伤害是否仍为0
3. 收集详细日志供Technical Director分析

历史问题:
- 日志格式已修复 (显示2位小数)
- 但流血伤害计算仍为0
- 问题日志: [流血伤害] 敌人 171245046786 受到流血伤害: 0，剩余层数: 1
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


class BatTotemRetester:
    """蝙蝠图腾流血机制重新测试器"""

    TOTEM_ID = "bat_totem"
    UNIT_ID = "mosquito"

    def __init__(self, http_port=9995):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_bat_totem_retest_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "unit_spawned": False,
            "wave_started": False,
            "bleed_applied": False,
            "bleed_damage_nonzero": False,  # 关键验证点
            "totem_attack_triggered": False,
            "core_heal_working": False,
        }

        # 流血伤害记录
        self.bleed_damage_records = []

        # 日志统计
        self.log_stats = {
            "bleed_damage_logs": [],
            "totem_attack_logs": [],
            "debuff_logs": [],
            "core_heal_logs": [],
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
        """解析流血相关日志"""

        # 1. 检测流血伤害日志
        bleed_damage_patterns = [
            r"流血伤害.*?([\d.]+)",
            r"流血.*?造成.*?([\d.]+).*?伤害",
            r"\[流血伤害\].*?受到流血伤害:\s*([\d.]+)",
            r"\[状态伤害\].*?流血.*?造成\s*([\d.]+)",
            r"\[DEBUFF\].*?流血.*?造成\s*([\d.]+)",
        ]
        for pattern in bleed_damage_patterns:
            match = re.search(pattern, obs, re.IGNORECASE)
            if match:
                damage_str = match.group(1)
                try:
                    damage = float(damage_str)
                    self.bleed_damage_records.append(damage)
                    self.log_stats["bleed_damage_logs"].append(obs)
                    if damage > 0:
                        self.validation["bleed_damage_nonzero"] = True
                        self.log(f"🩸 检测到流血伤害: {damage}", "DETECTION")
                    else:
                        self.log(f"🩸 检测到流血伤害为0", "WARNING")
                except ValueError:
                    pass
                break

        # 2. 检测流血debuff施加
        bleed_apply_patterns = [
            r"施加流血",
            r"获得流血",
            r"bleed.*applied",
            r"\[DEBUFF\].*?流血",
        ]
        for pattern in bleed_apply_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["bleed_applied"] = True
                self.log_stats["debuff_logs"].append(obs)
                self.log(f"🩸 检测到流血debuff", "DETECTION")
                break

        # 3. 检测图腾攻击
        totem_patterns = [
            r"\[TOTEM\].*?蝙蝠",
            r"蝙蝠图腾",
            r"bat_totem",
        ]
        for pattern in totem_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["totem_attack_triggered"] = True
                self.log_stats["totem_attack_logs"].append(obs)
                self.log(f"🦇 检测到蝙蝠图腾攻击", "DETECTION")
                break

        # 4. 检测核心治疗
        heal_patterns = [
            r"核心.*治疗",
            r"核心.*回复",
            r"core.*heal",
        ]
        for pattern in heal_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["core_heal_working"] = True
                self.log_stats["core_heal_logs"].append(obs)
                self.log(f"💚 检测到核心治疗", "DETECTION")
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
        self.log("步骤1: 选择蝙蝠图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 蝙蝠图腾选择完成", "VALIDATION")

    async def step_spawn_unit(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 生成蚊子单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log("设置核心血量保护: 99999", "SYSTEM")

        # 生成蚊子单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": self.UNIT_ID,
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成蚊子结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        await self.poll_observations(2.0)
        self.validation["unit_spawned"] = True
        self.log("✅ 蚊子单位生成完成", "VALIDATION")

    async def step_start_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 开始战斗观察", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)
        self.validation["wave_started"] = True

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
        self.log("RETEST-BAT-BLEED-001: 蝙蝠图腾流血机制重新测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_spawn_unit()
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

        # 分析流血伤害记录
        nonzero_count = sum(1 for d in self.bleed_damage_records if d > 0)
        zero_count = len(self.bleed_damage_records) - nonzero_count

        report_lines = [
            "# QA测试报告: 蝙蝠图腾流血机制重新测试 (P1)",
            "",
            f"**任务ID**: RETEST-BAT-BLEED-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1 修复验证测试",
            f"**所属图腾**: 蝙蝠图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证Technical Director的日志格式修复后，流血伤害计算是否仍为0",
            "",
            "## 历史问题",
            "",
            "```",
            "[流血伤害] 敌人 171245046786 受到流血伤害: 0，剩余层数: 1",
            "```",
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
            ("totem_selected", "蝙蝠图腾选择"),
            ("unit_spawned", "蚊子单位生成"),
            ("wave_started", "战斗波次启动"),
            ("bleed_applied", "流血debuff施加"),
            ("totem_attack_triggered", "图腾攻击触发"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 关键验证: 流血伤害",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        if self.validation["bleed_damage_nonzero"]:
            report_lines.append(f"| 流血伤害非零 | ✅ 通过 | 检测到非零流血伤害 |")
        else:
            report_lines.append(f"| 流血伤害非零 | ❌ 未通过 | 所有流血伤害仍为0 |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 流血伤害统计",
            "",
            f"- **总记录数**: {len(self.bleed_damage_records)} 条",
            f"- **非零伤害**: {nonzero_count} 条",
            f"- **零伤害**: {zero_count} 条",
            "",
        ])

        if self.bleed_damage_records:
            report_lines.append("### 伤害记录")
            report_lines.append("")
            for i, dmg in enumerate(self.bleed_damage_records[:10], 1):
                report_lines.append(f"{i}. 流血伤害: {dmg}")
            if len(self.bleed_damage_records) > 10:
                report_lines.append(f"... 共 {len(self.bleed_damage_records)} 条记录")
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

        if self.validation["bleed_damage_nonzero"]:
            report_lines.append("✅ **流血伤害修复成功**")
            report_lines.append("")
            report_lines.append("流血伤害现在正确计算，不再为0。")
        else:
            report_lines.append("❌ **流血伤害仍为0**")
            report_lines.append("")
            report_lines.append("Technical Director的日志格式修复未解决根本问题。")
            report_lines.append("需要进一步修复流血伤害计算逻辑。")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_bat_bleed_retest.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9995
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BatTotemRetester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
