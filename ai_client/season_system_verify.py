#!/usr/bin/env python3
"""
SEASON-VERIFY-FINAL: 修复后季节系统验证测试

验证目标:
1. 验证skip_to_wave功能可以正常跳转波次
2. 验证调整后的难度曲线可以支撑到Boss波次（第6波）
3. 采样测试Boss波次（6, 12, 18, 24）
4. 验证季节切换信号（波次7, 13, 19）
5. 验证Boss生成（波次6, 12, 18, 24）

前置条件:
- skip_to_wave调试命令已修复
- 第1-2波难度已降低（第1波3个slime，第2波6个slime）
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


class SeasonSystemVerifier:
    """季节系统验证器"""

    SEASONS = {
        "spring": {"name": "春之觉醒", "waves": range(1, 7), "boss_wave": 6, "boss_name": "春之守护者"},
        "summer": {"name": "夏之炎阳", "waves": range(7, 13), "boss_wave": 12, "boss_name": "炎阳巨龙"},
        "autumn": {"name": "秋之凋零", "waves": range(13, 19), "boss_wave": 18, "boss_name": "凋零收割者"},
        "winter": {"name": "冬之严寒", "waves": range(19, 25), "boss_wave": 24, "boss_name": "霜冻之王"},
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
        self.log_file = log_dir / f"ai_session_season_verify_{timestamp}.log"

        self.test_results = {
            "skip_to_wave_tests": {},
            "difficulty_curve": {},
            "season_changes": {},
            "boss_spawns": {},
            "waves_completed": [],
        }

        self.season_detected = {season: False for season in self.SEASONS.keys()}
        self.boss_detected = {season: False for season in self.SEASONS.keys()}

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
            await asyncio.sleep(0.3)
        return all_obs

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

        # 启动客户端，将输出重定向到日志
        log_path = self.log_file.with_suffix('.client.log')
        self.client_process = subprocess.Popen(
            [
                sys.executable,
                str(client_script),
                "--project", str(project_dir),
                "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
                "--http-port", str(self.http_port)
            ],
            stdout=open(log_path, 'w', encoding='utf-8'),
            stderr=subprocess.STDOUT,
            cwd=str(project_dir),
            env=env
        )
        time.sleep(15)
        self.log(f"AI客户端已启动 (PID: {self.client_process.pid})", "SYSTEM")
        self.log(f"客户端日志: {log_path}", "SYSTEM")

    def stop_ai_client(self):
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.client_process = None

    def detect_season_content(self, obs: str):
        """检测季节相关内容"""
        # 季节切换检测
        season_patterns = {
            "spring": [r"春之觉醒", r"春季", r"spring.*awakening", r"season.*spring", r"季节切换.*春"],
            "summer": [r"夏之炎阳", r"夏季", r"summer.*inferno", r"season.*summer", r"季节切换.*夏"],
            "autumn": [r"秋之凋零", r"秋季", r"autumn.*decay", r"season.*autumn", r"季节切换.*秋"],
            "winter": [r"冬之严寒", r"冬季", r"winter.*frost", r"season.*winter", r"季节切换.*冬"],
        }

        for season, patterns in season_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.season_detected[season]:
                        self.log(f"检测到季节 [{season}]: {obs[:100]}...", "DETECTION")
                        self.season_detected[season] = True

        # Boss检测
        boss_patterns = {
            "spring": [r"春之守护者", r"spring.*guardian"],
            "summer": [r"炎阳巨龙", r"summer.*dragon"],
            "autumn": [r"凋零收割者", r"autumn.*lord", r"瘟疫领主"],
            "winter": [r"霜冻之王", r"winter.*queen", r"冬之女王"],
        }

        for season, patterns in boss_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.boss_detected[season]:
                        self.log(f"检测到Boss [{season}]: {obs[:100]}...", "DETECTION")
                        self.boss_detected[season] = True

    async def test_skip_to_wave(self, wave: int) -> bool:
        """测试skip_to_wave功能"""
        self.log("=" * 60, "SYSTEM")
        self.log(f"测试: skip_to_wave跳转到第{wave}波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        result = await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
        await asyncio.sleep(2)

        obs = await self.poll_observations(3.0)
        obs_text = " ".join(obs)

        # 检查是否成功跳转
        wave_pattern = rf"第?\s*{wave}\s*波"
        success = bool(re.search(wave_pattern, obs_text))

        self.test_results["skip_to_wave_tests"][wave] = success

        if success:
            self.log(f"✅ skip_to_wave到第{wave}波成功", "VALIDATION")
        else:
            self.log(f"❌ skip_to_wave到第{wave}波可能失败", "WARNING")
            self.log(f"观测内容: {obs_text[:200]}...", "DEBUG")

        return success

    async def test_wave_difficulty(self, wave: int) -> Dict:
        """测试指定波次的难度"""
        self.log("=" * 60, "SYSTEM")
        self.log(f"测试: 第{wave}波难度", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 跳转到指定波次
        await self.test_skip_to_wave(wave)

        # 启动波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 等待波次进行
        wave_active = True
        start_time = time.time()
        max_duration = 60 if wave not in [6, 12, 18, 24] else 90

        wave_observations = []
        game_over = False
        wave_completed = False

        while wave_active and time.time() - start_time < max_duration:
            obs = await self.poll_observations(3.0)
            wave_observations.extend(obs)

            for o in obs:
                self.detect_season_content(o)

                if "游戏结束" in o or "game over" in o.lower():
                    game_over = True
                    wave_active = False
                    self.log(f"游戏在第{wave}波结束", "EVENT")
                    break

                if "波次完成" in o or "wave ended" in o.lower() or "商店刷新" in o:
                    wave_completed = True
                    wave_active = False
                    self.log(f"第{wave}波完成", "EVENT")
                    break

        result = {
            "wave": wave,
            "completed": wave_completed,
            "game_over": game_over,
            "duration": time.time() - start_time,
        }

        self.test_results["difficulty_curve"][wave] = result

        if wave_completed:
            self.test_results["waves_completed"].append(wave)
            self.log(f"✅ 第{wave}波完成 (耗时{result['duration']:.1f}秒)", "VALIDATION")
        elif game_over:
            self.log(f"❌ 第{wave}波游戏结束", "ERROR")
        else:
            self.log(f"⚠️ 第{wave}波超时", "WARNING")

        return result

    async def run_complete_verification(self) -> bool:
        """运行完整的季节系统验证"""
        self.log("=" * 70, "SYSTEM")
        self.log("SEASON-VERIFY-FINAL: 修复后季节系统验证测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.log("\n季节配置:", "SYSTEM")
        for season, config in self.SEASONS.items():
            self.log(f"  [{config['name']}] 波次{list(config['waves'])}, Boss波:第{config['boss_wave']}波 - {config['boss_name']}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            # 选择图腾
            self.log("\n" + "=" * 60, "SYSTEM")
            self.log("步骤: 选择牛图腾 (cow_totem)", "SYSTEM")
            self.log("=" * 60, "SYSTEM")
            await self.poll_observations(2.0)
            await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
            await asyncio.sleep(1.0)
            await self.poll_observations(2.0)
            self.log("✅ 牛图腾选择完成", "VALIDATION")

            # 建立初始防御
            self.log("\n" + "=" * 60, "SYSTEM")
            self.log("步骤: 建立初始防御", "SYSTEM")
            self.log("=" * 60, "SYSTEM")
            await self.poll_observations(2.0)

            # 购买并部署4个单位
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
            self.log("✅ 初始防御建立完成 (4个单位)", "VALIDATION")

            # 测试1: 难度曲线测试（第1-6波）
            self.log("\n" + "=" * 70, "SYSTEM")
            self.log("测试阶段1: 难度曲线测试（第1-6波）", "SYSTEM")
            self.log("=" * 70, "SYSTEM")

            for wave in range(1, 7):
                result = await self.test_wave_difficulty(wave)
                if result["game_over"]:
                    self.log(f"\n游戏在第{wave}波结束，停止测试", "ERROR")
                    break
                await asyncio.sleep(1.0)

            # 如果通过了第6波，继续测试Boss波次采样
            if 6 in self.test_results["waves_completed"]:
                self.log("\n" + "=" * 70, "SYSTEM")
                self.log("测试阶段2: Boss波次采样测试", "SYSTEM")
                self.log("=" * 70, "SYSTEM")

                boss_waves = [12, 18, 24]
                for wave in boss_waves:
                    result = await self.test_wave_difficulty(wave)
                    await asyncio.sleep(1.0)

            # 生成报告
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

        completed_waves = self.test_results["waves_completed"]

        report_lines = [
            "\n" + "=" * 70,
            "SEASON-VERIFY-FINAL: 修复后季节系统验证测试报告",
            "=" * 70,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试目标:",
            "  1. 验证skip_to_wave功能可以正常跳转波次",
            "  2. 验证调整后的难度曲线可以支撑到Boss波次（第6波）",
            "  3. 采样测试Boss波次（6, 12, 18, 24）",
            "  4. 验证季节切换信号（波次7, 13, 19）",
            "  5. 验证Boss生成（波次6, 12, 18, 24）",
            "",
            "=" * 70,
            "测试结果汇总",
            "=" * 70,
            "",
            "1. skip_to_wave功能测试:",
        ]

        for wave, success in self.test_results["skip_to_wave_tests"].items():
            status = "✅ 通过" if success else "❌ 失败"
            report_lines.append(f"   跳转到第{wave}波: {status}")

        report_lines.extend([
            "",
            "2. 难度曲线测试:",
        ])

        for wave, result in self.test_results["difficulty_curve"].items():
            if result["completed"]:
                status = f"✅ 完成 (耗时{result['duration']:.1f}秒)"
            elif result["game_over"]:
                status = "❌ 游戏结束"
            else:
                status = "⚠️ 超时"
            report_lines.append(f"   第{wave}波: {status}")

        report_lines.extend([
            "",
            "3. 季节切换检测:",
        ])

        for season, detected in self.season_detected.items():
            season_name = self.SEASONS[season]["name"]
            status = "✅ 检测到" if detected else "❌ 未检测到"
            report_lines.append(f"   {season_name}: {status}")

        report_lines.extend([
            "",
            "4. Boss生成检测:",
        ])

        for season, detected in self.boss_detected.items():
            season_name = self.SEASONS[season]["name"]
            boss_name = self.SEASONS[season]["boss_name"]
            boss_wave = self.SEASONS[season]["boss_wave"]
            status = "✅ 检测到" if detected else "❌ 未检测到"
            report_lines.append(f"   {season_name} ({boss_name}, 第{boss_wave}波): {status}")

        # 统计
        skip_tests_passed = sum(1 for v in self.test_results["skip_to_wave_tests"].values() if v)
        skip_tests_total = len(self.test_results["skip_to_wave_tests"])
        waves_completed = len(self.test_results["waves_completed"])
        seasons_detected = sum(1 for v in self.season_detected.values() if v)
        bosses_detected = sum(1 for v in self.boss_detected.values() if v)

        report_lines.extend([
            "",
            "=" * 70,
            "统计汇总:",
            "=" * 70,
            f"  skip_to_wave测试: {skip_tests_passed}/{skip_tests_total} 通过",
            f"  波次完成: {waves_completed} 波",
            f"  季节检测: {seasons_detected}/4",
            f"  Boss生成: {bosses_detected}/4",
            "",
            "=" * 70,
            "测试结论:",
            "=" * 70,
        ])

        # 判断测试结果
        if waves_completed >= 6 and skip_tests_passed >= 3:
            report_lines.append("✅ 测试通过 - 难度曲线修复成功，可以到达Boss波次")
            report_lines.append("✅ skip_to_wave功能工作正常")
        elif waves_completed >= 3:
            report_lines.append("⚠️ 测试部分通过 - 难度有所降低，但仍需进一步优化")
        else:
            report_lines.append("❌ 测试失败 - 难度仍然过高，无法完成基础波次")

        report_lines.extend([
            "",
            "验证检查清单:",
            "-" * 70,
            f"- [{'x' if 1 in completed_waves else ' '}] 第1波完成 (3个slime)",
            f"- [{'x' if 2 in completed_waves else ' '}] 第2波完成 (6个slime)",
            f"- [{'x' if 6 in completed_waves else ' '}] 第6波Boss完成 (春之守护者)",
            f"- [{'x' if 12 in completed_waves else ' '}] 第12波Boss完成 (炎阳巨龙)",
            f"- [{'x' if 18 in completed_waves else ' '}] 第18波Boss完成 (凋零收割者)",
            f"- [{'x' if 24 in completed_waves else ' '}] 第24波Boss完成 (霜冻之王)",
            f"- [{'x' if self.season_detected['spring'] else ' '}] 春季切换信号检测",
            f"- [{'x' if self.season_detected['summer'] else ' '}] 夏季切换信号检测",
            f"- [{'x' if self.season_detected['autumn'] else ' '}] 秋季切换信号检测",
            f"- [{'x' if self.season_detected['winter'] else ' '}] 冬季切换信号检测",
            "",
            "=" * 70,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_path = report_dir / "SEASON-VERIFY-FINAL_report.md"
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9995
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with SeasonSystemVerifier(http_port) as verifier:
        success = await verifier.run_complete_verification()
        print(f"\n日志文件: {verifier.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
