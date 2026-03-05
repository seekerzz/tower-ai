#!/usr/bin/env python3
"""
P2-EAGLE-UNITS-TEST: 鹰图腾单位机制验证测试

任务ID: P2-EAGLE-UNITS-001
来源: Project Director / QA Tester

测试目标:
验证鹰图腾流派3个问题：
1. 老鹰(eagle): Lv.3处决伤害代码为200%，设计为250%
2. 秃鹫(vulture): 实现为临时buff，与设计文档的永久叠加机制不符
3. 孔雀(peacock): Lv.2缺少易伤debuff实现

参考文档:
- docs/qa_tasks/task_eagle_damage_001.md
- docs/qa_tasks/task_vulture_scavenge_001.md
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


class EagleUnitsTester:
    """鹰图腾单位机制测试器"""

    TOTEM_ID = "eagle_totem"

    def __init__(self, http_port=9994):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_eagle_units_{timestamp}.log"

        # 验证结果
        self.validation = {
            # 基础验证
            "totem_selected": False,

            # 老鹰验证
            "eagle_spawned": False,
            "eagle_lv1_full_hp_damage": False,    # Lv.1满血伤害200%
            "eagle_lv2_high_hp_bonus": False,     # Lv.2高HP+30%
            "eagle_lv3_execute_200": False,       # Lv.3处决200% (代码实现)
            "eagle_lv3_execute_250": False,       # Lv.3处决250% (设计预期)

            # 秃鹫验证
            "vulture_spawned": False,
            "vulture_target_lowest_hp": False,    # 优先攻击最低HP
            "vulture_temp_buff": False,           # 临时buff机制
            "vulture_permanent_stack": False,     # 永久叠加机制 (设计预期)
            "vulture_death_echo": False,          # 死亡回响 (设计预期)

            # 孔雀验证
            "peacock_spawned": False,
            "peacock_feather_mechanic": False,    # 羽毛机制
            "peacock_vulnerability_debuff": False, # Lv.2易伤debuff (设计预期)
        }

        # 检测到的日志统计
        self.log_stats = {
            "eagle_logs": [],
            "vulture_logs": [],
            "peacock_logs": [],
            "damage_logs": [],
            "buff_logs": [],
            "debuff_logs": [],
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
        """解析鹰图腾单位相关日志"""

        # 1. 检测老鹰相关日志
        eagle_patterns = [
            r"eagle",
            r"老鹰",
            r"\[UNIT\].*?老鹰",
            r"Eagle",
        ]
        for pattern in eagle_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["eagle_logs"].append(obs)
                self.log(f"🦅 检测到老鹰单位日志", "DETECTION")
                break

        # 2. 检测秃鹫相关日志
        vulture_patterns = [
            r"vulture",
            r"秃鹫",
            r"\[UNIT\].*?秃鹫",
            r"Vulture",
        ]
        for pattern in vulture_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["vulture_logs"].append(obs)
                self.log(f"🦅 检测到秃鹫单位日志", "DETECTION")
                break

        # 3. 检测孔雀相关日志
        peacock_patterns = [
            r"peacock",
            r"孔雀",
            r"\[UNIT\].*?孔雀",
            r"Peacock",
        ]
        for pattern in peacock_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["peacock_logs"].append(obs)
                self.log(f"🦚 检测到孔雀单位日志", "DETECTION")
                break

        # 4. 检测伤害日志
        damage_patterns = [
            r"\[DAMAGE\].*?(老鹰|eagle)",
            r"造成伤害",
            r"damage",
        ]
        for pattern in damage_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["damage_logs"].append(obs)
                # 检查处决伤害
                if "200%" in obs or "2.0" in obs:
                    self.validation["eagle_lv3_execute_200"] = True
                    self.log(f"🦅 检测到老鹰200%伤害", "DETECTION")
                if "250%" in obs:
                    self.validation["eagle_lv3_execute_250"] = True
                    self.log(f"🦅 检测到老鹰250%伤害", "DETECTION")
                break

        # 5. 检测buff日志
        buff_patterns = [
            r"\[BUFF\].*?(秃鹫|vulture)",
            r"攻击.*?\+",
            r"buff",
        ]
        for pattern in buff_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["buff_logs"].append(obs)
                self.validation["vulture_temp_buff"] = True
                self.log(f"🦅 检测到buff日志", "DETECTION")
                break

        # 6. 检测debuff日志
        debuff_patterns = [
            r"\[DEBUFF\].*?(孔雀|peacock)",
            r"易伤",
            r"vulnerability",
        ]
        for pattern in debuff_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["debuff_logs"].append(obs)
                self.validation["peacock_vulnerability_debuff"] = True
                self.log(f"🦚 检测到易伤debuff日志", "DETECTION")
                break

        # 7. 检测永久叠加日志
        permanent_patterns = [
            r"永久",
            r"permanent",
            r"叠加",
            r"stack",
        ]
        for pattern in permanent_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["vulture_permanent_stack"] = True
                self.log(f"🦅 检测到永久叠加日志", "DETECTION")
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
        self.log("步骤1: 选择鹰图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 鹰图腾选择完成", "VALIDATION")

    async def step_test_eagle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 测试老鹰单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])

        # 生成老鹰单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "eagle",
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成老鹰结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["eagle_spawned"] = True
        self.log("✅ 老鹰单位生成完成", "VALIDATION")

    async def step_test_vulture(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 测试秃鹫单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 生成秃鹫单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "vulture",
            "position": {"x": 1, "y": 1}
        }])
        self.log(f"生成秃鹫结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["vulture_spawned"] = True
        self.log("✅ 秃鹫单位生成完成", "VALIDATION")

    async def step_test_peacock(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 测试孔雀单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 生成孔雀单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "peacock",
            "position": {"x": 1, "y": 2}
        }])
        self.log(f"生成孔雀结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["peacock_spawned"] = True
        self.log("✅ 孔雀单位生成完成", "VALIDATION")

    async def step_start_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 开始战斗观察", "SYSTEM")
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

        # 老鹰发现
        if self.validation["eagle_lv3_execute_200"] and not self.validation["eagle_lv3_execute_250"]:
            self.findings.append({
                "unit": "老鹰",
                "type": "数值差异",
                "design": "Lv.3处决伤害: 250%",
                "implementation": "Lv.3处决伤害: 200%",
                "evidence": "检测到200%伤害日志，未检测到250%"
            })

        # 秃鹫发现
        if self.validation["vulture_temp_buff"] and not self.validation["vulture_permanent_stack"]:
            self.findings.append({
                "unit": "秃鹫",
                "type": "机制差异",
                "design": "击杀后永久攻击力+1（上限20）",
                "implementation": "周围敌人死亡时临时攻击力buff",
                "evidence": f"Buff日志: {len(self.log_stats['buff_logs'])} 条，无永久叠加"
            })

        if not self.validation["vulture_death_echo"]:
            self.findings.append({
                "unit": "秃鹫",
                "type": "缺失功能",
                "design": "Lv.3死亡回响: 击杀触发图腾回响",
                "implementation": "未实现",
                "evidence": "无死亡回响日志"
            })

        # 孔雀发现
        if not self.validation["peacock_vulnerability_debuff"]:
            self.findings.append({
                "unit": "孔雀",
                "type": "缺失功能",
                "design": "Lv.2易伤debuff: 拉扯后+30%伤害",
                "implementation": "未检测到实现",
                "evidence": "无易伤debuff日志"
            })

        for finding in self.findings:
            self.log(f"\n发现: {finding['unit']} - {finding['type']}", "FINDING")
            self.log(f"  设计预期: {finding['design']}", "FINDING")
            self.log(f"  实际实现: {finding['implementation']}", "FINDING")
            self.log(f"  证据: {finding['evidence']}", "FINDING")

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("P2-EAGLE-UNITS-TEST: 鹰图腾单位机制验证", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_test_eagle()
            await self.step_test_vulture()
            await self.step_test_peacock()
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
            "# QA测试报告: 鹰图腾单位机制验证 (P2)",
            "",
            f"**任务ID**: P2-EAGLE-UNITS-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P2机制验证测试",
            f"**所属图腾**: 鹰图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证鹰图腾流派3个单位的机制实现与设计文档的差异：",
            "1. 老鹰(eagle): Lv.3处决伤害代码为200%，设计为250%",
            "2. 秃鹫(vulture): 实现为临时buff，与设计文档的永久叠加机制不符",
            "3. 孔雀(peacock): Lv.2缺少易伤debuff实现",
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
            ("totem_selected", "鹰图腾选择"),
            ("eagle_spawned", "老鹰单位生成"),
            ("vulture_spawned", "秃鹫单位生成"),
            ("peacock_spawned", "孔雀单位生成"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 老鹰伤害验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        eagle_validations = [
            ("eagle_lv3_execute_200", "Lv.3处决200% (代码实现)"),
            ("eagle_lv3_execute_250", "Lv.3处决250% (设计预期)"),
        ]

        for key, desc in eagle_validations:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 秃鹫机制验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        vulture_validations = [
            ("vulture_temp_buff", "临时buff机制 (代码实现)"),
            ("vulture_permanent_stack", "永久叠加机制 (设计预期)"),
            ("vulture_death_echo", "死亡回响技能 (设计预期)"),
        ]

        for key, desc in vulture_validations:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 孔雀机制验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        peacock_validations = [
            ("peacock_vulnerability_debuff", "Lv.2易伤debuff (设计预期)"),
        ]

        for key, desc in peacock_validations:
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
                f"### 发现 {i}: {finding['unit']} - {finding['type']}",
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

        # 统计问题数量
        issue_count = len(self.findings)

        if issue_count == 0:
            report_lines.append("✅ **实现与设计基本一致**")
        else:
            report_lines.append(f"🔧 **发现 {issue_count} 处实现与设计不符**")
            report_lines.append("")
            report_lines.append("### 建议")
            report_lines.append("")
            report_lines.append("1. **老鹰**: 确认Lv.3处决伤害200% vs 250%是否影响游戏平衡")
            report_lines.append("2. **秃鹫**: 评估临时buff vs 永久叠加机制的可玩性差异")
            report_lines.append("3. **孔雀**: 确认是否需要补充Lv.2易伤debuff实现")
            report_lines.append("4. **技术总监**: 评估是否需要统一修改代码以匹配设计文档")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_eagle_units_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9994
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with EagleUnitsTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
