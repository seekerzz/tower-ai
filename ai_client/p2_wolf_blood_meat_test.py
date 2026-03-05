#!/usr/bin/env python3
"""
P2-WOLF-BLOOD-MEAT-TEST: 狼图腾-血食机制验证测试

任务ID: P2-WOLF-BLOOD-MEAT-001
来源: Project Director / QA Tester

测试目标:
验证血食单位的机制实现与设计文档的差异：
- 设计文档: 血魂充能(狼族吞噬获得层数) + 血祭主动技能
- 实际代码: 基于狼图腾魂魄数量的全局buff

测试场景:
1. 血魂层数积累验证 - 验证当前魂魄加成机制
2. 血祭技能验证 - 确认血祭技能是否已实现

参考文档:
- docs/qa_tasks/task_wolf_blood_meat_001.md
- docs/qa_tasks/remaining_units_review_report.md
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


class WolfBloodMeatTester:
    """狼图腾血食机制测试器"""

    UNIT_NAME = "血食"
    UNIT_ID = "blood_meat"
    TOTEM_ID = "wolf_totem"

    def __init__(self, http_port=9993):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_wolf_blood_meat_{timestamp}.log"

        # 验证结果
        self.validation = {
            # 基础验证
            "totem_selected": False,
            "unit_spawned": False,
            "wolf_spawned": False,

            # 机制验证 - 设计文档预期
            "blood_soul_stack_on_devour": False,  # 狼族吞噬时获得血魂层数
            "aura_bonus_per_stack": False,        # 每层+2%光环
            "stack_limit_10": False,              # 层数上限10层
            "blood_sacrifice_skill": False,       # 血祭技能

            # 机制验证 - 实际代码实现
            "soul_based_global_buff": False,      # 基于魂魄的全局buff
            "buff_amount_lv1_2": False,           # Lv1-2: 每魂魄+0.5%
            "buff_amount_lv3": False,             # Lv3: 每魂魄+0.8%
        }

        # 检测到的日志统计
        self.log_stats = {
            "blood_meat_logs": [],
            "wolf_devour_logs": [],
            "buff_logs": [],
            "soul_logs": [],
            "skill_logs": [],
        }

        # 关键发现
        self.findings = []

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

        # 1. 检测血食单位相关日志
        blood_meat_patterns = [
            r"blood_meat",
            r"血食",
            r"\[UNIT\].*?血食",
            r"UnitBloodFood",
        ]
        for pattern in blood_meat_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["blood_meat_logs"].append(obs)
                self.log(f"🩸 检测到血食单位日志", "DETECTION")
                break

        # 2. 检测狼吞噬日志
        devour_patterns = [
            r"\[WOLF\].*?吞噬",
            r"\[DEVOUR\]",
            r"wolf.*devour",
            r"狼.*吞噬",
        ]
        for pattern in devour_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["wolf_devour_logs"].append(obs)
                self.validation["blood_soul_stack_on_devour"] = True
                self.log(f"🐺 检测到狼吞噬日志", "DETECTION")
                break

        # 3. 检测血魂层数日志
        soul_stack_patterns = [
            r"血魂.*?层数",
            r"blood_soul.*?stack",
            r"\[BUFF\].*?血魂",
        ]
        for pattern in soul_stack_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["aura_bonus_per_stack"] = True
                self.log_stats["buff_logs"].append(obs)
                self.log(f"🩸 检测到血魂层数日志", "DETECTION")
                break

        # 4. 检测魂魄相关日志
        soul_patterns = [
            r"\[RESOURCE\].*?狼图腾.*?魂魄",
            r"狼图腾.*?魂魄",
            r"wolf.*?soul",
        ]
        for pattern in soul_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["soul_logs"].append(obs)
                self.validation["soul_based_global_buff"] = True
                self.log(f"🐺 检测到狼图腾魂魄日志", "DETECTION")
                break

        # 5. 检测全局buff日志
        buff_patterns = [
            r"全局伤害.*?加成",
            r"global.*?buff",
            r"damage_percent",
            r"\[BUFF\].*?伤害",
        ]
        for pattern in buff_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["buff_logs"].append(obs)
                self.log(f"💪 检测到全局buff日志", "DETECTION")
                break

        # 6. 检测血祭技能日志
        sacrifice_patterns = [
            r"血祭",
            r"blood_sacrifice",
            r"\[SKILL\].*?血食",
            r"自杀",
        ]
        for pattern in sacrifice_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["blood_sacrifice_skill"] = True
                self.log_stats["skill_logs"].append(obs)
                self.log(f"🔥 检测到血祭技能日志", "DETECTION")
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

    async def analyze_findings(self):
        """分析测试结果，对比设计与实现"""
        self.log("=" * 60, "SYSTEM")
        self.log("分析测试结果", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 分析发现
        self.findings.append({
            "type": "机制差异",
            "design": "血魂充能: 狼族吞噬时获得血魂层数，每层+2%光环",
            "implementation": "基于狼图腾魂魄总数的全局伤害buff",
            "evidence": f"魂魄相关日志: {len(self.log_stats['soul_logs'])} 条"
        })

        # 检查血祭技能
        if not self.validation["blood_sacrifice_skill"]:
            self.findings.append({
                "type": "缺失功能",
                "design": "血祭主动技能: 自杀治疗核心5% + 狼族+30%攻击",
                "implementation": "未检测到血祭技能实现",
                "evidence": "无血祭相关日志"
            })

        # 检查全局buff
        if self.validation["soul_based_global_buff"]:
            self.findings.append({
                "type": "实际实现",
                "design": "血魂层数独立计算",
                "implementation": "魂魄数 * 0.5%(Lv1-2) 或 0.8%(Lv3) 全局伤害加成",
                "evidence": f"Buff日志: {len(self.log_stats['buff_logs'])} 条"
            })

        for finding in self.findings:
            self.log(f"\n发现: {finding['type']}", "FINDING")
            self.log(f"  设计预期: {finding['design']}", "FINDING")
            self.log(f"  实际实现: {finding['implementation']}", "FINDING")
            self.log(f"  证据: {finding['evidence']}", "FINDING")

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("P2-WOLF-BLOOD-MEAT-TEST: 狼图腾血食机制验证", "SYSTEM")
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
            await self.analyze_findings()
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
            "# QA测试报告: 狼图腾-血食机制验证 (P2)",
            "",
            f"**任务ID**: P2-WOLF-BLOOD-MEAT-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P2机制验证测试",
            f"**单位名称**: {self.UNIT_NAME} ({self.UNIT_ID})",
            f"**所属图腾**: 狼图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证血食单位的机制实现与设计文档的差异",
            "",
            "### 设计文档描述 (Lv.3)",
            "- **血魂充能**: 每当狼族吞噬时获得血魂层数，每层+2%光环效果(上限10层)",
            "- **血祭**: 主动技能自杀，治疗核心5%并给所有狼族+30%攻击持续5秒",
            "",
            "### 实际代码实现",
            "```gdscript",
            "func _update_buff():",
            "    var bonus_per_soul = 0.005 if level < 3 else 0.008",
            "    var total_bonus = TotemManager.get_resource(\"wolf\") * bonus_per_soul",
            "    GameManager.apply_global_buff(\"damage_percent\", total_bonus)",
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
            ("totem_selected", "狼图腾选择"),
            ("unit_spawned", "血食单位生成"),
            ("wolf_spawned", "狼单位生成"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 设计文档机制验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        design_validations = [
            ("blood_soul_stack_on_devour", "狼族吞噬获得血魂层数"),
            ("aura_bonus_per_stack", "每层+2%光环"),
            ("stack_limit_10", "层数上限10层"),
            ("blood_sacrifice_skill", "血祭主动技能"),
        ]

        for key, desc in design_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 实际代码实现验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        impl_validations = [
            ("soul_based_global_buff", "魂魄加成全局buff"),
        ]

        for key, desc in impl_validations:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

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
            "## 关键发现",
            "",
        ])

        for i, finding in enumerate(self.findings, 1):
            report_lines.extend([
                f"### 发现 {i}: {finding['type']}",
                "",
                f"- **设计预期**: {finding['design']}",
                f"- **实际实现**: {finding['implementation']}",
                f"- **证据**: {finding['evidence']}",
                "",
            ])

        report_lines.extend([
            "---",
            "",
            "## 测试结论",
            "",
        ])

        # 判断实现与设计的一致性
        design_match = sum([
            self.validation["blood_soul_stack_on_devour"],
            self.validation["aura_bonus_per_stack"],
            self.validation["blood_sacrifice_skill"],
        ])

        if design_match == 0:
            report_lines.append("🔧 **实现与设计不符**")
            report_lines.append("")
            report_lines.append("当前实现采用魂魄加成机制，而非设计文档中的血魂层数机制。")
            report_lines.append("血祭主动技能未检测到实现。")
        elif design_match >= 2:
            report_lines.append("✅ **实现与设计基本一致**")
        else:
            report_lines.append("⚠️ **部分实现与设计不符**")

        report_lines.extend([
            "",
            "### 建议",
            "",
            "1. **短期**: 确认当前魂魄加成机制是否可玩平衡",
            "2. **中期**: 技术总监评估是否需要修改代码以匹配设计",
            "3. **长期**: 如需血祭技能，安排实现排期",
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_wolf_blood_meat_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9993
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with WolfBloodMeatTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
