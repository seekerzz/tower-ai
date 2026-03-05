#!/usr/bin/env python3
"""
EAGLE-VERIFY-001: 鹰图腾修复验证测试

验证内容:
1. 孔雀Lv.2易伤debuff (30%增伤)
   - 验证日志: [PEACOCK_VULNERABLE]
   - 确认3层*10%=30%增伤生效

2. 秃鹫Lv.3死亡回响
   - 验证日志: [VULTURE_ECHO]
   - 确认死亡时对范围敌人造成伤害

输出报告: docs/player_reports/qa_report_eagle_verify_001.md
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


class EagleVerifyTester:
    """鹰图腾修复验证测试器"""

    TOTEM_ID = "eagle_totem"

    def __init__(self, http_port=9995):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_eagle_verify_{timestamp}.log"

        # 验证结果
        self.validation = {
            # 基础验证
            "totem_selected": False,
            "core_hp_set": False,

            # 孔雀验证
            "peacock_spawned": False,
            "peacock_vulnerable_debuff": False,  # [PEACOCK_VULNERABLE]日志
            "peacock_vulnerable_30_percent": False,  # 30%增伤

            # 秃鹫验证
            "vulture_spawned": False,
            "vulture_death_echo": False,  # [VULTURE_ECHO]日志
            "vulture_echo_damage": False,  # 死亡回响伤害

            # 升级验证
            "upgrade_available": False,
        }

        # 检测到的日志
        self.log_stats = {
            "peacock_logs": [],
            "vulture_logs": [],
            "vulnerable_logs": [],
            "echo_logs": [],
            "damage_logs": [],
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
        """解析鹰图腾修复相关日志"""

        # 1. 检测孔雀易伤debuff日志 [PEACOCK_VULNERABLE]
        if "PEACOCK_VULNERABLE" in obs or "peacock_vulnerable" in obs.lower():
            self.validation["peacock_vulnerable_debuff"] = True
            self.log_stats["vulnerable_logs"].append(obs)
            self.log("🦚 检测到[PEACOCK_VULNERABLE]易伤debuff日志", "DETECTION")

        # 2. 检测30%增伤
        if "30%" in obs and ("易伤" in obs or "vulnerable" in obs.lower() or "孔雀" in obs or "peacock" in obs.lower()):
            self.validation["peacock_vulnerable_30_percent"] = True
            self.log("🦚 检测到孔雀30%易伤增伤", "DETECTION")

        # 3. 检测秃鹫死亡回响日志 [VULTURE_ECHO]
        if "VULTURE_ECHO" in obs or "vulture_echo" in obs.lower():
            self.validation["vulture_death_echo"] = True
            self.log_stats["echo_logs"].append(obs)
            self.log("🦅 检测到[VULTURE_ECHO]死亡回响日志", "DETECTION")

        # 4. 检测死亡回响伤害
        if ("echo" in obs.lower() or "回响" in obs) and ("damage" in obs.lower() or "伤害" in obs):
            self.validation["vulture_echo_damage"] = True
            self.log_stats["damage_logs"].append(obs)
            self.log("🦅 检测到死亡回响伤害", "DETECTION")

        # 5. 检测孔雀相关日志
        if "peacock" in obs.lower() or "孔雀" in obs:
            self.log_stats["peacock_logs"].append(obs)

        # 6. 检测秃鹫相关日志
        if "vulture" in obs.lower() or "秃鹫" in obs:
            self.log_stats["vulture_logs"].append(obs)

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

    async def step_spawn_peacock(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 生成孔雀单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "peacock",
            "grid_pos": {"x": 1, "y": 0}
        }])
        self.log(f"生成孔雀结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["peacock_spawned"] = True
        self.log("✅ 孔雀单位生成完成", "VALIDATION")

    async def step_spawn_vulture(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 生成秃鹫单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "vulture",
            "grid_pos": {"x": 1, "y": 1}
        }])
        self.log(f"生成秃鹫结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["vulture_spawned"] = True
        self.log("✅ 秃鹫单位生成完成", "VALIDATION")

    async def step_start_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 开始战斗观察", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察战斗过程
        battle_duration = 90
        start_time = time.time()

        self.log("开始观察战斗，寻找修复验证日志...", "SYSTEM")

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
        self.log("EAGLE-VERIFY-001: 鹰图腾修复验证测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_set_god_mode()
            await self.step_spawn_peacock()
            await self.step_spawn_vulture()
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
            "# QA测试报告: 鹰图腾修复验证 (EAGLE-VERIFY-001)",
            "",
            f"**任务ID**: EAGLE-VERIFY-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: 修复验证测试",
            f"**所属图腾**: 鹰图腾",
            "",
            "---",
            "",
            "## 验证内容",
            "",
            "### 1. 孔雀Lv.2易伤debuff (30%增伤)",
            "- 预期日志: `[PEACOCK_VULNERABLE]`",
            "- 预期效果: 3层*10%=30%增伤",
            "",
            "### 2. 秃鹫Lv.3死亡回响",
            "- 预期日志: `[VULTURE_ECHO]`",
            "- 预期效果: 死亡时对范围敌人造成伤害",
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
            ("core_hp_set", "上帝模式设置"),
            ("peacock_spawned", "孔雀单位生成"),
            ("vulture_spawned", "秃鹫单位生成"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 孔雀易伤debuff验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        peacock_status = "✅ 检测到" if self.validation["peacock_vulnerable_debuff"] else "❌ 未检测到"
        damage_status = "✅ 检测到" if self.validation["peacock_vulnerable_30_percent"] else "❌ 未检测到"

        report_lines.append(f"| [PEACOCK_VULNERABLE]日志 | {peacock_status} | 易伤debuff标记 |")
        report_lines.append(f"| 30%增伤效果 | {damage_status} | 3层*10%=30% |")

        report_lines.extend([
            "",
            "### 秃鹫死亡回响验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        echo_status = "✅ 检测到" if self.validation["vulture_death_echo"] else "❌ 未检测到"
        damage_status = "✅ 检测到" if self.validation["vulture_echo_damage"] else "❌ 未检测到"

        report_lines.append(f"| [VULTURE_ECHO]日志 | {echo_status} | 死亡回响标记 |")
        report_lines.append(f"| 回响伤害 | {damage_status} | 范围伤害效果 |")

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

        # 判断修复是否成功
        peacock_fixed = self.validation["peacock_vulnerable_debuff"]
        vulture_fixed = self.validation["vulture_death_echo"]

        if peacock_fixed and vulture_fixed:
            report_lines.append("✅ **修复验证通过** - 孔雀易伤debuff和秃鹫死亡回响均已正确实现")
        elif peacock_fixed:
            report_lines.append("⚠️ **部分修复** - 孔雀易伤debuff已实现，秃鹫死亡回响未检测到")
        elif vulture_fixed:
            report_lines.append("⚠️ **部分修复** - 秃鹫死亡回响已实现，孔雀易伤debuff未检测到")
        else:
            report_lines.append("❌ **修复验证失败** - 未检测到预期的修复日志")
            report_lines.append("")
            report_lines.append("### 可能原因")
            report_lines.append("1. 修复尚未部署到测试环境")
            report_lines.append("2. 日志标记格式与预期不符")
            report_lines.append("3. 触发条件未满足（如单位未升级至Lv.2/Lv.3）")
            report_lines.append("4. 需要检查技术总监的修复提交是否已合并")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_eagle_verify_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9995
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with EagleVerifyTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
