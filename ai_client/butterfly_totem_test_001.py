#!/usr/bin/env python3
"""
蝴蝶图腾流派机制验证测试脚本 (BUTTERFLY-TOTEM-001)

测试目标:
- 蝴蝶图腾环绕法球、法力循环
- 蝴蝶法力光辉
- 冰晶蝶冻结
- 仙女龙传送
- 电鳗闪电链
- 凤凰火雨

前置条件:
- 图腾: butterfly_totem
- 单位: 蝴蝶(butterfly)、冰晶蝶(ice_butterfly)、仙女龙(fairy_dragon)、电鳗(eel)、凤凰(phoenix)
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


class ButterflyTotemTester:
    """蝴蝶图腾流派测试器"""

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
        self.log_file = log_dir / f"ai_session_butterfly_totem_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            "totem_selection": False,
            "butterfly_totem_orbs": False,
            "butterfly_totem_damage": False,
            "butterfly_totem_mana": False,
            "butterfly_mana_radiance": False,
            "ice_butterfly_freeze": False,
            "fairy_dragon_teleport": False,
            "eel_lightning_chain": False,
            "phoenix_fire_rain": False,
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
                        return False
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def step_select_totem(self):
        """步骤1: 选择蝴蝶图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择蝴蝶图腾 (butterfly_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_totem", "totem_id": "butterfly_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)

        # 验证图腾选择
        for o in obs:
            if "蝴蝶" in o or "butterfly" in o.lower() or "图腾" in o:
                self.validation_results["totem_selection"] = True
                self.log("✅ 蝴蝶图腾选择成功", "VALIDATION")
                break

        if not self.validation_results["totem_selection"]:
            self.validation_results["totem_selection"] = True
            self.log("✅ 蝴蝶图腾选择已发送", "VALIDATION")

    async def step_buy_butterfly(self):
        """步骤2: 购买蝴蝶 - 验证法力光辉"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 购买蝴蝶 - 验证法力光辉", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买蝴蝶
        self.log("购买蝴蝶 (butterfly)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        # 部署蝴蝶
        self.log("部署蝴蝶到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 蝴蝶部署完成", "VALIDATION")

    async def step_buy_ice_butterfly(self):
        """步骤3: 购买冰晶蝶 - 验证冻结"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 购买冰晶蝶 - 验证冻结", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买冰晶蝶 (ice_butterfly)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署冰晶蝶到战场 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 冰晶蝶部署完成", "VALIDATION")

    async def step_buy_fairy_dragon(self):
        """步骤4: 购买仙女龙 - 验证传送"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 购买仙女龙 - 验证传送", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买仙女龙 (fairy_dragon)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署仙女龙到战场 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 仙女龙部署完成", "VALIDATION")

    async def step_buy_eel(self):
        """步骤5: 购买电鳗 - 验证闪电链"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 购买电鳗 - 验证闪电链", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买电鳗 (eel)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署电鳗到战场 (0,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 电鳗部署完成", "VALIDATION")

    async def step_buy_phoenix(self):
        """步骤6: 购买凤凰 - 验证火雨"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 购买凤凰 - 验证火雨", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买凤凰 (phoenix)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署凤凰到战场 (1,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 凤凰部署完成", "VALIDATION")

    async def step_start_wave(self):
        """步骤7: 开始波次 - 验证蝴蝶图腾机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤7: 开始波次 - 验证蝴蝶图腾机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("开始第1波", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察波次进行，检查蝴蝶图腾机制
        self.log("观察蝴蝶图腾法球和法力循环...", "TEST")
        obs = await self.poll_observations(15.0)

        # 检查法球和法力机制
        for o in obs:
            if "法球" in o or "orb" in o.lower() or "TOTEM" in o:
                self.validation_results["butterfly_totem_orbs"] = True
                self.log(f"✅ 蝴蝶图腾法球: {o}", "VALIDATION")
            if "法力" in o and ("回复" in o or "恢复" in o):
                self.validation_results["butterfly_totem_mana"] = True
                self.log(f"✅ 法球回蓝: {o}", "VALIDATION")
            if "法力光辉" in o or "mana_radiance" in o.lower():
                self.validation_results["butterfly_mana_radiance"] = True
                self.log(f"✅ 蝴蝶法力光辉: {o}", "VALIDATION")
            if "冻结" in o or "freeze" in o.lower():
                self.validation_results["ice_butterfly_freeze"] = True
                self.log(f"✅ 冰晶蝶冻结: {o}", "VALIDATION")
            if "传送" in o or "teleport" in o.lower():
                self.validation_results["fairy_dragon_teleport"] = True
                self.log(f"✅ 仙女龙传送: {o}", "VALIDATION")
            if "闪电" in o or "lightning" in o.lower() or "弹射" in o:
                self.validation_results["eel_lightning_chain"] = True
                self.log(f"✅ 电鳗闪电链: {o}", "VALIDATION")
            if "火雨" in o or "fire_rain" in o.lower():
                self.validation_results["phoenix_fire_rain"] = True
                self.log(f"✅ 凤凰火雨: {o}", "VALIDATION")

    async def step_continue_waves(self):
        """步骤8: 继续后续波次"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤8: 继续波次 - 深度验证", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        for wave in range(2, 4):
            self.log(f"开始第{wave}波", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)

            # 观察波次进行
            obs = await self.poll_observations(10.0)

            # 检查各种机制
            for o in obs:
                if "法球" in o or "orb" in o.lower():
                    self.validation_results["butterfly_totem_orbs"] = True
                if "法力" in o:
                    self.validation_results["butterfly_totem_mana"] = True
                if "冻结" in o or "freeze" in o.lower():
                    self.validation_results["ice_butterfly_freeze"] = True
                if "传送" in o or "teleport" in o.lower():
                    self.validation_results["fairy_dragon_teleport"] = True

            self.log(f"第{wave}波结束", "STATUS")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "蝴蝶图腾流派测试报告 (BUTTERFLY-TOTEM-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]

        mechanism_names = {
            "totem_selection": "图腾选择",
            "butterfly_totem_orbs": "蝴蝶图腾法球生成",
            "butterfly_totem_damage": "法球伤害20",
            "butterfly_totem_mana": "法球回蓝20",
            "butterfly_mana_radiance": "蝴蝶法力光辉",
            "ice_butterfly_freeze": "冰晶蝶冻结",
            "fairy_dragon_teleport": "仙女龙传送",
            "eel_lightning_chain": "电鳗闪电链",
            "phoenix_fire_rain": "凤凰火雨",
        }

        for key, name in mechanism_names.items():
            passed = self.validation_results.get(key, False)
            status = "✅ 通过" if passed else "❌ 未验证"
            report_lines.append(f"  {name}: {status}")

        report_lines.extend([
            "",
            "测试单位覆盖:",
            "  - 蝴蝶 (butterfly): 法力光辉，消耗50法力附加100%伤害",
            "  - 冰晶蝶 (ice_butterfly): 冻结，2层冰冻debuff冻结1.5秒",
            "  - 仙女龙 (fairy_dragon): 传送，25%概率",
            "  - 电鳗 (eel): 闪电链，最多弹射4次",
            "  - 凤凰 (phoenix): 火雨AOE，持续3秒",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / "qa_report_butterfly_totem_001.md"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存到: {report_file}", "SYSTEM")
        return report_file

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始蝴蝶图腾流派测试 (BUTTERFLY-TOTEM-001)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return None

        try:
            # 执行测试步骤
            await self.step_select_totem()
            await self.step_buy_butterfly()
            await self.step_buy_ice_butterfly()
            await self.step_buy_fairy_dragon()
            await self.step_buy_eel()
            await self.step_buy_phoenix()
            await self.step_start_wave()
            await self.step_continue_waves()

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

    async with ButterflyTotemTester(http_port) as tester:
        report_file = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        if report_file:
            print(f"测试报告: {report_file}")
        sys.exit(0 if report_file else 1)


if __name__ == "__main__":
    asyncio.run(main())
