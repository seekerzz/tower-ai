#!/usr/bin/env python3
"""
WAVE-SEASON-BOSS-001: 季节Boss波次测试

测试目标:
1. 直接测试4个季节Boss波次 (6, 12, 18, 24)
2. 验证季节切换信号
3. 验证Boss生成
4. 验证Boss技能

使用skip_to_wave调试功能跳转到指定波次
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


class SeasonBossTester:
    """季节Boss测试器"""

    SEASONS = {
        "spring": {"name": "春之觉醒", "boss_wave": 6, "boss_name": "春之守护者", "boss_skill": "spring_awakening"},
        "summer": {"name": "夏之炎阳", "boss_wave": 12, "boss_name": "炎阳巨龙", "boss_skill": "summer_inferno"},
        "autumn": {"name": "秋之凋零", "boss_wave": 18, "boss_name": "凋零收割者", "boss_skill": "autumn_decay"},
        "winter": {"name": "冬之严寒", "boss_wave": 24, "boss_name": "霜冻之王", "boss_skill": "winter_frost"},
    }

    def __init__(self, http_port=9994):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_season_boss_{timestamp}.log"

        self.test_results = []
        self.season_detections = {season: False for season in self.SEASONS.keys()}
        self.boss_detections = {season: False for season in self.SEASONS.keys()}
        self.skill_detections = {season: False for season in self.SEASONS.keys()}

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
            "spring": [r"春之觉醒", r"春季", r"spring.*awakening", r"season.*spring", r"季节切换.*春"],
            "summer": [r"夏之炎阳", r"夏季", r"summer.*inferno", r"season.*summer", r"季节切换.*夏"],
            "autumn": [r"秋之凋零", r"秋季", r"autumn.*decay", r"season.*autumn", r"季节切换.*秋"],
            "winter": [r"冬之严寒", r"冬季", r"winter.*frost", r"season.*winter", r"季节切换.*冬"],
        }

        for season, patterns in season_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.season_detections[season]:
                        self.log(f"🌟 检测到季节 [{season}]: {obs[:80]}...", "DETECTION")
                        self.season_detections[season] = True

        # Boss检测 - 12个Boss
        boss_patterns = {
            "spring": [r"春之守护者", r"spring.*guardian", r"季节Boss.*spring",
                      r"荆棘女王", r"thorn.*queen", r"BossSpringThornQueen",
                      r"春风之灵", r"breeze.*spirit", r"BossSpringBreezeSpirit"],
            "summer": [r"炎阳巨龙", r"summer.*dragon", r"季节Boss.*summer",
                      r"熔岩巨人", r"magma.*colossus", r"BossSummerMagmaColossus",
                      r"烈日猎豹", r"sun.*cheetah", r"BossSummerSunCheetah"],
            "autumn": [r"凋零收割者", r"autumn.*lord", r"瘟疫领主", r"季节Boss.*autumn",
                      r"凋零死神", r"death.*reaper", r"BossAutumnDeathReaper",
                      r"枯萎先知", r"withered.*prophet", r"BossAutumnWitheredProphet"],
            "winter": [r"霜冻之王", r"winter.*queen", r"冬之女王", r"季节Boss.*winter",
                      r"冰霜巨魔", r"frost.*troll", r"BossWinterFrostTroll",
                      r"雪原指挥官", r"snow.*commander", r"BossWinterSnowCommander"],
        }

        for season, patterns in boss_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.boss_detections[season]:
                        self.log(f"👹 检测到Boss [{season}]: {obs[:80]}...", "DETECTION")
                        self.boss_detections[season] = True

        # 技能检测 - 12个Boss的技能
        skill_patterns = {
            "spring": [r"spring_awakening", r"万物复苏", r"召唤幼苗", r"生命复苏", r"荆棘波",
                      r"summon_seedling", r"regeneration", r"thorn_wave"],
            "summer": [r"summer_inferno", r"炎阳", r"火焰吐息", r"陨石坠落", r"热浪",
                      r"fire_breath", r"meteor_fall", r"heat_wave"],
            "autumn": [r"autumn_decay", r"凋零", r"瘟疫", r"毒云", r"瘟疫传播",
                      r"poison_cloud", r"plague_spread", r"decay"],
            "winter": [r"winter_frost", r"霜冻", r"冰封", r"冰霜风暴", r"冻结", r"暴风雪", r"绝对零度",
                      r"ice_storm", r"freeze", r"blizzard", r"absolute_zero"],
        }

        for season, patterns in skill_patterns.items():
            for pattern in patterns:
                if re.search(pattern, obs, re.IGNORECASE):
                    if not self.skill_detections[season]:
                        self.log(f"⚡ 检测到技能 [{season}]: {obs[:80]}...", "DETECTION")
                        self.skill_detections[season] = True

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤: 选择牛图腾 (cow_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(2.0)
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

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

        self.log("✅ 初始防御建立完成", "VALIDATION")

    async def step_skip_to_wave(self, wave: int) -> bool:
        """跳转到指定波次"""
        self.log(f"尝试跳转到第{wave}波...", "SYSTEM")

        # 使用refresh_shop动作作为调试命令的载体
        # 因为HTTP API可能不直接支持skip_to_wave
        # 我们需要通过游戏内调试命令实现

        # 先尝试直接发送skip_to_wave动作
        result = await self.send_actions([{"type": "skip_to_wave", "wave": wave}])
        self.log(f"skip_to_wave结果: {result}", "DEBUG")

        await asyncio.sleep(2.0)

        # 检查是否成功跳转
        obs = await self.poll_observations(2.0)
        for o in obs:
            if f"第 {wave} 波" in o or f"Wave {wave}" in o:
                self.log(f"✅ 成功跳转到第{wave}波", "VALIDATION")
                return True

        self.log(f"⚠️ 跳转到第{wave}波可能未生效", "WARNING")
        return False

    async def step_test_boss_wave(self, season: str) -> Dict:
        """测试指定季节的Boss波次"""
        config = self.SEASONS[season]
        wave = config["boss_wave"]

        self.log("=" * 70, "SYSTEM")
        self.log(f"测试 [{config['name']}] Boss波次 - 第{wave}波", "SYSTEM")
        self.log(f"期望Boss: {config['boss_name']}", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        # 跳转到Boss波次
        await self.step_skip_to_wave(wave)

        # 启动波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 等待波次进行
        wave_active = True
        start_time = time.time()
        max_duration = 60  # 最多等待60秒

        wave_observations = []

        while wave_active and time.time() - start_time < max_duration:
            obs = await self.poll_observations(3.0)
            wave_observations.extend(obs)

            for o in obs:
                self.detect_season_content(o)

                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"❌ 游戏在第{wave}波结束", "ERROR")
                    return {"season": season, "wave": wave, "completed": False, "game_over": True}

                if "波次完成" in o or "wave ended" in o.lower():
                    self.log(f"✅ 第{wave}波完成", "EVENT")
                    wave_active = False
                    break

        return {"season": season, "wave": wave, "completed": True, "game_over": False}

    async def run_boss_test(self) -> bool:
        """运行季节Boss测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("WAVE-SEASON-BOSS-001: 季节Boss波次测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.log("\n测试计划:", "SYSTEM")
        for season, config in self.SEASONS.items():
            self.log(f"  [{config['name']}] 第{config['boss_wave']}波 - {config['boss_name']}", "SYSTEM")

        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            # 选择图腾
            await self.step_select_totem()

            # 建立初始防御
            await self.step_build_defense()

            # 测试每个季节的Boss波次
            self.log("\n" + "=" * 70, "SYSTEM")
            self.log("开始测试季节Boss", "SYSTEM")
            self.log("=" * 70, "SYSTEM")

            for season in self.SEASONS.keys():
                result = await self.step_test_boss_wave(season)
                self.test_results.append(result)

                # 波次间等待
                await asyncio.sleep(3.0)

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

        report_lines = [
            "\n" + "=" * 70,
            "WAVE-SEASON-BOSS-001: 季节Boss波次测试报告",
            "=" * 70,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试目标:",
            "  1. 验证4个季节Boss在波次6/12/18/24生成",
            "  2. 验证季节切换信号输出",
            "  3. 验证Boss技能正确触发",
            "",
            "季节Boss配置:",
            "-" * 70,
        ]

        for season, config in self.SEASONS.items():
            report_lines.append(f"  [{config['name']}]")
            report_lines.append(f"    Boss波: 第{config['boss_wave']}波")
            report_lines.append(f"    Boss名称: {config['boss_name']}")
            report_lines.append(f"    Boss技能: {config['boss_skill']}")

        report_lines.extend([
            "",
            "测试结果:",
            "-" * 70,
        ])

        for season in self.SEASONS.keys():
            config = self.SEASONS[season]
            season_detected = "✅" if self.season_detections[season] else "❌"
            boss_detected = "✅" if self.boss_detections[season] else "❌"
            skill_detected = "✅" if self.skill_detections[season] else "❌"

            report_lines.append(f"\n[{config['name']}]:")
            report_lines.append(f"  季节检测: {season_detected}")
            report_lines.append(f"  Boss生成: {boss_detected}")
            report_lines.append(f"  技能触发: {skill_detected}")

        # 统计
        seasons_detected = sum(1 for v in self.season_detections.values() if v)
        bosses_detected = sum(1 for v in self.boss_detections.values() if v)
        skills_detected = sum(1 for v in self.skill_detections.values() if v)

        report_lines.extend([
            "",
            "=" * 70,
            "统计汇总:",
            "=" * 70,
            f"  季节检测: {seasons_detected}/4",
            f"  Boss生成: {bosses_detected}/4",
            f"  技能触发: {skills_detected}/4",
        ])

        # 结论
        report_lines.extend([
            "",
            "=" * 70,
            "测试结论:",
            "=" * 70,
        ])

        if bosses_detected == 4:
            report_lines.append("✅ 测试通过 - 所有4个季节Boss全部检测到")
        elif bosses_detected >= 2:
            report_lines.append(f"⚠️ 测试部分通过 - 检测到{bosses_detected}/4个Boss")
        else:
            report_lines.append("❌ 测试失败 - Boss生成可能存在问题")

        report_lines.extend([
            "",
            "验证检查清单:",
            "-" * 70,
            f"- [{'x' if self.season_detections['spring'] else ' '}] 春季切换信号检测",
            f"- [{'x' if self.boss_detections['spring'] else ' '}] 春季Boss生成 (波次6)",
            f"- [{'x' if self.skill_detections['spring'] else ' '}] 春季Boss技能触发",
            f"- [{'x' if self.season_detections['summer'] else ' '}] 夏季切换信号检测",
            f"- [{'x' if self.boss_detections['summer'] else ' '}] 夏季Boss生成 (波次12)",
            f"- [{'x' if self.skill_detections['summer'] else ' '}] 夏季Boss技能触发",
            f"- [{'x' if self.season_detections['autumn'] else ' '}] 秋季切换信号检测",
            f"- [{'x' if self.boss_detections['autumn'] else ' '}] 秋季Boss生成 (波次18)",
            f"- [{'x' if self.skill_detections['autumn'] else ' '}] 秋季Boss技能触发",
            f"- [{'x' if self.season_detections['winter'] else ' '}] 冬季切换信号检测",
            f"- [{'x' if self.boss_detections['winter'] else ' '}] 冬季Boss生成 (波次24)",
            f"- [{'x' if self.skill_detections['winter'] else ' '}] 冬季Boss技能触发",
            "",
            "=" * 70,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_path = Path("docs/player_reports/wave_season_boss_report.md")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_path}", "SYSTEM")

        return report


async def main():
    http_port = 9994
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with SeasonBossTester(http_port) as tester:
        success = await tester.run_boss_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
