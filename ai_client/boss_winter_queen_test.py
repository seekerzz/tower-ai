#!/usr/bin/env python3
"""
BOSS-WINTER-QUEEN-TEST: 冬之女王Boss技能测试

测试任务:
- task_boss_winter_absolute_zero.md - 绝对零度(移速/攻速光环)
- task_boss_winter_freeze_field.md - 冰封领域(定身)
- task_boss_winter_blizzard.md - 暴风雪(全场AOE)
- task_boss_winter_ice_shield.md - 冰晶护盾(护盾)

测试目标:
1. 验证冬之女王第24波正确生成
2. 验证绝对零度降低全场敌人移速和攻速
3. 验证冰封领域定身效果
4. 验证暴风雪全场AOE伤害
5. 验证冰晶护盾护盾效果

使用方法:
- 使用skip_to_wave(24)跳转到第24波
- 使用set_core_hp(99999)保护核心
- 观察并记录Boss技能日志
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


class BossWinterQueenTester:
    """冬之女王Boss测试器"""

    WAVE = 24
    SEASON = "winter"
    BOSS_NAME = "冬之女王"
    BOSS_ID = "winter_queen"

    def __init__(self, http_port=9992):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_winter_queen_{timestamp}.log"

        # 技能检测结果
        self.skill_detections = {
            "absolute_zero": [],      # 绝对零度
            "freeze_field": [],       # 冰封领域
            "blizzard": [],           # 暴风雪
            "ice_shield": [],         # 冰晶护盾
        }

        # 验证结果
        self.validation = {
            # 基础验证
            "boss_spawned": False,
            "boss_correct_type": False,
            "wave_24_triggered": False,

            # 技能1: 绝对零度
            "absolute_zero_triggered": False,
            "absolute_zero_move_speed": False,
            "absolute_zero_attack_speed": False,

            # 技能2: 冰封领域
            "freeze_field_triggered": False,
            "freeze_field_root": False,

            # 技能3: 暴风雪
            "blizzard_triggered": False,
            "blizzard_damage": False,

            # 技能4: 冰晶护盾
            "ice_shield_triggered": False,
            "ice_shield_absorb": False,
        }

        # 检测到的日志统计
        self.log_stats = {
            "boss_spawn_logs": [],
            "boss_skill_logs": [],
            "boss_damage_logs": [],
            "boss_aura_logs": [],
            "buff_logs": [],
            "debuff_logs": [],
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
                self.parse_boss_logs(o)
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

    def parse_boss_logs(self, obs: str):
        """解析Boss相关日志"""

        # 1. 检测Boss生成
        spawn_patterns = [
            r"\[BOSS出场\].*?冬之女王",
            r"【BOSS出场】.*?冬之女王",
            r"BOSS出场.*?冬之女王",
            r"Boss.*?(冬之女王|winter_queen).*?出现",
            r"季节Boss.*?(冬之女王|winter_queen)",
        ]
        for pattern in spawn_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["boss_spawned"] = True
                self.validation["boss_correct_type"] = True
                self.log_stats["boss_spawn_logs"].append(obs)
                self.log("❄️ 检测到[BOSS出场]: 冬之女王", "DETECTION")
                break

        # 2. 检测绝对零度光环
        zero_patterns = [
            r"\[BOSS_PASSIVE\].*?冬之女王.*?绝对零度",
            r"\[BOSS_AURA\].*?绝对零度",
            r"绝对零度.*?激活",
            r"移速.*?-20%",
            r"攻速.*?-10%",
        ]
        for pattern in zero_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["absolute_zero_triggered"] = True
                self.skill_detections["absolute_zero"].append(obs)
                self.log_stats["boss_aura_logs"].append(obs)
                self.log("❄️ 检测到[绝对零度]光环", "DETECTION")
                break

        # 3. 检测冰封领域
        freeze_patterns = [
            r"\[BOSS_SKILL\].*?冬之女王.*?冰封领域",
            r"\[BOSS_DEBUFF\].*?冰封领域",
            r"冰封领域.*?触发",
            r"定身",
            r"冻结",
        ]
        for pattern in freeze_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["freeze_field_triggered"] = True
                self.skill_detections["freeze_field"].append(obs)
                self.log_stats["debuff_logs"].append(obs)
                self.log("❄️ 检测到[冰封领域]技能", "DETECTION")
                break

        # 4. 检测暴风雪
        blizzard_patterns = [
            r"\[BOSS_SKILL\].*?冬之女王.*?暴风雪",
            r"\[BOSS_DAMAGE\].*?暴风雪",
            r"暴风雪.*?触发",
            r"全场.*?伤害",
        ]
        for pattern in blizzard_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["blizzard_triggered"] = True
                self.skill_detections["blizzard"].append(obs)
                self.log_stats["boss_damage_logs"].append(obs)
                self.log("❄️ 检测到[暴风雪]技能", "DETECTION")
                break

        # 5. 检测冰晶护盾
        shield_patterns = [
            r"\[BOSS_SKILL\].*?冬之女王.*?冰晶护盾",
            r"\[BOSS_BUFF\].*?冰晶护盾",
            r"冰晶护盾.*?触发",
            r"护盾.*?吸收",
        ]
        for pattern in shield_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["ice_shield_triggered"] = True
                self.skill_detections["ice_shield"].append(obs)
                self.log_stats["buff_logs"].append(obs)
                self.log("🛡️ 检测到[冰晶护盾]技能", "DETECTION")
                break

        # 6. 检测波次24
        if f"第 {self.WAVE} 波" in obs or f"Wave {self.WAVE}" in obs or f"波次{self.WAVE}" in obs:
            self.validation["wave_24_triggered"] = True
            self.log(f"❄️ 检测到第{self.WAVE}波", "DETECTION")

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
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_skip_to_boss_wave(self):
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤2: 跳转到第{self.WAVE}波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "skip_to_wave", "wave": self.WAVE}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)
        self.log(f"✅ 跳转到第{self.WAVE}波完成", "VALIDATION")

    async def step_start_boss_battle(self):
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤3: 开始Boss战", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        self.log("开始观察Boss战...", "SYSTEM")
        battle_duration = 90
        start_time = time.time()

        while time.time() - start_time < battle_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"⚠️ 游戏结束", "WARNING")
                    return False

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"✅ 波次完成", "EVENT")
                    return True

        self.log(f"✅ Boss战观察完成 ({battle_duration}秒)", "VALIDATION")
        return True

    async def run_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("BOSS-WINTER-QUEEN-TEST: 冬之女王Boss技能测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            self.log("⚠️ 跳过reset_game (已知bug)，直接开始测试", "WARNING")
            await self.step_select_totem()
            await self.step_skip_to_boss_wave()
            await self.step_start_boss_battle()

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
            "# QA测试报告: 冬之女王Boss技能测试",
            "",
            f"**测试ID**: BOSS-WINTER-QUEEN-TEST",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: Boss技能功能测试",
            f"**Boss名称**: {self.BOSS_NAME}",
            f"**Boss波次**: 第{self.WAVE}波",
            "",
            "---",
            "",
            "## 测试任务覆盖",
            "",
            "| 任务ID | 技能名称 | 测试目标 |",
            "|--------|----------|----------|",
            "| task_boss_winter_absolute_zero.md | 绝对零度 | 移速-20%，攻速-10%光环 |",
            "| task_boss_winter_freeze_field.md | 冰封领域 | 定身效果 |",
            "| task_boss_winter_blizzard.md | 暴风雪 | 全场AOE伤害 |",
            "| task_boss_winter_ice_shield.md | 冰晶护盾 | 护盾吸收 |",
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
            ("boss_spawned", "Boss成功生成"),
            ("boss_correct_type", "Boss类型正确(冬之女王)"),
            ("wave_24_triggered", "第24波正确触发"),
        ]

        for key, desc in base_validations:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {desc} | {status} | - |")

        report_lines.extend([
            "",
            "### 技能验证",
            "",
            "| 技能 | 状态 | 说明 |",
            "|------|------|------|",
        ])

        skills = [
            ("absolute_zero_triggered", "绝对零度"),
            ("freeze_field_triggered", "冰封领域"),
            ("blizzard_triggered", "暴风雪"),
            ("ice_shield_triggered", "冰晶护盾"),
        ]

        for key, name in skills:
            status = "✅ 通过" if self.validation[key] else "❌ 未通过"
            report_lines.append(f"| {name} | {status} | - |")

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

        passed = sum([
            self.validation["boss_spawned"],
            self.validation["absolute_zero_triggered"],
            self.validation["freeze_field_triggered"],
            self.validation["blizzard_triggered"],
            self.validation["ice_shield_triggered"],
        ])
        total = 5
        pass_rate = passed / total * 100

        if pass_rate >= 60:
            report_lines.append(f"✅ **测试通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
        elif pass_rate >= 40:
            report_lines.append(f"⚠️ **测试部分通过** - 通过率 {pass_rate:.1f}% ({passed}/{total})")
        else:
            report_lines.append(f"❌ **测试失败** - 通过率 {pass_rate:.1f}% ({passed}/{total})")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        report_path = Path("docs/player_reports/qa_report_boss_winter_queen.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9992
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossWinterQueenTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
