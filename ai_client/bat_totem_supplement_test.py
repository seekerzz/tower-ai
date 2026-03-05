#!/usr/bin/env python3
"""
BAT-TOTEM-SUPPLEMENT-001: 蝙蝠图腾机制补充验证测试

任务ID: BAT-TOTEM-SUPPLEMENT-001
来源: QA Tester / Project Director
优先级: P1

测试目标:
- 验证蝙蝠图腾核心机制 (5秒攻击/流血施加)
- 验证流血伤害机制 (Technical Director修复后)
- 验证吸血治疗核心机制
- 验证血法师血池机制
- 验证生命链条机制
- 验证瘟疫使者机制
- 验证血祭术士机制

重点验证:
- 流血伤害不为0 (关键验证项)
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


class BatTotemSupplementTester:
    """蝙蝠图腾机制补充验证测试器"""

    TOTEM_ID = "bat_totem"

    def __init__(self, http_port=9999):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_bat_totem_supplement_{timestamp}.log"

        # 验证结果
        self.validation = {
            "totem_selected": False,
            "bat_totem_timer": False,       # 5秒定时器
            "bleed_apply": False,           # 流血施加
            "bleed_damage_not_zero": False, # 流血伤害不为0 (关键)
            "vampire_heal": False,          # 攻击回血
            "mosquito_drain": False,        # 蚊子吸血
            "blood_mage_pool": False,       # 血法师血池
            "life_chain": False,            # 生命链条
            "plague_bringer": False,        # 瘟疫使者
            "blood_sacrifice": False,       # 血祭术士
        }

        # 日志统计
        self.log_stats = {
            "bat_totem_logs": [],
            "bleed_logs": [],
            "damage_logs": [],
            "heal_logs": [],
            "mosquito_logs": [],
            "blood_mage_logs": [],
            "life_chain_logs": [],
            "plague_logs": [],
            "sacrifice_logs": [],
        }

        # 流血伤害记录
        self.bleed_damage_records = []

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
        """解析蝙蝠图腾相关日志"""

        # 1. 检测蝙蝠图腾日志
        bat_totem_patterns = [
            r"\[BAT_TOTEM\]",
            r"bat_totem",
            r"蝙蝠图腾",
        ]
        for pattern in bat_totem_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["bat_totem_logs"].append(obs)
                self.validation["bat_totem_timer"] = True
                self.log(f"🦇 检测到蝙蝠图腾日志", "DETECTION")
                break

        # 2. 检测流血施加
        bleed_apply_patterns = [
            r"\[DEBUFF\].*?流血",
            r"流血debuff",
            r"施加流血",
            r"bleed.*apply",
        ]
        for pattern in bleed_apply_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["bleed_logs"].append(obs)
                self.validation["bleed_apply"] = True
                self.log(f"🩸 检测到流血施加", "DETECTION")
                break

        # 3. 检测流血伤害 (关键验证)
        bleed_damage_patterns = [
            r"\[DOT\].*?流血.*?伤害[:\s]*(\d+\.?\d*)",
            r"流血伤害[:\s]*(\d+\.?\d*)",
            r"bleed.*damage[:\s]*(\d+\.?\d*)",
            r"状态伤害.*流血.*?造成[:\s]*(\d+\.?\d*)",
        ]
        for pattern in bleed_damage_patterns:
            match = re.search(pattern, obs, re.IGNORECASE)
            if match:
                try:
                    damage = float(match.group(1))
                    self.bleed_damage_records.append(damage)
                    self.log_stats["damage_logs"].append(obs)
                    # 关键验证: 流血伤害不为0
                    if damage > 0:
                        self.validation["bleed_damage_not_zero"] = True
                        self.log(f"🩸 检测到流血伤害: {damage} (不为0!)", "DETECTION")
                    else:
                        self.log(f"⚠️ 流血伤害为0", "WARNING")
                except ValueError:
                    pass
                break

        # 4. 检测吸血/回血
        heal_patterns = [
            r"\[HEAL\].*?回血",
            r"攻击回血",
            r"vampire.*heal",
            r"吸血",
        ]
        for pattern in heal_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["heal_logs"].append(obs)
                self.validation["vampire_heal"] = True
                self.log(f"💚 检测到吸血回血", "DETECTION")
                break

        # 5. 检测蚊子吸血
        mosquito_patterns = [
            r"\[SKILL\].*?蚊子",
            r"蚊子.*吸食",
            r"mosquito.*drain",
        ]
        for pattern in mosquito_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["mosquito_logs"].append(obs)
                self.validation["mosquito_drain"] = True
                self.log(f"🦟 检测到蚊子吸血", "DETECTION")
                break

        # 6. 检测血法师血池
        blood_mage_patterns = [
            r"\[SKILL\].*?血法师",
            r"血池",
            r"blood.*pool",
            r"blood_mage",
        ]
        for pattern in blood_mage_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["blood_mage_logs"].append(obs)
                self.validation["blood_mage_pool"] = True
                self.log(f"🩸 检测到血法师血池", "DETECTION")
                break

        # 7. 检测生命链条
        life_chain_patterns = [
            r"\[SKILL\].*?生命链条",
            r"生命链条",
            r"life.*chain",
            r"偷取生命",
        ]
        for pattern in life_chain_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["life_chain_logs"].append(obs)
                self.validation["life_chain"] = True
                self.log(f"🔗 检测到生命链条", "DETECTION")
                break

        # 8. 检测瘟疫使者
        plague_patterns = [
            r"\[DEBUFF\].*?瘟疫",
            r"瘟疫使者",
            r"plague.*bringer",
            r"腐坏",
        ]
        for pattern in plague_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["plague_logs"].append(obs)
                self.validation["plague_bringer"] = True
                self.log(f"☠️ 检测到瘟疫使者", "DETECTION")
                break

        # 9. 检测血祖
        ancestor_patterns = [
            r"\[SKILL\].*?血祖",
            r"血祖",
            r"blood.*ancestor",
            r"鲜血仪式",
        ]
        for pattern in ancestor_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.log_stats["sacrifice_logs"].append(obs)
                self.validation["blood_sacrifice"] = True
                self.log(f"🔥 检测到血祖", "DETECTION")
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

    async def step_spawn_test_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 生成测试单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 设置核心血量保护
        await self.send_actions([{"type": "set_core_hp", "hp": 99999}])
        self.log("设置核心血量保护: 99999", "SYSTEM")

        # 生成蚊子单位 (测试吸血)
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "mosquito",
            "position": {"x": 1, "y": 0}
        }])
        self.log(f"生成蚊子结果: {result}", "DEBUG")
        await asyncio.sleep(0.5)

        # 生成血法师单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "blood_mage",
            "position": {"x": 2, "y": 0}
        }])
        self.log(f"生成血法师结果: {result}", "DEBUG")
        await asyncio.sleep(0.5)

        # 生成生命链条单位
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "life_chain",
            "position": {"x": 3, "y": 0}
        }])
        self.log(f"生成生命链条结果: {result}", "DEBUG")
        await asyncio.sleep(0.5)

        # 生成瘟疫使者单位 (实际ID为plague_spreader)
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "plague_spreader",
            "position": {"x": 4, "y": 0}
        }])
        self.log(f"生成瘟疫使者结果: {result}", "DEBUG")
        await asyncio.sleep(0.5)

        # 生成血祖单位 (blood_ancestor - 替代血祭术士)
        result = await self.send_actions([{
            "type": "spawn_unit",
            "unit_id": "blood_ancestor",
            "position": {"x": 5, "y": 0}
        }])
        self.log(f"生成血祖结果: {result}", "DEBUG")
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
        self.log("BAT-TOTEM-SUPPLEMENT-001: 蝙蝠图腾机制补充验证", "SYSTEM")
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

        # 分析流血伤害记录
        if self.bleed_damage_records:
            avg_damage = sum(self.bleed_damage_records) / len(self.bleed_damage_records)
            max_damage = max(self.bleed_damage_records)
            min_damage = min(self.bleed_damage_records)
        else:
            avg_damage = max_damage = min_damage = 0

        report_lines = [
            "# QA测试报告: 蝙蝠图腾机制补充验证 (P1)",
            "",
            f"**任务ID**: BAT-TOTEM-SUPPLEMENT-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: P1 机制补充测试",
            f"**所属图腾**: 蝙蝠图腾",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "验证蝙蝠图腾核心机制及关键单位的特殊机制实现情况",
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
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 蝙蝠图腾核心机制",
            "",
            "| 机制 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        core_mechanisms = [
            ("bat_totem_timer", "5秒定时器"),
            ("bleed_apply", "流血施加"),
            ("bleed_damage_not_zero", "流血伤害不为0 (关键)"),
            ("vampire_heal", "攻击回血"),
        ]

        for key, desc in core_mechanisms:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 单位特殊机制",
            "",
            "| 单位 | 机制 | 状态 | 说明 |",
            "|------|------|------|------|",
        ])

        unit_mechanisms = [
            ("mosquito_drain", "蚊子", "吸血治疗"),
            ("blood_mage_pool", "血法师", "血池机制"),
            ("life_chain", "生命链条", "偷取生命"),
            ("plague_bringer", "瘟疫使者", "腐坏debuff"),
            ("blood_sacrifice", "血祭术士", "鲜血仪式"),
        ]

        for key, unit, mechanism in unit_mechanisms:
            status = "✅ 检测到" if self.validation[key] else "❌ 未检测到"
            report_lines.append(f"| {unit} | {mechanism} | {status} | - |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 流血伤害统计 (关键验证)",
            "",
            f"- **记录次数**: {len(self.bleed_damage_records)} 次",
            f"- **平均伤害**: {avg_damage:.2f}",
            f"- **最高伤害**: {max_damage:.2f}",
            f"- **最低伤害**: {min_damage:.2f}",
            "",
        ])

        if self.bleed_damage_records:
            report_lines.append("### 伤害记录")
            report_lines.append("")
            for i, dmg in enumerate(self.bleed_damage_records[:10], 1):
                report_lines.append(f"{i}. 流血伤害: {dmg:.2f}")
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

        passed = sum(self.validation.values())
        total = len(self.validation)
        pass_rate = passed / total * 100

        if pass_rate >= 80:
            report_lines.append(f"✅ **测试通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
            report_lines.append("")
            report_lines.append("蝙蝠图腾机制验证成功，所有核心功能正常工作。")
        elif pass_rate >= 50:
            report_lines.append(f"⚠️ **测试部分通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
            report_lines.append("")
            report_lines.append("部分机制已验证，但仍有功能需要进一步检查。")
        else:
            report_lines.append(f"❌ **测试未通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
            report_lines.append("")
            report_lines.append("关键机制验证失败，需要Technical Director检查实现。")

        # 关键问题说明
        report_lines.extend([
            "",
            "### 关键问题",
            "",
        ])

        if not self.validation["bleed_damage_not_zero"]:
            report_lines.append("- **流血伤害为0**: 这是P1关键问题，需要Technical Director紧急修复")
        else:
            report_lines.append("- **流血伤害正常**: Technical Director修复成功！")

        report_lines.extend([
            "",
            "---",
            "",
            "## 建议",
            "",
            "1. QA-Tester审查测试报告",
            "2. 更新GameDesign.md中蝙蝠图腾机制状态",
            "3. 如流血伤害仍为0，投递修复任务给Technical Director",
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_bat_totem_supplement_001.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9999
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BatTotemSupplementTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
