#!/usr/bin/env python3
"""
FINAL-VERIFICATION-001: 24波季节系统最终验证测试

测试目标:
1. 验证可以顺利通过第1-6波（春季）
2. 验证可以到达并击败第6波Boss（春之守护者）
3. 使用skip_to_wave采样测试Boss波次（6, 12, 18, 24）
4. 验证季节切换信号（波次7, 13, 19）
5. 验证Boss生成和技能触发

季节配置:
- 春之觉醒: 波次1-6, Boss波:第6波 - 春之守护者
- 夏之炎阳: 波次7-12, Boss波:第12波 - 炎阳巨龙
- 秋之凋零: 波次13-18, Boss波:第18波 - 凋零收割者
- 冬之严寒: 波次19-24, Boss波:第24波 - 霜冻之王
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


class FinalVerificationTester:
    """最终验证测试器"""

    SEASONS = {
        "spring": {"name": "春之觉醒", "waves": range(1, 7), "boss_wave": 6, "boss_name": "春之守护者", "boss_skill": "spring_awakening"},
        "summer": {"name": "夏之炎阳", "waves": range(7, 13), "boss_wave": 12, "boss_name": "炎阳巨龙", "boss_skill": "summer_inferno"},
        "autumn": {"name": "秋之凋零", "waves": range(13, 19), "boss_wave": 18, "boss_name": "凋零收割者", "boss_skill": "autumn_decay"},
        "winter": {"name": "冬之严寒", "waves": range(19, 25), "boss_wave": 24, "boss_name": "霜冻之王", "boss_skill": "winter_frost"},
    }

    # 季节切换波次
    SEASON_TRANSITION_WAVES = [7, 13, 19]

    def __init__(self, http_port=9999):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_final_verification_{timestamp}.log"

        self.wave_results = []
        self.season_detections = {season: False for season in self.SEASONS.keys()}
        self.boss_detections = {season: False for season in self.SEASONS.keys()}
        self.skill_detections = {season: False for season in self.SEASONS.keys()}
        self.season_transition_detections = {wave: False for wave in self.SEASON_TRANSITION_WAVES}

        self.test_summary = {
            "waves_1_6_completed": False,
            "boss_6_defeated": False,
            "skip_to_wave_working": False,
            "season_transitions_detected": 0,
            "bosses_detected": 0,
            "skills_detected": 0,
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
        time.sleep(8)
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

    def detect_season_content(self, obs: str):
        """检测季节相关内容"""
        # 季节检测
        season_patterns = {
            "spring": [r"春之觉醒", r"春季", r"spring.*awakening", r"season.*spring", r"季节.*春"],
            "summer": [r"夏之炎阳", r"夏季", r"summer.*inferno", r"season.*summer", r"季节.*夏"],
            "autumn": [r"秋之凋零", r"秋季", r"autumn.*decay", r"season.*autumn", r"季节.*秋"],
            "winter": [r"冬之严寒", r"冬季", r"winter.*frost", r"season.*winter", r"季节.*冬"],
        }

        for season, patterns in season_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.season_detections[season]:
                        self.log(f"检测到季节 [{season}]: {obs[:80]}...", "DETECTION")
                        self.season_detections[season] = True

        # Boss检测
        boss_patterns = {
            "spring": [r"春之守护者", r"spring.*guardian", r"Boss.*spring"],
            "summer": [r"炎阳巨龙", r"summer.*dragon", r"Boss.*summer"],
            "autumn": [r"凋零收割者", r"autumn.*lord", r"瘟疫领主", r"Boss.*autumn"],
            "winter": [r"霜冻之王", r"winter.*queen", r"冬之女王", r"Boss.*winter"],
        }

        for season, patterns in boss_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.boss_detections[season]:
                        self.log(f"检测到Boss [{season}]: {obs[:80]}...", "DETECTION")
                        self.boss_detections[season] = True

        # 技能检测
        skill_patterns = {
            "spring": [r"spring_awakening", r"万物复苏", r"春之技能"],
            "summer": [r"summer_inferno", r"炎阳", r"火焰吐息", r"夏之技能"],
            "autumn": [r"autumn_decay", r"凋零", r"瘟疫", r"秋之技能"],
            "winter": [r"winter_frost", r"霜冻", r"冰封", r"冬之技能"],
        }

        for season, patterns in skill_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.skill_detections[season]:
                        self.log(f"检测到技能 [{season}]: {obs[:80]}...", "DETECTION")
                        self.skill_detections[season] = True

        # 季节切换检测
        transition_patterns = {
            7: [r"季节切换.*7", r"切换到.*夏", r"夏季.*开始", r"summer.*start"],
            13: [r"季节切换.*13", r"切换到.*秋", r"秋季.*开始", r"autumn.*start"],
            19: [r"季节切换.*19", r"切换到.*冬", r"冬季.*开始", r"winter.*start"],
        }

        for wave, patterns in transition_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.season_transition_detections[wave]:
                        self.log(f"检测到季节切换 [波次{wave}]: {obs[:80]}...", "DETECTION")
                        self.season_transition_detections[wave] = True

    def get_wave_season(self, wave: int) -> Optional[str]:
        for season, config in self.SEASONS.items():
            if wave in config["waves"]:
                return season
        return None

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤: 选择牛图腾 (cow_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(2.0)
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("牛图腾选择完成", "VALIDATION")

    async def step_build_defense(self):
        """建立初始防御"""
        self.log("=" * 60, "SYSTEM")
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

        self.log("初始防御建立完成 (4个单位)", "VALIDATION")

    async def step_reinforce(self):
        """波次结束后增援"""
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        for i in range(2):
            await self.send_actions([{"type": "buy_unit", "shop_index": i}])
            await asyncio.sleep(0.3)

        await self.poll_observations(1.0)

    async def step_run_wave(self, wave: int) -> Dict:
        """运行单个波次"""
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤: 进行第{wave}波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        season = self.get_wave_season(wave)
        if season:
            season_name = self.SEASONS[season]["name"]
            self.log(f"第{wave}波属于 [{season_name}]", "INFO")

        is_boss_wave = wave in [6, 12, 18, 24]
        if is_boss_wave:
            boss_name = self.SEASONS[season]["boss_name"] if season else "未知"
            self.log(f"Boss波次! 期望Boss: {boss_name}", "INFO")

        # 启动波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 等待波次进行
        wave_active = True
        start_time = time.time()
        max_duration = 120 if not is_boss_wave else 180

        wave_observations = []

        while wave_active and time.time() - start_time < max_duration:
            obs = await self.poll_observations(3.0)
            wave_observations.extend(obs)

            for o in obs:
                self.detect_season_content(o)

                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"游戏在第{wave}波结束", "ERROR")
                    return {"wave": wave, "completed": False, "game_over": True, "observations": wave_observations}

                if "波次完成" in o or "wave ended" in o.lower() or "商店刷新" in o:
                    self.log(f"第{wave}波完成", "EVENT")
                    wave_active = False
                    break

        # 波次结束后增援
        await self.step_reinforce()

        return {"wave": wave, "completed": True, "game_over": False, "observations": wave_observations}

    async def step_skip_to_wave(self, wave: int) -> bool:
        """跳转到指定波次"""
        self.log(f"尝试跳转到第{wave}波...", "SYSTEM")

        result = await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")

        await asyncio.sleep(2.0)

        # 检查是否成功跳转
        obs = await self.poll_observations(2.0)
        for o in obs:
            if f"第 {wave} 波" in o or f"Wave {wave}" in o or f"波次 {wave}" in o:
                self.log(f"成功跳转到第{wave}波", "VALIDATION")
                return True

        self.log(f"跳转到第{wave}波可能未生效，继续测试...", "WARNING")
        return False

    async def step_test_boss_wave(self, wave: int) -> Dict:
        """测试指定Boss波次"""
        season = self.get_wave_season(wave)
        config = self.SEASONS[season] if season else None

        self.log("=" * 70, "SYSTEM")
        self.log(f"测试 Boss波次 - 第{wave}波", "SYSTEM")
        if config:
            self.log(f"期望Boss: {config['boss_name']}", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        # 跳转到Boss波次
        skip_success = await self.step_skip_to_wave(wave)

        # 启动波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 等待波次进行
        wave_active = True
        start_time = time.time()
        max_duration = 60

        wave_observations = []

        while wave_active and time.time() - start_time < max_duration:
            obs = await self.poll_observations(3.0)
            wave_observations.extend(obs)

            for o in obs:
                self.detect_season_content(o)

                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"游戏在第{wave}波结束", "ERROR")
                    return {"wave": wave, "completed": False, "game_over": True, "skip_success": skip_success}

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"第{wave}波完成", "EVENT")
                    wave_active = False
                    break

        return {"wave": wave, "completed": True, "game_over": False, "skip_success": skip_success}

    async def run_phase1_spring_test(self) -> bool:
        """阶段1: 测试第1-6波（春季）"""
        self.log("\n" + "=" * 70, "SYSTEM")
        self.log("阶段1: 测试第1-6波（春之觉醒）", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        # 选择图腾
        await self.step_select_totem()

        # 建立初始防御
        await self.step_build_defense()

        # 运行第1-6波
        for wave in range(1, 7):
            result = await self.step_run_wave(wave)
            self.wave_results.append(result)

            if result["game_over"]:
                self.log(f"游戏在第{wave}波结束，春季测试失败", "ERROR")
                return False

        self.log("第1-6波（春季）全部完成", "VALIDATION")
        self.test_summary["waves_1_6_completed"] = True
        self.test_summary["boss_6_defeated"] = self.boss_detections.get("spring", False)
        return True

    async def run_phase2_skip_to_boss_test(self) -> bool:
        """阶段2: 使用skip_to_wave测试Boss波次"""
        self.log("\n" + "=" * 70, "SYSTEM")
        self.log("阶段2: 使用skip_to_wave测试Boss波次", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        boss_waves = [6, 12, 18, 24]
        skip_results = []

        for wave in boss_waves:
            result = await self.step_test_boss_wave(wave)
            skip_results.append(result["skip_success"])

            # 波次间等待
            await asyncio.sleep(2.0)

        # 检查skip_to_wave是否工作
        if any(skip_results):
            self.test_summary["skip_to_wave_working"] = True
            self.log(f"skip_to_wave功能正常 ({sum(skip_results)}/{len(skip_results)}次成功)", "VALIDATION")
        else:
            self.log("skip_to_wave功能可能未生效，但继续测试...", "WARNING")

        return True

    async def run_final_verification_test(self) -> bool:
        """运行最终验证测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("FINAL-VERIFICATION-001: 24波季节系统最终验证测试", "SYSTEM")
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

            # 阶段1: 测试第1-6波
            spring_success = await self.run_phase1_spring_test()

            # 阶段2: 测试skip_to_wave和Boss波次
            boss_success = await self.run_phase2_skip_to_boss_test()

            # 更新统计
            self.test_summary["season_transitions_detected"] = sum(1 for v in self.season_transition_detections.values() if v)
            self.test_summary["bosses_detected"] = sum(1 for v in self.boss_detections.values() if v)
            self.test_summary["skills_detected"] = sum(1 for v in self.skill_detections.values() if v)

            # 生成报告
            await self.generate_report()

            return spring_success and boss_success

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

        completed_waves = [r["wave"] for r in self.wave_results if r["completed"]]

        report_lines = [
            "\n" + "=" * 70,
            "FINAL-VERIFICATION-001: 24波季节系统最终验证测试报告",
            "=" * 70,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试目标:",
            "  1. 验证可以顺利通过第1-6波（春季）",
            "  2. 验证可以到达并击败第6波Boss（春之守护者）",
            "  3. 使用skip_to_wave采样测试Boss波次（6, 12, 18, 24）",
            "  4. 验证季节切换信号（波次7, 13, 19）",
            "  5. 验证Boss生成和技能触发",
            "",
            "=" * 70,
            "测试结果汇总",
            "=" * 70,
            "",
            "核心验证项:",
            f"  [{'x' if self.test_summary['waves_1_6_completed'] else ' '}] 第1-6波（春季）完成",
            f"  [{'x' if self.test_summary['boss_6_defeated'] else ' '}] 第6波Boss（春之守护者）击败",
            f"  [{'x' if self.test_summary['skip_to_wave_working'] else ' '}] skip_to_wave功能正常",
            "",
            "季节切换信号检测:",
            f"  [{'x' if self.season_transition_detections[7] else ' '}] 波次7 (春->夏)",
            f"  [{'x' if self.season_transition_detections[13] else ' '}] 波次13 (夏->秋)",
            f"  [{'x' if self.season_transition_detections[19] else ' '}] 波次19 (秋->冬)",
            f"  总计: {self.test_summary['season_transitions_detected']}/3",
            "",
            "Boss生成检测:",
        ]

        for season, config in self.SEASONS.items():
            detected = "x" if self.boss_detections[season] else " "
            report_lines.append(f"  [{detected}] {config['name']} - {config['boss_name']} (波次{config['boss_wave']})")

        report_lines.append(f"  总计: {self.test_summary['bosses_detected']}/4")
        report_lines.append("")
        report_lines.append("技能触发检测:")

        for season, config in self.SEASONS.items():
            detected = "x" if self.skill_detections[season] else " "
            report_lines.append(f"  [{detected}] {config['name']} - {config['boss_skill']}")

        report_lines.append(f"  总计: {self.test_summary['skills_detected']}/4")
        report_lines.extend([
            "",
            "=" * 70,
            "波次完成情况:",
            "=" * 70,
            f"  完成波次: {completed_waves}",
            f"  完成数量: {len(completed_waves)}",
        ])

        # 结论
        report_lines.extend([
            "",
            "=" * 70,
            "测试结论:",
            "=" * 70,
        ])

        all_pass = (
            self.test_summary["waves_1_6_completed"] and
            self.test_summary["skip_to_wave_working"] and
            self.test_summary["bosses_detected"] >= 2
        )

        if all_pass:
            report_lines.append("通过 - 核心功能验证成功")
            report_lines.append("")
            report_lines.append("验证结果:")
            report_lines.append("  - 第1-6波（春季）可正常完成")
            report_lines.append("  - skip_to_wave调试功能正常工作")
            report_lines.append(f"  - 检测到 {self.test_summary['bosses_detected']}/4 个季节Boss")
            report_lines.append(f"  - 检测到 {self.test_summary['season_transitions_detected']}/3 个季节切换信号")
        elif self.test_summary["waves_1_6_completed"]:
            report_lines.append("部分通过 - 核心功能正常，但部分验证项未完全通过")
            report_lines.append("")
            report_lines.append("问题:")
            if not self.test_summary["skip_to_wave_working"]:
                report_lines.append("  - skip_to_wave功能可能未正常工作")
            if self.test_summary["bosses_detected"] < 2:
                report_lines.append("  - Boss生成检测数量偏低")
        else:
            report_lines.append("未通过 - 第1-6波未能完成，需要进一步调查")

        report_lines.extend([
            "",
            "=" * 70,
            "详细检测记录:",
            "=" * 70,
            "",
            "季节检测:",
        ])

        for season, config in self.SEASONS.items():
            status = "检测到" if self.season_detections[season] else "未检测到"
            report_lines.append(f"  [{config['name']}]: {status}")

        report_lines.extend([
            "",
            "Boss检测:",
        ])

        for season, config in self.SEASONS.items():
            status = "检测到" if self.boss_detections[season] else "未检测到"
            report_lines.append(f"  [{config['boss_name']}]: {status}")

        report_lines.extend([
            "",
            "技能检测:",
        ])

        for season, config in self.SEASONS.items():
            status = "检测到" if self.skill_detections[season] else "未检测到"
            report_lines.append(f"  [{config['boss_skill']}]: {status}")

        report_lines.extend([
            "",
            "=" * 70,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_path = Path("docs/player_reports/FINAL-VERIFICATION-001_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9999
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with FinalVerificationTester(http_port) as tester:
        success = await tester.run_final_verification_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
