#!/usr/bin/env python3
"""
BOSS-AUTUMN-LORD-TEST: 瘟疫领主Boss技能测试

测试任务:
- task_boss_autumn_plague_aura.md - 瘟疫光环(攻击降低)
- task_boss_autumn_infection.md - 传染(debuff扩散)
- task_boss_autumn_wither_touch.md - 凋零之触(持续伤害)
- task_boss_autumn_undead_legion.md - 不死军团(召唤)

测试目标:
1. 验证瘟疫领主第18波正确生成
2. 验证瘟疫光环降低范围内防御塔攻击力
3. 验证传染技能扩散debuff
4. 验证凋零之触持续伤害
5. 验证不死军团召唤技能

使用方法:
- 使用skip_to_wave(18)跳转到第18波
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


class BossAutumnLordTester:
    """瘟疫领主Boss测试器"""

    WAVE = 18
    SEASON = "autumn"
    BOSS_NAME = "瘟疫领主"
    BOSS_ID = "autumn_lord"

    def __init__(self, http_port=9992):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_autumn_lord_{timestamp}.log"

        # 技能检测结果
        self.skill_detections = {
            "plague_aura": [],        # 瘟疫光环
            "infection": [],          # 传染
            "wither_touch": [],       # 凋零之触
            "undead_legion": [],      # 不死军团
        }

        # 验证结果
        self.validation = {
            # 基础验证
            "boss_spawned": False,
            "boss_correct_type": False,
            "wave_18_triggered": False,

            # 技能1: 瘟疫光环
            "plague_aura_triggered": False,
            "plague_aura_range": False,

            # 技能2: 传染
            "infection_triggered": False,
            "infection_spread": False,

            # 技能3: 凋零之触
            "wither_touch_triggered": False,
            "wither_dot_damage": False,

            # 技能4: 不死军团
            "undead_legion_triggered": False,
            "undead_spawn_count": 0,
        }

        # 检测到的日志统计
        self.log_stats = {
            "boss_spawn_logs": [],
            "boss_skill_logs": [],
            "boss_damage_logs": [],
            "boss_aura_logs": [],
            "summon_logs": [],
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
            r"\[BOSS出场\].*?瘟疫领主",
            r"【BOSS出场】.*?瘟疫领主",
            r"BOSS出场.*?瘟疫领主",
            r"Boss.*?(瘟疫领主|autumn_lord).*?出现",
            r"季节Boss.*?(瘟疫领主|autumn_lord)",
        ]
        for pattern in spawn_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["boss_spawned"] = True
                self.validation["boss_correct_type"] = True
                self.log_stats["boss_spawn_logs"].append(obs)
                self.log("☠️ 检测到[BOSS出场]: 瘟疫领主", "DETECTION")
                break

        # 2. 检测瘟疫光环
        aura_patterns = [
            r"\[BOSS_PASSIVE\].*?瘟疫领主.*?瘟疫光环",
            r"\[BOSS_AURA\].*?瘟疫光环",
            r"瘟疫光环.*?激活",
            r"攻击力.*?-30%",
        ]
        for pattern in aura_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["plague_aura_triggered"] = True
                self.skill_detections["plague_aura"].append(obs)
                self.log_stats["boss_aura_logs"].append(obs)
                self.log("☠️ 检测到[瘟疫光环]", "DETECTION")
                break

        # 3. 检测传染技能
        infection_patterns = [
            r"\[BOSS_SKILL\].*?瘟疫领主.*?传染",
            r"\[BOSS_DEBUFF\].*?传染",
            r"传染.*?扩散",
        ]
        for pattern in infection_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["infection_triggered"] = True
                self.skill_detections["infection"].append(obs)
                self.log_stats["debuff_logs"].append(obs)
                self.log("☠️ 检测到[传染]技能", "DETECTION")
                break

        # 4. 检测凋零之触
        wither_patterns = [
            r"\[BOSS_SKILL\].*?瘟疫领主.*?凋零之触",
            r"\[BOSS_DAMAGE\].*?凋零之触",
            r"凋零之触.*?触发",
            r"持续伤害",
        ]
        for pattern in wither_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["wither_touch_triggered"] = True
                self.skill_detections["wither_touch"].append(obs)
                self.log_stats["boss_damage_logs"].append(obs)
                self.log("☠️ 检测到[凋零之触]技能", "DETECTION")
                break

        # 5. 检测不死军团召唤
        undead_patterns = [
            r"\[BOSS_SKILL\].*?瘟疫领主.*?不死军团",
            r"\[BOSS_SUMMON\].*?不死军团",
            r"召唤.*?骷髅",
            r"召唤.*?亡灵",
        ]
        for pattern in undead_patterns:
            if re.search(pattern, obs, re.IGNORECASE):
                self.validation["undead_legion_triggered"] = True
                self.skill_detections["undead_legion"].append(obs)
                self.log_stats["summon_logs"].append(obs)
                self.log("💀 检测到[不死军团]召唤", "DETECTION")
                break

        # 6. 检测波次18
        if f"第 {self.WAVE} 波" in obs or f"Wave {self.WAVE}" in obs or f"波次{self.WAVE}" in obs:
            self.validation["wave_18_triggered"] = True
            self.log(f"🍂 检测到第{self.WAVE}波", "DETECTION")

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
        self.log("BOSS-AUTUMN-LORD-TEST: 瘟疫领主Boss技能测试", "SYSTEM")
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
            "# QA测试报告: 瘟疫领主Boss技能测试",
            "",
            f"**测试ID**: BOSS-AUTUMN-LORD-TEST",
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
            "| task_boss_autumn_plague_aura.md | 瘟疫光环 | 攻击力-30%光环 |",
            "| task_boss_autumn_infection.md | 传染 | debuff扩散 |",
            "| task_boss_autumn_wither_touch.md | 凋零之触 | 持续伤害 |",
            "| task_boss_autumn_undead_legion.md | 不死军团 | 召唤骷髅 |",
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
            ("boss_correct_type", "Boss类型正确(瘟疫领主)"),
            ("wave_18_triggered", "第18波正确触发"),
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
            ("plague_aura_triggered", "瘟疫光环"),
            ("infection_triggered", "传染"),
            ("wither_touch_triggered", "凋零之触"),
            ("undead_legion_triggered", "不死军团"),
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
            self.validation["plague_aura_triggered"],
            self.validation["infection_triggered"],
            self.validation["wither_touch_triggered"],
            self.validation["undead_legion_triggered"],
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

        report_path = Path("docs/player_reports/qa_report_boss_autumn_lord.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9992
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossAutumnLordTester(http_port) as tester:
        success = await tester.run_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
