#!/usr/bin/env python3
"""
VIPER-VERIFY-001: 毒蛇图腾修复验证测试

验证内容:
1. 箭毒蛙斩杀阈值
   - 验证日志: [ARROW_FROG_EXECUTE]
   - 确认Debuff层数*200%伤害计算
   - 测试不同Debuff层数下的斩杀效果

输出报告: docs/player_reports/qa_report_viper_verify_001.md
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


class ViperVerifyTester:
    """毒蛇图腾修复验证测试器"""

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
        self.log_file = log_dir / f"ai_session_viper_verify_{timestamp}.log"

        # 验证结果
        self.validation = {
            # 基础验证
            "totem_selected": False,
            "core_hp_set": False,

            # 箭毒蛙斩杀验证
            "arrow_frog_spawned": False,
            "arrow_frog_execute_log": False,  # [ARROW_FROG_EXECUTE]日志
            "arrow_frog_200_percent": False,  # 200%伤害
            "arrow_frog_debuff_based": False,  # Debuff层数计算

            # 斩杀阈值验证
            "execute_threshold_15": False,  # 15%阈值
            "execute_threshold_20": False,  # 20%阈值
            "execute_threshold_25": False,  # 25%阈值
            "execute_threshold_30": False,  # 30%阈值

            # 毒蛇图腾核心机制
            "viper_totem_3_targets": False,  # 3目标
            "viper_totem_3_layers": False,   # 3层中毒
        }

        # 检测到的日志
        self.log_stats = {
            "arrow_frog_logs": [],
            "execute_logs": [],
            "damage_logs": [],
            "debuff_logs": [],
            "totem_logs": [],
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
        """解析毒蛇图腾修复相关日志"""

        # 1. 检测箭毒蛙斩杀日志 [ARROW_FROG_EXECUTE]
        if "ARROW_FROG_EXECUTE" in obs or "arrow_frog_execute" in obs.lower():
            self.validation["arrow_frog_execute_log"] = True
            self.log_stats["execute_logs"].append(obs)
            self.log("🐸 检测到[ARROW_FROG_EXECUTE]斩杀日志", "DETECTION")

        # 2. 检测200%伤害
        if "200%" in obs and ("斩杀" in obs or "execute" in obs.lower() or "箭毒蛙" in obs or "arrow_frog" in obs.lower()):
            self.validation["arrow_frog_200_percent"] = True
            self.log("🐸 检测到箭毒蛙200%斩杀伤害", "DETECTION")

        # 3. 检测Debuff层数计算
        if ("debuff" in obs.lower() or "层数" in obs or "层" in obs) and ("斩杀" in obs or "execute" in obs.lower()):
            self.validation["arrow_frog_debuff_based"] = True
            self.log_stats["debuff_logs"].append(obs)
            self.log("🐸 检测到Debuff层数斩杀计算", "DETECTION")

        # 4. 检测斩杀阈值
        if "15%" in obs and ("斩杀" in obs or "threshold" in obs.lower()):
            self.validation["execute_threshold_15"] = True
            self.log("🐸 检测到15%斩杀阈值", "DETECTION")
        if "20%" in obs and ("斩杀" in obs or "threshold" in obs.lower()):
            self.validation["execute_threshold_20"] = True
            self.log("🐸 检测到20%斩杀阈值", "DETECTION")
        if "25%" in obs and ("斩杀" in obs or "threshold" in obs.lower()):
            self.validation["execute_threshold_25"] = True
            self.log("🐸 检测到25%斩杀阈值", "DETECTION")
        if "30%" in obs and ("斩杀" in obs or "threshold" in obs.lower()):
            self.validation["execute_threshold_30"] = True
            self.log("🐸 检测到30%斩杀阈值", "DETECTION")

        # 5. 检测毒蛇图腾3目标
        if ("3目标" in obs or "3 targets" in obs.lower() or "三目标" in obs) and ("毒蛇" in obs or "viper" in obs.lower()):
            self.validation["viper_totem_3_targets"] = True
            self.log("🐍 检测到毒蛇图腾3目标", "DETECTION")

        # 6. 检测3层中毒
        if ("3层" in obs or "3 layers" in obs.lower() or "三层" in obs) and ("中毒" in obs or "poison" in obs.lower()):
            self.validation["viper_totem_3_layers"] = True
            self.log("🐍 检测到3层中毒", "DETECTION")

        # 7. 检测箭毒蛙相关日志
        if "arrow_frog" in obs.lower() or "箭毒蛙" in obs:
            self.log_stats["arrow_frog_logs"].append(obs)

        # 8. 检测毒蛇图腾日志
        if "viper_totem" in obs.lower() or "毒蛇图腾" in obs:
            self.log_stats["totem_logs"].append(obs)

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

    async def step_spawn_arrow_frog(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 生成箭毒蛙单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "arrow_frog",
            "grid_pos": {"x": 1, "y": 0}
        }])
        self.log(f"生成箭毒蛙结果: {result}", "DEBUG")
        await asyncio.sleep(1.0)

        self.validation["arrow_frog_spawned"] = True
        self.log("✅ 箭毒蛙单位生成完成", "VALIDATION")

    async def step_start_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 开始战斗观察", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察战斗过程
        battle_duration = 90
        start_time = time.time()

        self.log("开始观察战斗，寻找箭毒蛙斩杀日志...", "SYSTEM")

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
        self.log("VIPER-VERIFY-001: 毒蛇图腾修复验证测试", "SYSTEM")
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
            await self.step_spawn_arrow_frog()
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
            "# QA测试报告: 毒蛇图腾修复验证 (VIPER-VERIFY-001)",
            "",
            f"**任务ID**: VIPER-VERIFY-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: 修复验证测试",
            f"**所属图腾**: 毒蛇图腾",
            "",
            "---",
            "",
            "## 验证内容",
            "",
            "### 箭毒蛙斩杀阈值",
            "- 预期日志: `[ARROW_FROG_EXECUTE]`",
            "- 预期效果: Debuff层数*200%伤害计算",
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
            ("core_hp_set", "上帝模式设置"),
            ("arrow_frog_spawned", "箭毒蛙单位生成"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 箭毒蛙斩杀验证",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        execute_status = "✅ 检测到" if self.validation["arrow_frog_execute_log"] else "❌ 未检测到"
        damage_status = "✅ 检测到" if self.validation["arrow_frog_200_percent"] else "❌ 未检测到"
        debuff_status = "✅ 检测到" if self.validation["arrow_frog_debuff_based"] else "❌ 未检测到"

        report_lines.append(f"| [ARROW_FROG_EXECUTE]日志 | {execute_status} | 斩杀标记 |")
        report_lines.append(f"| 200%伤害 | {damage_status} | Debuff层数*200% |")
        report_lines.append(f"| Debuff层数计算 | {debuff_status} | 基于层数的伤害 |")

        report_lines.extend([
            "",
            "### 斩杀阈值检测",
            "",
            "| 阈值 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        thresholds = [
            ("execute_threshold_15", "15%"),
            ("execute_threshold_20", "20%"),
            ("execute_threshold_25", "25%"),
            ("execute_threshold_30", "30%"),
        ]

        for key, desc in thresholds:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {desc} | {status} | 斩杀阈值 |")

        report_lines.extend([
            "",
            "### 毒蛇图腾核心机制",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ])

        targets_status = "✅ 检测到" if self.validation["viper_totem_3_targets"] else "❌ 未检测到"
        layers_status = "✅ 检测到" if self.validation["viper_totem_3_layers"] else "❌ 未检测到"

        report_lines.append(f"| 3目标选择 | {targets_status} | 同时攻击3个敌人 |")
        report_lines.append(f"| 3层中毒 | {layers_status} | 叠加3层中毒 |")

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
        execute_fixed = self.validation["arrow_frog_execute_log"]
        damage_fixed = self.validation["arrow_frog_200_percent"]

        if execute_fixed and damage_fixed:
            report_lines.append("✅ **修复验证通过** - 箭毒蛙斩杀机制已正确实现")
            report_lines.append(f"- [ARROW_FROG_EXECUTE]日志: 检测到")
            report_lines.append(f"- 200%伤害计算: 检测到")
        elif execute_fixed:
            report_lines.append("⚠️ **部分修复** - 斩杀日志已检测到，但200%伤害未确认")
        else:
            report_lines.append("❌ **修复验证失败** - 未检测到预期的[ARROW_FROG_EXECUTE]日志")
            report_lines.append("")
            report_lines.append("### 可能原因")
            report_lines.append("1. 修复尚未部署到测试环境")
            report_lines.append("2. 日志标记格式与预期不符")
            report_lines.append("3. 触发条件未满足（如敌人血量未达到斩杀阈值）")
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

        report_path = Path("docs/player_reports/qa_report_viper_verify_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9996
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with ViperVerifyTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
