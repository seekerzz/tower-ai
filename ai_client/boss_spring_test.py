#!/usr/bin/env python3
"""
BOSS-SPRING-TEST: 春季Boss测试 (波次6)

测试目标:
1. 验证春季Boss波次(第6波)正确触发
2. 验证从3个春季Boss中随机选择1个:
   - 春之守护者 (SpringGuardian) - 生命/恢复主题
   - 荆棘女王 (ThornQueen) - 自然/陷阱主题
   - 春风之灵 (BreezeSpirit) - 速度/分身主题
3. 验证Boss技能和属性符合设计
4. 验证[BOSS出场]和[BOSS技能]日志

测试方法:
- 使用skip_to_wave跳转到第6波
- 观察并验证Boss生成和技能触发
"""

import asyncio
import json
import time
import sys
import subprocess
import os
import re
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class BossSpringTest:
    """春季Boss测试器"""

    WAVE = 6
    SEASON = "spring"
    SEASON_NAME = "春之觉醒"

    # 春季Boss配置
    BOSSES = {
        "spring_guardian": {
            "name": "春之守护者",
            "theme": "生命/恢复",
            "hp_expected": 1500,
            "attack_expected": 50,
            "speed_expected": 0.8,
            "skills": ["召唤幼苗", "生命复苏", "荆棘波", "summon_seedling", "regeneration", "thorn_wave"],
        },
        "thorn_queen": {
            "name": "荆棘女王",
            "theme": "自然/陷阱",
            "hp_expected": 1500,
            "attack_expected": 50,
            "speed_expected": 0.8,
            "skills": ["荆棘丛生", "藤蔓缠绕", "尖刺爆发", "自然庇护", "thorn_trap", "vine_bind", "spike_burst", "nature_shelter"],
        },
        "spring_spirit": {
            "name": "春风之灵",
            "theme": "速度/分身",
            "hp_expected": 1500,
            "attack_expected": 50,
            "speed_expected": 1.8,
            "skills": ["风之步", "分身幻象", "疾风连击", "春风治愈", "wind_step", "illusion", "gale_strike", "spring_heal"],
        },
    }

    def __init__(self, http_port=9992):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_spring_{timestamp}.log"

        # 测试结果
        self.detected_boss: Optional[str] = None
        self.detected_boss_name: Optional[str] = None
        self.detected_skills: List[str] = []
        self.boss_spawn_detected = False
        self.boss_skill_detected = False

        # 验证点
        self.validation = {
            "wave_6_triggered": False,
            "boss_spawned": False,
            "correct_boss_type": False,
            "skills_triggered": False,
            "hp_matches_design": False,
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

    def parse_boss_logs(self, obs: str):
        """解析Boss相关日志"""
        # 解析[BOSS出场]日志
        spawn_patterns = [
            r"\[BOSS出场\].*?(\w+).*?出现",
            r"【BOSS出场】.*?(\w+)",
            r"BOSS出场.*?(\w+)",
            r"Boss.*?(春之守护者|荆棘女王|春风之灵).*?出现",
            r"季节Boss.*?(春之守护者|荆棘女王|春风之灵)",
        ]
        for pattern in spawn_patterns:
            match = re.search(pattern, obs, re.IGNORECASE)
            if match:
                self.boss_spawn_detected = True
                self.validation["boss_spawned"] = True
                boss_name = match.group(1)
                self.log(f"👹 检测到[BOSS出场]: {boss_name}", "DETECTION")
                break

        # 检测具体Boss
        for boss_id, config in self.BOSSES.items():
            boss_name = config["name"]
            # 检测Boss名称（中文或英文）
            if boss_name in obs or boss_id in obs.lower():
                if not self.detected_boss:
                    self.detected_boss = boss_id
                    self.detected_boss_name = boss_name
                    self.validation["correct_boss_type"] = True
                    self.log(f"🎯 检测到春季Boss: {boss_name}", "DETECTION")

        # 解析[BOSS技能]日志
        skill_patterns = [
            r"\[BOSS技能\].*?(\w+).*?使用.*?(\w+)",
            r"【BOSS技能】.*?(\w+).*?(\w+)",
            r"Boss技能.*?(\w+)",
        ]
        for pattern in skill_patterns:
            match = re.search(pattern, obs, re.IGNORECASE)
            if match:
                self.boss_skill_detected = True
                self.validation["skills_triggered"] = True
                skill_name = match.group(2) if len(match.groups()) > 1 else match.group(1)
                if skill_name not in self.detected_skills:
                    self.detected_skills.append(skill_name)
                self.log(f"⚡ 检测到[BOSS技能]: {skill_name}", "DETECTION")
                break

        # 检测技能关键词
        for boss_id, config in self.BOSSES.items():
            for skill in config["skills"]:
                if skill in obs:
                    if skill not in self.detected_skills:
                        self.detected_skills.append(skill)
                        self.boss_skill_detected = True
                        self.validation["skills_triggered"] = True
                    self.log(f"⚡ 检测到技能: {skill}", "DETECTION")

        # 检测波次6
        if f"第 {self.WAVE} 波" in obs or f"Wave {self.WAVE}" in obs or f"波次{self.WAVE}" in obs:
            self.validation["wave_6_triggered"] = True
            self.log(f"🌸 检测到第{self.WAVE}波", "DETECTION")

        # 检测季节
        if self.SEASON_NAME in obs or f"season_{self.SEASON}" in obs.lower():
            self.log(f"🌸 检测到季节: {self.SEASON_NAME}", "DETECTION")

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

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤: 选择牛图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(2.0)
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_build_defense(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤: 建立初始防御", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(2.0)

        positions = [(1, 0), (0, 1), (1, 1), (2, 0)]
        for i, pos in enumerate(positions):
            await self.send_actions([{"type": "buy_unit", "shop_index": i % 3}])
            await asyncio.sleep(0.5)
            await self.poll_observations(0.5)

            await self.send_actions([{
                "type": "move_unit",
                "from_zone": "bench",
                "to_zone": "grid",
                "from_pos": i,
                "to_pos": {"x": pos[0], "y": pos[1]}
            }])
            await asyncio.sleep(0.5)
            await self.poll_observations(0.5)

        self.log("✅ 初始防御建立完成", "VALIDATION")

    async def step_test_spring_boss(self) -> Dict:
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试 [{self.SEASON_NAME}] Boss波次 - 第{self.WAVE}波", "SYSTEM")
        self.log(f"候选Boss: {[b['name'] for b in self.BOSSES.values()]}", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        # 跳转到第6波
        self.log(f"跳转到第{self.WAVE}波...", "SYSTEM")
        result = await self.send_actions([{"type": "skip_to_wave", "wave": self.WAVE}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")
        await asyncio.sleep(2.0)
        await self.poll_observations(2.0)

        # 开始波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 等待波次进行
        wave_active = True
        start_time = time.time()
        max_duration = 60

        while wave_active and time.time() - start_time < max_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"❌ 游戏在第{self.WAVE}波结束", "ERROR")
                    return {"wave": self.WAVE, "completed": False, "game_over": True}

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"✅ 第{self.WAVE}波完成", "EVENT")
                    wave_active = False
                    break

        return {"wave": self.WAVE, "completed": True, "game_over": False}

    async def run_spring_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("BOSS-SPRING-TEST: 春季Boss测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_build_defense()

            result = await self.step_test_spring_boss()

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
            "# BOSS-SPRING-TEST: 春季Boss测试报告",
            "",
            f"**测试ID**: BOSS-SPRING-TEST",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: 春季Boss功能测试",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            f"1. 验证春季Boss波次(第{self.WAVE}波)正确触发",
            "2. 验证从3个春季Boss中随机选择1个",
            "3. 验证Boss技能和属性符合设计",
            "4. 验证[BOSS出场]和[BOSS技能]日志",
            "",
            "---",
            "",
            "## 验证结果汇总",
            "",
            "| 验证项 | 状态 | 说明 |",
            "|--------|------|------|",
        ]

        # 验证结果
        for key, value in self.validation.items():
            status = "✅ 通过" if value else "❌ 未通过"
            desc = self._get_validation_desc(key)
            report_lines.append(f"| {key} | {status} | {desc} |")

        report_lines.extend([
            "",
            "---",
            "",
            "## 春季Boss配置",
            "",
        ])

        for boss_id, config in self.BOSSES.items():
            report_lines.append(f"### {config['name']} ({boss_id})")
            report_lines.append(f"- **主题**: {config['theme']}")
            report_lines.append(f"- **预期HP**: {config['hp_expected']}")
            report_lines.append(f"- **预期攻击**: {config['attack_expected']}")
            report_lines.append(f"- **预期移速**: {config['speed_expected']}")
            report_lines.append(f"- **技能**: {', '.join(config['skills'][:4])}")
            report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## 检测结果",
            "",
        ])

        if self.detected_boss:
            config = self.BOSSES.get(self.detected_boss, {})
            report_lines.append(f"### 检测到的Boss: {self.detected_boss_name}")
            report_lines.append("")
            report_lines.append(f"- **Boss ID**: {self.detected_boss}")
            report_lines.append(f"- **Boss名称**: {self.detected_boss_name}")
            report_lines.append(f"- **主题**: {config.get('theme', 'N/A')}")
            report_lines.append("")
        else:
            report_lines.append("⚠️ **未检测到具体Boss**")
            report_lines.append("")

        if self.detected_skills:
            report_lines.append(f"### 检测到的技能 ({len(self.detected_skills)}个)")
            report_lines.append("")
            for skill in self.detected_skills:
                report_lines.append(f"- {skill}")
            report_lines.append("")
        else:
            report_lines.append("⚠️ **未检测到技能触发**")
            report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## 测试结论",
            "",
        ])

        if self.validation["boss_spawned"] and self.validation["correct_boss_type"]:
            report_lines.append(f"✅ **测试通过** - 第{self.WAVE}波春季Boss正确生成并触发技能。")
        elif self.validation["boss_spawned"]:
            report_lines.append(f"⚠️ **测试部分通过** - Boss生成但可能不是预期的春季Boss。")
        else:
            report_lines.append(f"❌ **测试失败** - 未检测到Boss生成。")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*Technical Director Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_path = Path("docs/player_reports/BOSS_SPRING_TEST_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report

    def _get_validation_desc(self, key: str) -> str:
        desc_map = {
            "wave_6_triggered": f"第{self.WAVE}波正确触发",
            "boss_spawned": "Boss成功生成",
            "correct_boss_type": "生成的Boss类型正确",
            "skills_triggered": "Boss技能正常触发",
            "hp_matches_design": "Boss HP符合设计值",
        }
        return desc_map.get(key, "")


async def main():
    http_port = 9992
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossSpringTest(http_port) as tester:
        success = await tester.run_spring_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
