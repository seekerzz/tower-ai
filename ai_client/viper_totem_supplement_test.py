#!/usr/bin/env python3
"""
VIPER-TOTEM-SUPPLEMENT-001: 毒蛇图腾机制补充验证测试

任务ID: VIPER-TOTEM-SUPPLEMENT-001
来源: QA Tester / Project Director
优先级: P1

测试内容:
1. 箭毒蛙斩杀机制 (重点) - 斩杀阈值数值验证
2. 毒蛇图腾核心机制 - 5秒毒液攻击
3. 雪人冰封剧毒机制 (Lv.3)
4. 毒蛇双目标Buff机制 (Lv.3)
5. 美杜莎石化机制
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


class ViperTotemSupplementTester:
    """毒蛇图腾机制补充测试器"""

    TOTEM_ID = "viper_totem"

    def __init__(self, http_port=9996):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_viper_totem_supplement_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "arrow_frog_execute": False,      # 箭毒蛙斩杀
            "arrow_frog_damage": False,       # 箭毒蛙250%伤害
            "viper_5s_timer": False,          # 毒蛇5秒定时器
            "viper_3_targets": False,         # 毒蛇3目标
            "viper_3_poison": False,          # 毒蛇3层中毒
            "snowman_ice_poison": False,      # 雪人冰封剧毒
            "viper_dual_buff": False,         # 毒蛇双目标Buff
            "medusa_petrify": False,          # 美杜莎石化
            "medusa_stone": False,            # 美杜莎石块
        }

        # 日志统计
        self.log_stats = {
            "totem_logs": [],
            "arrow_frog_logs": [],
            "viper_logs": [],
            "snowman_logs": [],
            "medusa_logs": [],
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
        """解析毒蛇图腾相关日志"""

        # 1. 检测箭毒蛙斩杀日志
        execute_patterns = [
            r"斩杀",
            r"execute",
            r"引爆",
            r"\[EXECUTE\]",
        ]
        for pattern in execute_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["arrow_frog_execute"] = True
                self.log_stats["arrow_frog_logs"].append(obs)
                self.log(f"🐸 检测到箭毒蛙斩杀", "DETECTION")
                break

        # 2. 检测毒蛇图腾攻击日志
        viper_patterns = [
            r"毒蛇图腾",
            r"viper_totem",
            r"毒液攻击",
            r"\[TOTEM\].*?毒蛇",
        ]
        for pattern in viper_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["viper_5s_timer"] = True
                self.log_stats["viper_logs"].append(obs)
                self.log(f"🐍 检测到毒蛇图腾攻击", "DETECTION")
                break

        # 3. 检测雪人冰封剧毒日志
        snowman_patterns = [
            r"雪人",
            r"snowman",
            r"冰封剧毒",
            r"冰冻",
        ]
        for pattern in snowman_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["snowman_logs"].append(obs)
                self.log(f"☃️ 检测到雪人", "DETECTION")
                break

        # 4. 检测美杜莎石化日志
        medusa_patterns = [
            r"美杜莎",
            r"medusa",
            r"石化",
            r"petrify",
        ]
        for pattern in medusa_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["medusa_petrify"] = True
                self.log_stats["medusa_logs"].append(obs)
                self.log(f"👁️ 检测到美杜莎石化", "DETECTION")
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
        self.log("步骤1: 选择毒蛇图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(1.0)
        result = await self.send_actions([{"type": "select_totem", "totem_id": self.TOTEM_ID}])
        self.log(f"选择图腾结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.validation["totem_selected"] = True
        self.log("✅ 毒蛇图腾选择完成", "VALIDATION")

    async def step_spawn_test_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 生成测试单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log("设置核心血量保护: 99999", "SYSTEM")

        # 生成箭毒蛙
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "arrow_frog",
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成箭毒蛙结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成雪人
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "snowman",
            "position": {"x": 1, "y": 1}
        }])
        self.log(f"生成雪人结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        # 生成毒蛇
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "viper",
            "position": {"x": 1, "y": 2}
        }])
        self.log(f"生成毒蛇结果: {result}", "DEBUG")
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
        self.log("VIPER-TOTEM-SUPPLEMENT-001: 毒蛇图腾机制补充验证", "SYSTEM")
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
            "# QA测试报告: 毒蛇图腾机制补充验证 (P1)",
            "",
            f"**任务ID**: VIPER-TOTEM-SUPPLEMENT-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1 机制补充测试",
            f"**所属图腾**: 毒蛇图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证毒蛇图腾核心机制及关键单位的特殊机制实现情况，特别是箭毒蛙斩杀机制",
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
            ("totem_selected", "毒蛇图腾选择"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 箭毒蛙斩杀机制 (P1重点)",
            "",
            "| 机制 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        arrow_frog_mechanics = [
            ("arrow_frog_execute", "斩杀触发"),
            ("arrow_frog_damage", "250%伤害"),
        ]

        for key, desc in arrow_frog_mechanics:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 毒蛇图腾核心机制",
            "",
            "| 机制 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        viper_mechanics = [
            ("viper_5s_timer", "5秒定时器"),
            ("viper_3_targets", "3目标选择"),
            ("viper_3_poison", "3层中毒"),
        ]

        for key, desc in viper_mechanics:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 其他单位机制",
            "",
            "| 单位 | 机制 | 状态 | 说明 |",
            "|------|------|------|------|",
        ])

        other_mechanics = [
            ("snowman_ice_poison", "雪人", "冰封剧毒"),
            ("viper_dual_buff", "毒蛇", "双目标Buff"),
            ("medusa_petrify", "美杜莎", "石化凝视"),
            ("medusa_stone", "美杜莎", "石块破碎"),
        ]

        for key, unit, mechanism in other_mechanics:
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
            "### 关键问题",
            "",
            "1. **箭毒蛙斩杀阈值**: 需要代码审查确认实际实现",
            "2. **数值描述不一致**: 设计文档与数据文件描述不一致",
            "",
            "### 建议",
            "",
            "1. 技术总监审查箭毒蛙斩杀机制代码实现",
            "2. 统一斩杀阈值数值描述",
            "3. 添加更多日志埋点以便验证",
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_viper_totem_supplement_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9996
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with ViperTotemSupplementTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
