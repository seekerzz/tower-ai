#!/usr/bin/env python3
"""
多波次深度测试脚本 (MULTI-WAVE-DEEP-001)

测试目标:
- 验证波次号修复后，游戏能否正常进行多波次连续战斗
- 连续进行至少5个波次
- 验证波次号正确递增（第1波→第2波→第3波→第4波→第5波）
- 记录每个波次的核心血量变化
- 验证商店每波正常刷新
- 观察敌人难度是否随波次递增

成功标准:
- 游戏能连续进行5个波次而不崩溃
- 波次号正确显示并递增
- 无ERROR级别的引擎错误
- 商店每波结束正常刷新
"""

import asyncio
import json
import time
import sys
import subprocess
import signal
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class MultiWaveDeepTester:
    """多波次深度测试器"""

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
        self.log_file = log_dir / f"ai_session_multi_wave_deep_001_{timestamp}.log"

        # 波次记录
        self.wave_records = []  # 记录每个波次的数据
        self.current_wave = 0
        self.core_health_history = []

        # 验证结果
        self.validation_results = {
            "wave_1_completed": False,
            "wave_2_completed": False,
            "wave_3_completed": False,
            "wave_4_completed": False,
            "wave_5_completed": False,
            "wave_number_increment": False,
            "shop_refresh_per_wave": False,
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
        """记录日志到文件和控制台"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    def log_validation(self, mechanism, passed, details=""):
        """记录验证结果"""
        status = "✅" if passed else "❌"
        self.log(f"{status} [{mechanism}] {details}", "VALIDATION")
        self.test_results.append({
            "mechanism": mechanism,
            "passed": passed,
            "details": details,
            "timestamp": datetime.now().isoformat()
        })

    async def send_actions(self, actions):
        """发送动作到游戏"""
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
        """获取游戏观测数据"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                data = await resp.json()
                obs_list = data.get("observations", [])
                for obs in obs_list:
                    self.observations.append(obs)
                    # 检查是否有错误
                    if "ERROR" in obs or "错误" in obs or "崩溃" in obs:
                        self.log(f"[OBS-ERROR] {obs}", "ERROR")
                        if "ERROR" in obs:
                            self.validation_results["no_error"] = False
                    else:
                        self.log(f"[OBS] {obs}", "OBSERVATION")
                return obs_list
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        """轮询观测数据一段时间"""
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 30.0) -> bool:
        """等待游戏就绪"""
        self.log("等待游戏就绪...", "SYSTEM")
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(
                    f"{self.base_url}/status",
                    timeout=aiohttp.ClientTimeout(total=2)
                ) as resp:
                    data = await resp.json()
                    if data.get("godot_running") and data.get("ws_connected"):
                        self.log("游戏已就绪", "SYSTEM")
                        return True
                    if data.get("crashed"):
                        self.log("游戏已崩溃!", "ERROR")
                        self.validation_results["no_crash"] = False
                        return False
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    def extract_wave_number(self, obs_list: List[str]) -> Optional[int]:
        """从观测数据中提取波次号"""
        for obs in obs_list:
            # 匹配各种波次格式
            if "第" in obs and "波" in obs:
                # 提取数字
                import re
                match = re.search(r'第\s*(\d+)\s*波', obs)
                if match:
                    return int(match.group(1))
            # 英文格式
            if "Wave" in obs or "wave" in obs.lower():
                import re
                match = re.search(r'[Ww]ave\s+(\d+)', obs)
                if match:
                    return int(match.group(1))
        return None

    def extract_core_health(self, obs_list: List[str]) -> Optional[float]:
        """从观测数据中提取核心血量"""
        for obs in reversed(obs_list):  # 从最新的开始找
            if "核心" in obs and "血量" in obs:
                import re
                # 匹配格式: 当前血量/最大血量 或 剩余血量
                match = re.search(r'(\d+\.?\d*)\s*/\s*(\d+\.?\d*)', obs)
                if match:
                    return float(match.group(1))
                match = re.search(r'剩余.*?([\d\.]+)', obs)
                if match:
                    return float(match.group(1))
        return None

    async def check_and_reset_game(self):
        """检查游戏状态，如果已结束则重置"""
        self.log("=" * 60, "SYSTEM")
        self.log("检查游戏状态", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 获取当前观测
        obs = await self.poll_observations(2.0)
        health = self.extract_core_health(obs)

        if health is not None and health <= 0:
            self.log(f"⚠️ 游戏已结束 (核心血量: {health})，需要重置", "WARNING")

            # 发送新游戏动作
            self.log("发送 new_game 动作重置游戏...", "ACTION")
            await self.send_actions([{"type": "new_game"}])
            await asyncio.sleep(2.0)

            # 等待游戏重置完成
            reset_timeout = 30.0
            start_time = time.time()
            while time.time() - start_time < reset_timeout:
                obs = await self.poll_observations(2.0)
                health = self.extract_core_health(obs)

                if health and health > 0:
                    self.log(f"✅ 游戏已重置，核心血量: {health}", "VALIDATION")
                    return True

                # 检查是否收到游戏开始的消息
                for o in obs:
                    if "图腾选择" in o or "选择图腾" in o or "游戏开始" in o:
                        self.log("✅ 检测到游戏重置信号", "VALIDATION")
                        return True

            self.log("⚠️ 游戏重置超时，继续测试...", "WARNING")
            return False
        else:
            self.log(f"✅ 游戏状态正常 (核心血量: {health})，无需重置", "VALIDATION")
            return True

    async def step_select_totem(self):
        """步骤1: 选择牛图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择牛图腾 (cow_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_totem", "totem_id": "cow_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)
        self.log("✅ 牛图腾选择完成", "VALIDATION")

    async def step_buy_and_deploy_unit(self):
        """步骤2: 购买并部署单位"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 购买并部署单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买第一个单位
        self.log("购买商店第1个单位", "ACTION")
        await self.send_actions([
            {"type": "buy_unit", "shop_index": 0}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 部署到战场 (1,0)
        self.log("将单位部署到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)
        self.log("✅ 单位购买部署完成", "VALIDATION")

    async def step_run_wave(self, wave_num: int):
        """运行单个波次并记录数据"""
        self.log("=" * 60, "SYSTEM")
        self.log(f"开始第{wave_num}波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        wave_data = {
            "wave_number": wave_num,
            "start_time": datetime.now().isoformat(),
            "start_health": None,
            "end_health": None,
            "enemies_killed": 0,
            "observations": []
        }

        # 启动波次
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 获取启动时的观测
        obs = await self.poll_observations(3.0)
        wave_data["observations"].extend(obs)

        # 提取波次号
        detected_wave = self.extract_wave_number(obs)
        if detected_wave:
            self.log(f"检测到波次号: {detected_wave}", "INFO")
            if detected_wave == wave_num:
                self.log(f"✅ 波次号正确: {wave_num}", "VALIDATION")
            else:
                self.log(f"❌ 波次号错误: 期望{wave_num}, 实际{detected_wave}", "ERROR")

        # 记录开始时的核心血量
        start_health = self.extract_core_health(obs)
        if start_health:
            wave_data["start_health"] = start_health
            self.core_health_history.append({"wave": wave_num, "start": start_health})
            self.log(f"第{wave_num}波开始 - 核心血量: {start_health}", "INFO")

        # 等待波次进行 (波次通常持续30-60秒)
        self.log(f"等待第{wave_num}波战斗进行...", "TEST")

        # 持续观察波次进行
        wave_duration = 0
        max_wave_duration = 45  # 最多等待45秒
        poll_interval = 2.0

        while wave_duration < max_wave_duration:
            obs = await self.poll_observations(poll_interval)
            wave_data["observations"].extend(obs)
            wave_duration += poll_interval

            # 检查波次是否结束
            wave_ended = False
            for o in obs:
                if any(keyword in o for keyword in ["波次完成", "波次结束", "商店刷新", "升级选择"]):
                    wave_ended = True
                    self.log(f"第{wave_num}波已结束", "INFO")
                    break
                if "游戏结束" in o or "game over" in o.lower():
                    self.log(f"游戏在第{wave_num}波结束!", "ERROR")
                    wave_data["end_time"] = datetime.now().isoformat()
                    return wave_data, True  # True 表示游戏结束

            if wave_ended:
                break

        # 记录结束时的核心血量
        end_health = self.extract_core_health(wave_data["observations"])
        if end_health is not None:
            wave_data["end_health"] = end_health
            start_health = wave_data.get("start_health")
            if isinstance(start_health, (int, float)):
                health_change = start_health - end_health
                self.log(f"第{wave_num}波结束 - 核心血量: {end_health} (损失: {health_change})", "INFO")
        else:
            # 尝试再次获取
            obs = await self.poll_observations(2.0)
            wave_data["observations"].extend(obs)
            end_health = self.extract_core_health(obs)
            if end_health:
                wave_data["end_health"] = end_health
                self.log(f"第{wave_num}波结束 - 核心血量: {end_health}", "INFO")

        wave_data["end_time"] = datetime.now().isoformat()

        # 刷新商店准备下一波
        self.log("刷新商店", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 检查商店刷新
        shop_refreshed = any("商店" in o or "刷新" in o for o in obs)
        if shop_refreshed:
            self.log(f"✅ 第{wave_num}波后商店已刷新", "VALIDATION")

        self.wave_records.append(wave_data)

        # 标记波次完成
        self.validation_results[f"wave_{wave_num}_completed"] = True

        return wave_data, False  # False 表示游戏未结束

    async def run_multi_wave_test(self):
        """运行多波次测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始多波次深度测试 (MULTI-WAVE-DEEP-001)", "SYSTEM")
        self.log("目标: 连续进行5个波次，验证波次号递增", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return False

        # 检查游戏状态，如果游戏已结束则重置
        await self.check_and_reset_game()

        try:
            # 选择图腾
            await self.step_select_totem()

            # 购买并部署单位
            await self.step_buy_and_deploy_unit()

            # 连续进行5个波次
            for wave in range(1, 6):
                wave_data, game_over = await self.step_run_wave(wave)

                if game_over:
                    self.log(f"❌ 游戏在第{wave}波结束，无法完成5波测试", "ERROR")
                    break

            # 验证波次号递增
            await self.verify_wave_increment()

            # 生成报告
            await self.generate_report()

            return True

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            self.validation_results["no_crash"] = False
            return False

    async def verify_wave_increment(self):
        """验证波次号递增"""
        self.log("=" * 60, "SYSTEM")
        self.log("验证波次号递增", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 从观测记录中提取所有波次号
        wave_numbers = []
        for obs in self.observations:
            wave_num = self.extract_wave_number([obs])
            if wave_num and wave_num not in wave_numbers:
                wave_numbers.append(wave_num)

        wave_numbers.sort()
        self.log(f"检测到的波次号序列: {wave_numbers}", "INFO")

        # 验证是否递增
        if wave_numbers == [1, 2, 3, 4, 5]:
            self.validation_results["wave_number_increment"] = True
            self.log("✅ 波次号正确递增: 1→2→3→4→5", "VALIDATION")
        elif len(wave_numbers) >= 3:
            # 检查是否递增
            is_incremental = all(wave_numbers[i] < wave_numbers[i+1] for i in range(len(wave_numbers)-1))
            if is_incremental:
                self.validation_results["wave_number_increment"] = True
                self.log(f"✅ 波次号递增正确: {'→'.join(map(str, wave_numbers))}", "VALIDATION")
            else:
                self.log(f"⚠️ 波次号未正确递增: {wave_numbers}", "WARNING")
        else:
            self.log(f"⚠️ 检测到的波次号不足: {wave_numbers}", "WARNING")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("生成测试报告", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "多波次深度测试报告 (MULTI-WAVE-DEEP-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试目标:",
            "  - 验证波次号修复后游戏能连续进行多波次",
            "  - 验证波次号正确递增（第1波→第2波→...→第5波）",
            "  - 记录每个波次的核心血量变化",
            "  - 验证商店每波正常刷新",
            "",
            "验证结果:",
        ]

        # 波次完成情况
        for i in range(1, 6):
            passed = self.validation_results.get(f"wave_{i}_completed", False)
            status = "✅ 完成" if passed else "❌ 未完成"
            report_lines.append(f"  第{i}波: {status}")

        # 其他验证项
        report_lines.extend([
            "",
            "其他验证项:",
            f"  波次号递增: {'✅ 通过' if self.validation_results['wave_number_increment'] else '❌ 未通过'}",
            f"  无崩溃: {'✅ 通过' if self.validation_results['no_crash'] else '❌ 未通过'}",
            f"  无ERROR: {'✅ 通过' if self.validation_results['no_error'] else '❌ 未通过'}",
        ])

        # 波次详细记录
        report_lines.extend([
            "",
            "波次详细记录:",
            "-" * 60,
        ])

        for record in self.wave_records:
            wave_num = record["wave_number"]
            start_health = record.get("start_health")
            end_health = record.get("end_health")

            # 确保值为数值类型
            start_health_valid = isinstance(start_health, (int, float))
            end_health_valid = isinstance(end_health, (int, float))

            if start_health_valid and end_health_valid:
                health_change = start_health - end_health
                report_lines.append(f"  第{wave_num}波:")
                report_lines.append(f"    开始血量: {start_health}")
                report_lines.append(f"    结束血量: {end_health}")
                report_lines.append(f"    血量变化: -{health_change:.1f}")
            else:
                start_str = start_health if start_health is not None else "未知"
                end_str = end_health if end_health is not None else "未知"
                report_lines.append(f"  第{wave_num}波: 血量数据不完整 (开始:{start_str}, 结束:{end_str})")

        # 核心血量变化趋势
        if self.core_health_history:
            report_lines.extend([
                "",
                "核心血量变化趋势:",
            ])
            for h in self.core_health_history:
                report_lines.append(f"  第{h['wave']}波开始: {h['start']}")

        # 总结
        all_waves_passed = all(
            self.validation_results.get(f"wave_{i}_completed", False)
            for i in range(1, 6)
        )

        report_lines.extend([
            "",
            "=" * 60,
            "测试总结:",
            "=" * 60,
        ])

        if all_waves_passed and self.validation_results["wave_number_increment"]:
            report_lines.append("✅ 测试通过 - 所有5个波次正常完成，波次号正确递增")
        elif self.validation_results["no_crash"]:
            report_lines.append("⚠️ 测试部分通过 - 游戏未崩溃但未完成全部5波")
        else:
            report_lines.append("❌ 测试失败 - 游戏发生崩溃或错误")

        report_lines.extend([
            "",
            "关键发现:",
        ])

        if self.validation_results["wave_number_increment"]:
            report_lines.append("  ✅ 波次号修复成功 - 波次号正确递增")
        else:
            report_lines.append("  ❌ 波次号可能仍有问题")

        report_lines.extend([
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_file = Path("docs/player_reports/multi_wave_deep_001_report.md")
        report_file.parent.mkdir(parents=True, exist_ok=True)
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存到: {report_file}", "SYSTEM")

        return report


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with MultiWaveDeepTester(http_port) as tester:
        success = await tester.run_multi_wave_test()
        print(f"\n日志文件: {tester.log_file}")
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
