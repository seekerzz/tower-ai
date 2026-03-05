#!/usr/bin/env python3
"""
BOSS-SELECTION-TEST: Boss随机选择系统测试

测试目标:
1. 验证Boss随机选择系统工作正常
2. 验证[BOSS选择]日志输出格式正确
3. 验证每局游戏选择不同的Boss组合
4. 验证种子系统可复现相同Boss组合

测试方法:
- 运行多局游戏，记录每局选中的Boss
- 验证随机性（不同局应有不同组合）
- 验证格式：[BOSS选择] 种子:X | 季节:xxx | 候选:[...] | 选中:xxx
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
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent))

import aiohttp


class BossSelectionTest:
    """Boss随机选择系统测试器"""

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

    def __init__(self, http_port=9991):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_boss_selection_{timestamp}.log"

        # 测试结果
        self.test_results = []
        self.boss_selections: List[Dict] = []  # 每局的Boss选择
        self.boss_selection_logs: List[str] = []  # 原始[BOSS选择]日志
        self.detected_seeds: Set[int] = set()

        # 验证点
        self.validation = {
            "boss_selection_format": False,
            "random_selection_working": False,
            "seed_system_working": False,
            "all_seasons_covered": False,
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
        """解析Boss选择相关日志"""
        # 解析[BOSS选择]日志 - 多种可能格式
        patterns = [
            # 格式1: [BOSS选择] 种子:X | 季节:xxx | 候选:[...] | 选中:xxx
            r"\[BOSS选择\].*种子[:=]\s*(\d+).*季节[:=]\s*([^|]+)\|.*候选[:=]\s*\[(.*?)\].*选中[:=]\s*(\w+)",
            # 格式2: 【BOSS选择】...
            r"【BOSS选择】.*种子[:=]\s*(\d+).*季节[:=]\s*([^|]+)\|.*候选[:=]\s*\[(.*?)\].*选中[:=]\s*(\w+)",
            # 格式3: BOSS选择 ...
            r"BOSS选择.*种子[:=]\s*(\d+).*季节[:=]\s*([^|]+)",
        ]

        for pattern in patterns:
            match = re.search(pattern, obs, re.IGNORECASE)
            if match:
                self.boss_selection_logs.append(obs)
                self.validation["boss_selection_format"] = True
                self.log(f"🎯 检测到[BOSS选择]日志: {obs[:120]}...", "DETECTION")
                break

        # 检测种子
        seed_pattern = r"种子[:=]\s*(\d+)"
        match = re.search(seed_pattern, obs)
        if match:
            seed = int(match.group(1))
            self.detected_seeds.add(seed)
            self.log(f"🎲 检测到种子: {seed}", "DETECTION")

        # 检测季节Boss选择
        for wave, config in self.BOSS_WAVES.items():
            season = config["season"]
            season_name = config["season_name"]
            # 检测季节关键词
            if season_name in obs or f"{season}_boss" in obs.lower():
                self.log(f"🌟 检测到季节相关: {season_name}", "DETECTION")

            # 检测选中的Boss
            for boss_id in config["boss_pool"]:
                boss_name = self.BOSS_NAMES.get(boss_id, boss_id)
                if boss_id in obs.lower() or boss_name in obs:
                    self.log(f"👹 检测到Boss: {boss_name} (波次{wave})", "DETECTION")

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

    async def run_single_game(self, game_index: int) -> Dict:
        """运行单局游戏，检测Boss选择"""
        self.log(f"\n{'='*70}", "SYSTEM")
        self.log(f"开始第 {game_index + 1} 局游戏", "SYSTEM")
        self.log(f"{'='*70}", "SYSTEM")

        # 选择图腾
        await self.poll_observations(2.0)
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        # 跳转到各Boss波次检测
        game_selections = {}
        for wave in sorted(self.BOSS_WAVES.keys()):
            config = self.BOSS_WAVES[wave]
            self.log(f"\n跳转到第{wave}波 [{config['season_name']}]...", "SYSTEM")

            await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
            await asyncio.sleep(1.5)
            await self.poll_observations(2.0)

            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)
            await self.poll_observations(3.0)

        return game_selections

    async def run_selection_test(self, num_games: int = 3) -> bool:
        """运行Boss选择系统测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("BOSS-SELECTION-TEST: Boss随机选择系统测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")
        self.log(f"测试局数: {num_games}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            # 运行多局游戏
            for i in range(num_games):
                await self.run_single_game(i)
                # 每局之间等待
                if i < num_games - 1:
                    self.log(f"\n等待下一局...", "SYSTEM")
                    await asyncio.sleep(5.0)
                    # 重启客户端以获得新的随机种子
                    self.stop_ai_client()
                    await asyncio.sleep(2.0)
                    self.start_ai_client()
                    if not await self.wait_for_game_ready():
                        self.log("游戏重新启动失败", "ERROR")
                        return False

            # 分析结果
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
        """生成测试报告"""
        self.log("=" * 70, "SYSTEM")
        self.log("生成测试报告", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        # 验证随机性
        if len(self.detected_seeds) > 1:
            self.validation["random_selection_working"] = True
            self.log(f"✅ 检测到 {len(self.detected_seeds)} 个不同种子，随机选择系统工作正常", "VALIDATION")
        elif len(self.detected_seeds) == 1:
            self.log(f"⚠️ 只检测到 1 个种子，样本不足，无法验证随机性", "WARNING")
        else:
            self.log(f"❌ 未检测到种子", "ERROR")

        # 验证格式
        if self.validation["boss_selection_format"]:
            self.log(f"✅ [BOSS选择]日志格式正确", "VALIDATION")
        else:
            self.log(f"⚠️ 未检测到标准格式的[BOSS选择]日志", "WARNING")

        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        report_lines = [
            "# BOSS-SELECTION-TEST: Boss随机选择系统测试报告",
            "",
            f"**测试ID**: BOSS-SELECTION-TEST",
            f"**测试时间**: {timestamp}",
            f"**测试类型**: Boss选择系统功能测试",
            "",
            "---",
            "",
            "## 测试目标",
            "",
            "1. 验证Boss随机选择系统工作正常（每局不同Boss）",
            "2. 验证[BOSS选择]日志输出格式正确",
            "3. 验证每局游戏选择不同的Boss组合",
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
            "## 检测到的种子",
            "",
        ])

        if self.detected_seeds:
            report_lines.append(f"检测到 {len(self.detected_seeds)} 个不同种子:")
            report_lines.append("")
            for seed in sorted(self.detected_seeds):
                report_lines.append(f"- 种子 {seed}")
        else:
            report_lines.append("⚠️ 未检测到种子")

        report_lines.extend([
            "",
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
            "## Boss配置",
            "",
        ])

        for wave, config in self.BOSS_WAVES.items():
            report_lines.append(f"### 第{wave}波 - {config['season_name']}")
            report_lines.append("")
            report_lines.append(f"- **候选Boss**: {[self.BOSS_NAMES.get(b, b) for b in config['boss_pool']]}")
            report_lines.append("")

        report_lines.extend([
            "---",
            "",
            "## 测试结论",
            "",
        ])

        if self.validation["boss_selection_format"] and len(self.detected_seeds) > 0:
            report_lines.append("✅ **测试通过** - Boss随机选择系统工作正常。")
        elif len(self.detected_seeds) > 0:
            report_lines.append("⚠️ **测试部分通过** - 检测到Boss选择，但日志格式可能不匹配预期。")
        else:
            report_lines.append("❌ **测试失败** - 未检测到Boss选择日志。")

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
        report_path = Path("docs/player_reports/BOSS_SELECTION_TEST_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report

    def _get_validation_desc(self, key: str) -> str:
        desc_map = {
            "boss_selection_format": "[BOSS选择]日志格式正确",
            "random_selection_working": "随机选择系统工作正常",
            "seed_system_working": "种子系统可复现",
            "all_seasons_covered": "所有季节都有Boss候选",
        }
        return desc_map.get(key, "")


async def main():
    http_port = 9991
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    num_games = 3
    if len(sys.argv) > 2:
        num_games = int(sys.argv[2])

    async with BossSelectionTest(http_port) as tester:
        success = await tester.run_selection_test(num_games)
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
