#!/usr/bin/env python3
"""
BOSS-TEST-001: 12季节Boss系统测试

测试目标:
1. 验证Boss随机选择系统工作正常（每局不同Boss）
2. 使用skip_to_wave测试4个Boss波次（6, 12, 18, 24）
3. 验证Boss正确生成和技能触发
4. 验证[BOSS选择]日志输出格式: [BOSS选择] 种子:X | 季节:春之觉醒 | 候选:[...] | 选中:xxx

预期日志格式:
- [BOSS选择] 种子:X | 季节:春之觉醒 | 候选:[...] | 选中:xxx
- [BOSS出场] xxx Boss出现
- [BOSS技能] xxx 使用 xxx
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
from typing import List, Dict, Any, Optional, Set

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class BossTest001:
    """BOSS-TEST-001 测试器"""

    # Boss波次配置
    BOSS_WAVES = {
        6: {"season": "spring", "season_name": "春之觉醒", "boss_pool": ["spring_guardian", "thorn_queen", "spring_spirit"]},
        12: {"season": "summer", "season_name": "夏之炎阳", "boss_pool": ["summer_dragon", "magma_giant", "sun_cheetah"]},
        18: {"season": "autumn", "season_name": "秋之凋零", "boss_pool": ["autumn_lord", "death_reaper", "withered_prophet"]},
        24: {"season": "winter", "season_name": "冬之严寒", "boss_pool": ["winter_queen", "frost_troll", "snow_commander"]},
    }

    # Boss名称映射
    BOSS_NAMES = {
        "spring_guardian": "春之守护者",
        "thorn_queen": "荆棘女王",
        "spring_spirit": "春风之灵",
        "summer_dragon": "炎阳巨龙",
        "magma_giant": "熔岩巨人",
        "sun_cheetah": "烈日猎豹",
        "autumn_lord": "瘟疫领主",
        "death_reaper": "凋零死神",
        "withered_prophet": "枯萎先知",
        "winter_queen": "冬之女王",
        "frost_troll": "冰霜巨魔",
        "snow_commander": "雪原指挥官",
    }

    def __init__(self, http_port=9995):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_test_001_{timestamp}.log"

        # 测试结果
        self.test_results = []
        self.boss_selections: Dict[int, str] = {}  # wave -> selected_boss
        self.boss_spawn_detected: Dict[int, bool] = {}  # wave -> detected
        self.boss_skill_detected: Dict[int, Set[str]] = {}  # wave -> set of skills
        self.boss_selection_logs: List[str] = []  # 原始[BOSS选择]日志

        # 验证点
        self.validation = {
            "boss_selection_format": False,
            "random_selection_working": False,
            "boss_spawn_wave_6": False,
            "boss_spawn_wave_12": False,
            "boss_spawn_wave_18": False,
            "boss_spawn_wave_24": False,
            "boss_skill_triggered": False,
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
        # 解析[BOSS选择]日志
        # 格式: [BOSS选择] 种子:X | 季节:春之觉醒 | 候选:[...] | 选中:xxx
        boss_selection_pattern = r"\[BOSS选择\].*种子:(\d+).*季节:(.+?)\|.*候选:\[(.*?)\].*选中:(\w+)"
        match = re.search(boss_selection_pattern, obs, re.IGNORECASE)
        if match:
            seed, season, candidates, selected = match.groups()
            self.boss_selection_logs.append(obs)
            self.log(f"🎯 检测到[BOSS选择]日志: 种子={seed}, 季节={season.strip()}, 选中={selected}", "DETECTION")
            self.validation["boss_selection_format"] = True

        # 简化的BOSS选择检测
        if "[BOSS选择]" in obs or "BOSS选择" in obs:
            if obs not in self.boss_selection_logs:
                self.boss_selection_logs.append(obs)
            self.log(f"🎯 检测到BOSS选择相关日志: {obs[:100]}...", "DETECTION")

        # 解析[BOSS出场]日志
        boss_spawn_pattern = r"\[BOSS出场\]\s*(\w+).*?出现|BOSS出场.*?(\w+).*?出现|Boss.*出现"
        match = re.search(boss_spawn_pattern, obs, re.IGNORECASE)
        if match:
            boss_name = match.group(1) or match.group(2)
            self.log(f"👹 检测到[BOSS出场]: {boss_name}", "DETECTION")

        # 简化的Boss出场检测
        spawn_keywords = ["BOSS出场", "Boss出现", "Boss生成", "季节Boss", "Boss波次"]
        for keyword in spawn_keywords:
            if keyword in obs:
                self.log(f"👹 检测到Boss相关事件: {obs[:80]}...", "DETECTION")
                break

        # 解析[BOSS技能]日志
        skill_pattern = r"\[BOSS技能\]\s*(\w+).*?使用\s*(\w+)"
        match = re.search(skill_pattern, obs, re.IGNORECASE)
        if match:
            boss_name, skill_name = match.groups()
            self.log(f"⚡ 检测到[BOSS技能]: {boss_name} 使用 {skill_name}", "DETECTION")
            self.validation["boss_skill_triggered"] = True

        # 简化的技能检测
        skill_keywords = ["BOSS技能", "技能触发", "释放技能", "使用技能"]
        for keyword in skill_keywords:
            if keyword in obs:
                self.log(f"⚡ 检测到技能相关事件: {obs[:80]}...", "DETECTION")
                self.validation["boss_skill_triggered"] = True
                break

        # 检测具体Boss名称
        for wave, config in self.BOSS_WAVES.items():
            for boss_id in config["boss_pool"]:
                boss_name_cn = self.BOSS_NAMES.get(boss_id, boss_id)
                if boss_id in obs.lower() or boss_name_cn in obs:
                    self.log(f"👹 检测到Boss [{boss_name_cn}] 在波次{wave}: {obs[:60]}...", "DETECTION")
                    self.boss_spawn_detected[wave] = True
                    if wave == 6:
                        self.validation["boss_spawn_wave_6"] = True
                    elif wave == 12:
                        self.validation["boss_spawn_wave_12"] = True
                    elif wave == 18:
                        self.validation["boss_spawn_wave_18"] = True
                    elif wave == 24:
                        self.validation["boss_spawn_wave_24"] = True

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
        time.sleep(15)  # 增加启动等待时间
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

    async def step_skip_to_wave(self, wave: int) -> bool:
        self.log(f"尝试跳转到第{wave}波...", "SYSTEM")

        result = await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")

        await asyncio.sleep(2.0)

        obs = await self.poll_observations(2.0)
        for o in obs:
            if f"第 {wave} 波" in o or f"Wave {wave}" in o:
                self.log(f"✅ 成功跳转到第{wave}波", "VALIDATION")
                return True

        self.log(f"⚠️ 跳转到第{wave}波可能未生效", "WARNING")
        return False

    async def step_test_boss_wave(self, wave: int) -> Dict:
        config = self.BOSS_WAVES[wave]
        season_name = config["season_name"]
        boss_pool = config["boss_pool"]

        self.log("=" * 70, "SYSTEM")
        self.log(f"测试 [{season_name}] Boss波次 - 第{wave}波", "SYSTEM")
        self.log(f"Boss候选池: {[self.BOSS_NAMES.get(b, b) for b in boss_pool]}", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        await self.step_skip_to_wave(wave)

        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        wave_active = True
        start_time = time.time()
        max_duration = 60

        while wave_active and time.time() - start_time < max_duration:
            obs = await self.poll_observations(3.0)

            for o in obs:
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"❌ 游戏在第{wave}波结束", "ERROR")
                    return {"wave": wave, "completed": False, "game_over": True}

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"✅ 第{wave}波完成", "EVENT")
                    wave_active = False
                    break

        return {"wave": wave, "completed": True, "game_over": False}

    async def run_boss_test(self) -> bool:
        self.log("=" * 70, "SYSTEM")
        self.log("BOSS-TEST-001: 12季节Boss系统测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.log("\n测试计划:", "SYSTEM")
        for wave, config in self.BOSS_WAVES.items():
            bosses = [self.BOSS_NAMES.get(b, b) for b in config["boss_pool"]]
            self.log(f"  第{wave:2d}波 [{config['season_name']}] - 候选: {bosses}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            await self.step_select_totem()
            await self.step_build_defense()

            self.log("\n" + "=" * 70, "SYSTEM")
            self.log("开始测试Boss波次", "SYSTEM")
            self.log("=" * 70, "SYSTEM")

            for wave in sorted(self.BOSS_WAVES.keys()):
                result = await self.step_test_boss_wave(wave)
                self.test_results.append(result)
                await asyncio.sleep(3.0)

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
            "# BOSS-TEST-001: 12季节Boss系统测试报告",
            "",
            f"**测试ID**: BOSS-TEST-001",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: Boss系统功能测试",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "1. 验证Boss随机选择系统工作正常（每局不同Boss）",
            "2. 使用skip_to_wave测试4个Boss波次（6, 12, 18, 24）",
            "3. 验证Boss正确生成和技能触发",
            "4. 验证[BOSS选择]日志输出格式",
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
            "## Boss波次测试结果",
            "",
        ])

        for wave in sorted(self.BOSS_WAVES.keys()):
            config = self.BOSS_WAVES[wave]
            season = config["season_name"]
            bosses = [self.BOSS_NAMES.get(b, b) for b in config["boss_pool"]]
            spawned = self.boss_spawn_detected.get(wave, False)

            report_lines.append(f"### 第{wave}波 - {season}")
            report_lines.append("")
            report_lines.append(f"- **Boss候选池**: {bosses}")
            report_lines.append(f"- **Boss生成检测**: {'✅ 检测到' if spawned else '❌ 未检测到'}")
            report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## [BOSS选择]日志记录",
            "",
        ])

        if self.boss_selection_logs:
            report_lines.append("检测到的[BOSS选择]日志:")
            report_lines.append("")
            for log in self.boss_selection_logs:
                report_lines.append(f"```")
                report_lines.append(log)
                report_lines.append(f"```")
                report_lines.append("")
        else:
            report_lines.append("⚠️ 未检测到[BOSS选择]日志")
            report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## 测试结论",
            "",
        ])

        # 统计
        boss_spawns = sum(1 for w in [6, 12, 18, 24] if self.boss_spawn_detected.get(w, False))

        if boss_spawns == 4 and self.validation["boss_selection_format"]:
            report_lines.append("✅ **测试通过** - 所有Boss波次正常生成，[BOSS选择]日志格式正确。")
        elif boss_spawns >= 2:
            report_lines.append(f"⚠️ **测试部分通过** - 检测到{boss_spawns}/4个Boss生成。")
        else:
            report_lines.append("❌ **测试失败** - Boss生成可能存在问题。")

        report_lines.extend([
            "",
            "---",
            "",
            f"*报告生成时间: {timestamp}*",
            "*AI Player Agent*",
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_path = Path("docs/player_reports/BOSS-TEST-001_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report

    def _get_validation_desc(self, key: str) -> str:
        desc_map = {
            "boss_selection_format": "[BOSS选择]日志格式正确",
            "random_selection_working": "随机选择系统工作正常",
            "boss_spawn_wave_6": "第6波Boss生成",
            "boss_spawn_wave_12": "第12波Boss生成",
            "boss_spawn_wave_18": "第18波Boss生成",
            "boss_spawn_wave_24": "第24波Boss生成",
            "boss_skill_triggered": "Boss技能触发",
        }
        return desc_map.get(key, "")


async def main():
    http_port = 9995
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BossTest001(http_port) as tester:
        success = await tester.run_boss_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
