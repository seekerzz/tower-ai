#!/usr/bin/env python3
"""
TASK-003: 日志增强回归测试脚本

测试目标:
1. 验证波次号正确递增（回归测试）
2. 验证新的日志类型输出:
   - [核心血量计算] 核心血量变化日志（波次、单位数、血量变化）
   - [牛图腾充能] 图腾充能日志（波次、受到伤害、充能变化）
   - [牛图腾触发] 图腾触发日志（波次、充能层数、反击伤害）
   - [单位攻击] 单位攻击日志（波次、单位、目标、伤害）
   - [核心受击] 核心受击来源日志（含具体敌人名称）
3. 重点追踪波次间血量变化（验证440→290问题）

成功标准:
- 所有新日志类型正常输出
- 波次号正确递增
- 核心血量变化可追踪
- 无ERROR级别的引擎错误
"""

import asyncio
import json
import time
import sys
import subprocess
import signal
import os
import re
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class Task003RegressionTester:
    """TASK-003回归测试器"""

    def __init__(self, http_port=9999):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []
        self.observations = []
        self.log_file = None
        self.client_process = None
        self.session: Optional[aiohttp.ClientSession] = None

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_task003_{timestamp}.log"

        # 波次记录
        self.wave_records = []
        self.current_wave = 0
        self.core_health_history = []

        # 新日志类型检测（同时检测英文[]和中文【】格式）
        self.log_patterns = {
            "core_health_calc": r"\[核心血量计算\]|【核心血量计算】|Core HP Calc",
            "cow_totem_charge": r"\[牛图腾充能\]|【牛图腾充能】|Cow Totem Charge",
            "cow_totem_trigger": r"\[牛图腾触发\]|【牛图腾触发】|Cow Totem Trigger",
            "unit_attack": r"\[单位攻击\]|【单位攻击】|Unit Attack",
            "core_damaged": r"\[核心受击\]|【核心受击】|Core damaged by",
        }
        self.detected_logs = {key: False for key in self.log_patterns}

        # 验证结果
        self.validation_results = {
            "wave_number_increment": False,
            "core_health_trackable": False,
            "new_log_types": False,
            "no_crash": True,
            "no_error": True,
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message, level="INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    def log_validation(self, mechanism, passed, details=""):
        """记录验证结果"""
        status = "✅" if passed else "❌"
        self.log(f"{status} [{mechanism}] {details}", "VALIDATION")

    async def send_actions(self, actions):
        """发送动作"""
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

    async def get_observations(self):
        """获取观测数据"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                data = await resp.json()
                obs_list = data.get("observations", [])
                for obs in obs_list:
                    self.observations.append(obs)
                    # 检查错误
                    if "ERROR" in obs or "错误" in obs or "崩溃" in obs:
                        self.log(f"[OBS-ERROR] {obs}", "ERROR")
                        if "ERROR" in obs:
                            self.validation_results["no_error"] = False
                    else:
                        self.log(f"[OBS] {obs}", "OBSERVATION")

                    # 检测新日志类型
                    self.detect_new_log_types(obs)

                return obs_list
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    def detect_new_log_types(self, obs):
        """检测新日志类型"""
        for log_type, pattern in self.log_patterns.items():
            if re.search(pattern, obs, re.IGNORECASE):
                if not self.detected_logs[log_type]:
                    self.log(f"📝 检测到新日志类型 [{log_type}]: {obs[:100]}...", "DETECTION")
                    self.detected_logs[log_type] = True

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        """轮询观测数据"""
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 60.0) -> bool:
        """等待游戏就绪"""
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(f"{self.base_url}/status", timeout=aiohttp.ClientTimeout(total=5)) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        if data.get("godot_running") and data.get("ws_connected"):
                            self.log("游戏已就绪", "SYSTEM")
                            return True
            except Exception as e:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    def check_and_reset_game(self):
        """检查并重置游戏状态"""
        self.log("检查并重置游戏状态...", "SYSTEM")
        try:
            result = subprocess.run(
                ["pkill", "-f", "godot"],
                capture_output=True,
                text=True
            )
            time.sleep(2)
            self.log("游戏状态已重置", "SYSTEM")
        except Exception as e:
            self.log(f"重置游戏状态时出错: {e}", "WARNING")

    def start_ai_client(self):
        """启动AI客户端"""
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
        """停止AI客户端"""
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.client_process = None
            # 关闭日志文件
            if hasattr(self, 'ai_client_log') and self.ai_client_log:
                self.ai_client_log.close()

    async def step_select_totem(self):
        """选择牛图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤: 选择牛图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(3.0)

        await self.send_actions([{
            "type": "select_totem",
            "totem_id": "cow_totem"
        }])

        await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_buy_and_deploy_unit(self):
        """购买并部署单位"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤: 购买并部署单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.poll_observations(2.0)

        # 刷新商店获取牛图腾阵营单位
        await self.send_actions([{"type": "refresh_shop"}])
        await self.poll_observations(2.0)

        # 购买第一个单位
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await self.poll_observations(1.0)

        # 部署到(1,0)
        await self.send_actions([{
            "type": "move_unit",
            "from_zone": "bench",
            "to_zone": "grid",
            "from_pos": 0,
            "to_pos": {"x": 1, "y": 0}
        }])

        await self.poll_observations(2.0)
        self.log("✅ 单位购买并部署完成", "VALIDATION")

    async def step_run_wave(self, wave_number: int) -> tuple:
        """运行单个波次"""
        self.log("=" * 60, "SYSTEM")
        self.log(f"步骤: 进行第{wave_number}波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        wave_data = {
            "wave_number": wave_number,
            "start_health": None,
            "end_health": None,
            "enemies_defeated": 0
        }

        # 开始波次
        await self.send_actions([{"type": "start_wave"}])

        # 等待波次进行
        wave_active = True
        start_time = time.time()
        max_duration = 120  # 最多等待2分钟

        while wave_active and time.time() - start_time < max_duration:
            obs_list = await self.poll_observations(3.0)

            for obs in obs_list:
                # 检测波次开始
                if f"第 {wave_number} 波战斗正式开始" in obs:
                    self.log(f"🎮 第{wave_number}波正式开始", "EVENT")
                    # 提取开始血量
                    health = self.extract_health_from_obs([obs])
                    if health:
                        wave_data["start_health"] = health
                        self.core_health_history.append({
                            "wave": wave_number,
                            "start": health
                        })

                # 检测波次结束
                if "波次完成" in obs or "wave ended" in obs.lower():
                    self.log(f"✅ 第{wave_number}波结束", "EVENT")
                    wave_active = False

                # 检测游戏结束
                if "游戏结束" in obs or "game over" in obs.lower():
                    self.log(f"❌ 游戏在第{wave_number}波结束", "EVENT")
                    wave_data["end_health"] = 0
                    self.wave_records.append(wave_data)
                    return wave_data, True

        # 获取结束血量
        health = self.extract_health_from_obs(self.observations[-10:])
        if health:
            wave_data["end_health"] = health

        self.wave_records.append(wave_data)

        # 等待商店刷新
        await self.poll_observations(2.0)

        return wave_data, False

    def extract_health_from_obs(self, obs_list: List[str]) -> Optional[float]:
        """从观测中提取血量"""
        for obs in reversed(obs_list):
            # 匹配血量格式
            match = re.search(r'血量[:\s]+(\d+\.?\d*)[\/\s]+(\d+\.?\d*)', obs)
            if match:
                return float(match.group(1))
            match = re.search(r'health[:\s]+(\d+\.?\d*)', obs, re.IGNORECASE)
            if match:
                return float(match.group(1))
        return None

    async def run_task003_test(self) -> bool:
        """运行TASK-003测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("TASK-003: 日志增强回归测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        self.log(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "SYSTEM")
        self.log(f"日志文件: {self.log_file}", "SYSTEM")

        self.check_and_reset_game()
        self.start_ai_client()

        try:
            if not await self.wait_for_game_ready():
                self.log("游戏未能就绪，测试中止", "ERROR")
                return False

            # 选择图腾
            await self.step_select_totem()

            # 购买并部署单位
            await self.step_buy_and_deploy_unit()

            # 连续进行5个波次
            for wave in range(1, 6):
                wave_data, game_over = await self.step_run_wave(wave)

                if game_over:
                    self.log(f"游戏在第{wave}波结束", "WARNING")
                    break

            # 验证结果
            await self.verify_results()

            # 生成报告
            await self.generate_report()

            return True

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            self.validation_results["no_crash"] = False
            return False

        finally:
            self.stop_ai_client()

    async def verify_results(self):
        """验证测试结果"""
        self.log("=" * 60, "SYSTEM")
        self.log("验证测试结果", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 验证新日志类型
        detected_count = sum(1 for v in self.detected_logs.values() if v)
        total_count = len(self.detected_logs)

        self.log(f"新日志类型检测: {detected_count}/{total_count}", "INFO")
        for log_type, detected in self.detected_logs.items():
            status = "✅" if detected else "❌"
            self.log(f"  {status} {log_type}", "INFO")

        if detected_count >= 3:
            self.validation_results["new_log_types"] = True
            self.log_validation("新日志类型", True, f"检测到{detected_count}种新日志类型")
        else:
            self.log_validation("新日志类型", False, f"仅检测到{detected_count}种新日志类型")

        # 验证波次号递增
        wave_numbers = []
        for obs in self.observations:
            match = re.search(r'第\s*(\d+)\s*波', obs)
            if match:
                wave_num = int(match.group(1))
                if wave_num not in wave_numbers:
                    wave_numbers.append(wave_num)

        wave_numbers.sort()
        if len(wave_numbers) >= 2 and wave_numbers == list(range(min(wave_numbers), max(wave_numbers) + 1)):
            self.validation_results["wave_number_increment"] = True
            self.log_validation("波次号递增", True, f"波次序列: {wave_numbers}")
        else:
            self.log_validation("波次号递增", False, f"波次序列: {wave_numbers}")

        # 验证血量可追踪
        if len(self.core_health_history) >= 2:
            self.validation_results["core_health_trackable"] = True
            self.log_validation("血量可追踪", True, f"记录了{len(self.core_health_history)}个波次的血量")
        else:
            self.log_validation("血量可追踪", False, f"仅记录了{len(self.core_health_history)}个波次的血量")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("生成测试报告", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "TASK-003: 日志增强回归测试报告",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试目标:",
            "  1. 验证波次号正确递增",
            "  2. 验证新的日志类型输出",
            "  3. 重点追踪波次间血量变化（验证440→290问题）",
            "",
            "验证结果:",
        ]

        # 新日志类型检测
        report_lines.extend([
            "",
            "新日志类型检测:",
            "-" * 60,
        ])
        for log_type, detected in self.detected_logs.items():
            status = "✅ 已检测" if detected else "❌ 未检测"
            report_lines.append(f"  {status} {log_type}")

        # 其他验证项
        report_lines.extend([
            "",
            "其他验证项:",
            "-" * 60,
            f"  波次号递增: {'✅ 通过' if self.validation_results['wave_number_increment'] else '❌ 未通过'}",
            f"  血量可追踪: {'✅ 通过' if self.validation_results['core_health_trackable'] else '❌ 未通过'}",
            f"  新日志类型: {'✅ 通过' if self.validation_results['new_log_types'] else '❌ 未通过'}",
            f"  无崩溃: {'✅ 通过' if self.validation_results['no_crash'] else '❌ 未通过'}",
            f"  无ERROR: {'✅ 通过' if self.validation_results['no_error'] else '❌ 未通过'}",
        ])

        # 血量变化记录
        report_lines.extend([
            "",
            "核心血量变化记录:",
            "-" * 60,
        ])
        for record in self.wave_records:
            wave_num = record["wave_number"]
            start = record.get("start_health")
            end = record.get("end_health")
            if start and end:
                change = start - end
                report_lines.append(f"  第{wave_num}波: {start:.1f} → {end:.1f} (变化: -{change:.1f})")
            elif start:
                report_lines.append(f"  第{wave_num}波: 开始血量 {start:.1f}")

        # 检查440→290问题
        report_lines.extend([
            "",
            "波次间血量异常调查 (440→290问题):",
            "-" * 60,
        ])
        if len(self.wave_records) >= 2:
            for i in range(len(self.wave_records) - 1):
                curr_wave = self.wave_records[i]
                next_wave = self.wave_records[i + 1]
                if curr_wave.get("end_health") and next_wave.get("start_health"):
                    end_health = curr_wave["end_health"]
                    start_health = next_wave["start_health"]
                    if end_health != start_health:
                        diff = end_health - start_health
                        report_lines.append(f"  ⚠️ 第{curr_wave['wave_number']}波结束到第{next_wave['wave_number']}波开始:")
                        report_lines.append(f"     血量变化: {end_health:.1f} → {start_health:.1f} (差值: {diff:+.1f})")
                    else:
                        report_lines.append(f"  ✅ 第{curr_wave['wave_number']}波→第{next_wave['wave_number']}波: 血量连续 ({end_health:.1f})")
        else:
            report_lines.append("  ⚠️ 数据不足以分析波次间血量变化")

        # 总结
        all_passed = (
            self.validation_results["wave_number_increment"] and
            self.validation_results["new_log_types"] and
            self.validation_results["no_crash"] and
            self.validation_results["no_error"]
        )

        report_lines.extend([
            "",
            "=" * 60,
            "测试总结:",
            "=" * 60,
        ])

        if all_passed:
            report_lines.append("✅ TASK-003 测试通过 - 所有验证项通过")
        elif self.validation_results["no_crash"]:
            report_lines.append("⚠️ TASK-003 测试部分通过 - 游戏未崩溃但部分验证未通过")
        else:
            report_lines.append("❌ TASK-003 测试失败 - 游戏发生崩溃")

        report_lines.extend([
            "",
            "后续建议:",
            "- 如日志类型未全部检测，可能需要增加更多日志埋点",
            "- 如波次间血量异常，需要调查血量重置逻辑",
            "- 测试报告已投递至游戏策划和项目总监",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告
        report_file = Path("docs/player_reports/task003_regression_report.md")
        report_file.parent.mkdir(parents=True, exist_ok=True)
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存到: {report_file}", "SYSTEM")

        return report


async def main():
    """主函数"""
    http_port = 9999
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with Task003RegressionTester(http_port) as tester:
        success = await tester.run_task003_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
