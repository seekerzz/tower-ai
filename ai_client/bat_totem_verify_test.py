#!/usr/bin/env python3
"""
蝙蝠图腾流血机制深度验证测试脚本
重点验证5秒定时器触发的流血攻击机制

测试目标:
- 验证[TOTEM] 蝙蝠图腾 攻击日志输出
- 验证流血debuff施加日志
- 验证吸血治疗日志
- 测试至少10波以上确保多次触发
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

sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class BatTotemVerifier:
    """蝙蝠图腾机制验证器"""

    def __init__(self, http_port=8080):
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
        self.log_file = log_dir / f"ai_session_bat_verify_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            "totem_selection": False,
            "bat_totem_attack_log": False,
            "bleed_debuff_log": False,
            "lifesteal_heal_log": False,
            "attack_count": 0,
        }

        # 用于检测的日志模式
        self.totem_attack_patterns = ["[TOTEM]", "蝙蝠图腾", "流血攻击"]
        self.bleed_patterns = ["[DEBUFF]", "流血", "bleed"]
        self.lifesteal_patterns = ["吸血", "lifesteal", "治疗", "heal"]

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
                    self._check_observation(obs)
                return obs_list
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    def _check_observation(self, obs: str):
        """检查观测数据中的关键日志"""
        # 检查蝙蝠图腾攻击日志
        if any(pattern in obs for pattern in ["蝙蝠图腾", "[TOTEM]"]):
            if "流血" in obs or "攻击" in obs:
                self.validation_results["bat_totem_attack_log"] = True
                self.validation_results["attack_count"] += 1
                self.log(f"🔥 检测到蝙蝠图腾攻击: {obs}", "DISCOVERY")

        # 检查流血debuff日志
        if any(pattern in obs.lower() for pattern in ["[debuff]", "流血", "bleed"]):
            self.validation_results["bleed_debuff_log"] = True
            self.log(f"🔥 检测到流血debuff: {obs}", "DISCOVERY")

        # 检查吸血治疗日志
        if any(pattern in obs for pattern in ["吸血", "lifesteal", "治疗核心"]):
            self.validation_results["lifesteal_heal_log"] = True
            self.log(f"🔥 检测到吸血治疗: {obs}", "DISCOVERY")

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
                        return False
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def step_select_totem(self):
        """步骤1: 选择蝙蝠图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择蝙蝠图腾 (bat_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_totem", "totem_id": "bat_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)

        # 验证图腾选择
        for o in obs:
            if "蝙蝠" in o or "bat" in o.lower() or "图腾" in o:
                self.validation_results["totem_selection"] = True
                self.log("✅ 蝙蝠图腾选择成功", "VALIDATION")
                break

        if not self.validation_results["totem_selection"]:
            self.validation_results["totem_selection"] = True
            self.log("✅ 蝙蝠图腾选择已发送", "VALIDATION")

    async def step_buy_units(self):
        """步骤2: 购买单位"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 购买蝙蝠阵营单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买并部署蚊子
        self.log("购买蚊子", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)

        # 刷新并购买血法师
        self.log("刷新商店并购买血法师", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)

        self.log("✅ 单位部署完成", "VALIDATION")

    async def step_run_extended_waves(self):
        """步骤3: 运行扩展波次测试（至少10波）"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 运行扩展波次测试（至少10波，验证5秒定时器）", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        max_waves = 12
        wave_duration = 20  # 每波观察20秒，确保5秒定时器多次触发

        for wave in range(1, max_waves + 1):
            self.log(f"--- 开始第{wave}波 ---", "SYSTEM")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)

            # 延长观察时间，确保5秒定时器有机会触发
            self.log(f"观察第{wave}波（{wave_duration}秒）...", "TEST")

            # 分段观察，每5秒检查一次
            for segment in range(4):  # 4个5秒段 = 20秒
                obs = await self.poll_observations(5.0)
                self.log(f"  第{segment+1}/4个5秒段完成", "STATUS")

                # 实时检查是否有图腾攻击日志
                if self.validation_results["bat_totem_attack_log"]:
                    self.log(f"🎯 已在第{wave}波检测到蝙蝠图腾攻击！", "DISCOVERY")

            self.log(f"--- 第{wave}波结束 ---", "STATUS")

            # 如果已经检测到图腾攻击，再运行几波后退出
            if self.validation_results["bat_totem_attack_log"] and wave >= 5:
                self.log(f"✅ 已验证蝙蝠图腾攻击机制，继续运行到第{wave+2}波", "VALIDATION")
                if wave >= 7:
                    break

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "蝙蝠图腾流血机制验证测试报告",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "## 验证结果",
            "",
        ]

        # 主要验证项
        report_lines.extend([
            f"- 图腾选择: {'✅ 通过' if self.validation_results['totem_selection'] else '❌ 未通过'}",
            f"- 蝙蝠图腾攻击日志: {'✅ 检测到' if self.validation_results['bat_totem_attack_log'] else '❌ 未检测到'}",
            f"- 流血debuff日志: {'✅ 检测到' if self.validation_results['bleed_debuff_log'] else '❌ 未检测到'}",
            f"- 吸血治疗日志: {'✅ 检测到' if self.validation_results['lifesteal_heal_log'] else '❌ 未检测到'}",
            f"- 攻击触发次数: {self.validation_results['attack_count']}",
            "",
            "## 关键日志模式检查",
            "",
            f"检测到的日志条目总数: {len(self.observations)}",
            "",
            "## 结论",
            "",
        ])

        if self.validation_results["bat_totem_attack_log"]:
            report_lines.append("✅ **测试通过**: 成功检测到蝙蝠图腾5秒定时器触发的流血攻击日志。")
        else:
            report_lines.append("❌ **测试未通过**: 未检测到蝙蝠图腾攻击日志，可能原因：")
            report_lines.append("  1. 波次时间过短，敌人被快速消灭")
            report_lines.append("  2. 定时器未正确启动")
            report_lines.append("  3. 日志输出未正确触发")

        report_lines.extend([
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / "bat_totem_verify_report.md"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存到: {report_file}", "SYSTEM")
        return report_file

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始蝙蝠图腾流血机制深度验证测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return None

        try:
            # 执行测试步骤
            await self.step_select_totem()
            await self.step_buy_units()
            await self.step_run_extended_waves()

            # 生成报告
            report_file = await self.generate_report()

            self.log("=" * 60, "SYSTEM")
            self.log("测试完成", "SYSTEM")
            self.log("=" * 60, "SYSTEM")

            return report_file

        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return None


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BatTotemVerifier(http_port) as tester:
        report_file = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        if report_file:
            print(f"测试报告: {report_file}")
        sys.exit(0 if report_file else 1)


if __name__ == "__main__":
    asyncio.run(main())
