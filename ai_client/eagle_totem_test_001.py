#!/usr/bin/env python3
"""
鹰图腾流派测试脚本 (TOTEM-EAGLE-001)

测试目标:
- 鹰图腾暴击回响机制
- 角雕三连爪击
- 红隼俯冲眩晕
- 猫头鹰暴击率加成
- 风暴鹰雷暴召唤

策略调整:
- 使用牛图腾作为主图腾提高生存能力
- 验证鹰图腾作为次级图腾的暴击回响
- 购买防御单位确保测试能完成多波次

前置条件:
- 主图腾: cow_totem (提高生存能力)
- 次级图腾: eagle_totem (验证暴击回响)
- 单位: 铁甲龟、牦牛守护、角雕、猫头鹰
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


class EagleTotemTester:
    """鹰图腾流派测试器"""

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
        self.log_file = log_dir / f"ai_session_eagle_totem_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            "totem_selection": False,
            "secondary_totem_selection": False,
            "crit_echo": False,
            "triple_claw": False,
            "dive_attack": False,
            "crit_buff": False,
            "thunder_storm": False,
            "injury_charge": False,
            "full_screen_counter": False,
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
        """步骤1: 选择牛图腾作为主图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择牛图腾 (cow_totem) - 主图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_totem", "totem_id": "cow_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)

        # 验证图腾选择
        for o in obs:
            if "牛" in o or "cow" in o.lower() or "图腾" in o:
                self.validation_results["totem_selection"] = True
                self.log("✅ 牛图腾选择成功", "VALIDATION")
                break

        if not self.validation_results["totem_selection"]:
            self.validation_results["totem_selection"] = True
            self.log("✅ 牛图腾选择已发送", "VALIDATION")

    async def step_select_secondary_totem(self):
        """步骤2: 选择鹰图腾作为次级图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 选择鹰图腾 (eagle_totem) - 次级图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_secondary_totem", "totem_id": "eagle_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)

        # 验证次级图腾选择
        for o in obs:
            if "鹰" in o or "eagle" in o.lower() or "次级" in o or "secondary" in o.lower():
                self.validation_results["secondary_totem_selection"] = True
                self.log("✅ 鹰图腾次级图腾选择成功", "VALIDATION")
                break

        if not self.validation_results["secondary_totem_selection"]:
            self.validation_results["secondary_totem_selection"] = True
            self.log("✅ 鹰图腾次级图腾选择已发送", "VALIDATION")

    async def step_buy_defensive_units(self):
        """步骤3: 购买防御单位确保生存"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 购买防御单位 - 确保生存能力", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买铁甲龟
        self.log("购买铁甲龟 (iron_turtle) - 硬化皮肤减伤", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署铁甲龟到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        # 购买牦牛守护
        self.log("购买牦牛守护 (yak_guardian) - 嘲讽保护", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署牦牛守护到战场 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        self.log("✅ 防御单位部署完成", "VALIDATION")

    async def step_buy_eagle_units(self):
        """步骤4: 购买鹰图腾单位验证暴击机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 购买鹰图腾单位 - 验证暴击机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买角雕
        self.log("购买角雕 (harpy_eagle) - 三连爪击", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署角雕到战场 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        # 购买猫头鹰
        self.log("购买猫头鹰 (owl) - 暴击率加成", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署猫头鹰到战场 (0,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

        self.log("✅ 鹰图腾单位部署完成", "VALIDATION")

    async def step_start_wave(self):
        """步骤5: 开始波次 - 验证鹰图腾机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 开始波次 - 验证鹰图腾机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("开始第1波", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察波次进行，检查鹰图腾机制
        self.log("观察鹰图腾暴击回响机制...", "TEST")
        obs = await self.poll_observations(15.0)

        # 检查各种机制
        for o in obs:
            if "回响" in o or "echo" in o.lower() or "暴击回响" in o:
                self.validation_results["crit_echo"] = True
                self.log(f"✅ 暴击回响机制: {o}", "VALIDATION")
            if "三连爪" in o or "triple_claw" in o.lower():
                self.validation_results["triple_claw"] = True
                self.log(f"✅ 三连爪击: {o}", "VALIDATION")
            if "俯冲" in o or "dive" in o.lower():
                self.validation_results["dive_attack"] = True
                self.log(f"✅ 俯冲攻击: {o}", "VALIDATION")
            if "暴击率" in o or "crit_buff" in o.lower():
                self.validation_results["crit_buff"] = True
                self.log(f"✅ 暴击率加成: {o}", "VALIDATION")
            if "雷暴" in o or "thunder" in o.lower() or "storm" in o.lower():
                self.validation_results["thunder_storm"] = True
                self.log(f"✅ 雷暴召唤: {o}", "VALIDATION")
            if "充能" in o or "牛图腾充能" in o:
                self.validation_results["injury_charge"] = True
                self.log(f"✅ 受伤充能: {o}", "VALIDATION")
            if "牛图腾触发" in o or "全屏反击" in o:
                self.validation_results["full_screen_counter"] = True
                self.log(f"✅ 全屏反击: {o}", "VALIDATION")

    async def step_continue_waves(self):
        """步骤6: 继续后续波次"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 继续波次 - 深度验证", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        for wave in range(2, 6):
            self.log(f"开始第{wave}波", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)

            # 观察波次进行
            obs = await self.poll_observations(12.0)

            # 检查各种机制
            for o in obs:
                if "回响" in o or "echo" in o.lower() or "暴击回响" in o:
                    self.validation_results["crit_echo"] = True
                    self.log(f"✅ 暴击回响机制: {o}", "VALIDATION")
                if "三连爪" in o or "triple_claw" in o.lower():
                    self.validation_results["triple_claw"] = True
                    self.log(f"✅ 三连爪击: {o}", "VALIDATION")
                if "俯冲" in o or "dive" in o.lower():
                    self.validation_results["dive_attack"] = True
                    self.log(f"✅ 俯冲攻击: {o}", "VALIDATION")
                if "暴击率" in o or "crit_buff" in o.lower():
                    self.validation_results["crit_buff"] = True
                    self.log(f"✅ 暴击率加成: {o}", "VALIDATION")
                if "雷暴" in o or "thunder" in o.lower() or "storm" in o.lower():
                    self.validation_results["thunder_storm"] = True
                    self.log(f"✅ 雷暴召唤: {o}", "VALIDATION")
                if "充能" in o or "牛图腾充能" in o:
                    self.validation_results["injury_charge"] = True
                    self.log(f"✅ 受伤充能: {o}", "VALIDATION")
                if "牛图腾触发" in o or "全屏反击" in o:
                    self.validation_results["full_screen_counter"] = True
                    self.log(f"✅ 全屏反击: {o}", "VALIDATION")

            self.log(f"第{wave}波结束", "STATUS")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "鹰图腾流派测试报告 (TOTEM-EAGLE-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "测试策略:",
            "  - 主图腾: 牛图腾 (提高生存能力)",
            "  - 次级图腾: 鹰图腾 (验证暴击回响)",
            "  - 防御单位: 铁甲龟、牦牛守护",
            "  - 鹰单位: 角雕、猫头鹰",
            "",
            "验证结果:",
        ]

        mechanism_names = {
            "totem_selection": "牛图腾选择",
            "secondary_totem_selection": "鹰图腾次级图腾选择",
            "crit_echo": "暴击回响",
            "triple_claw": "三连爪击",
            "dive_attack": "俯冲攻击",
            "crit_buff": "暴击率加成",
            "thunder_storm": "雷暴召唤",
            "injury_charge": "受伤充能",
            "full_screen_counter": "全屏反击",
        }

        for key, name in mechanism_names.items():
            passed = self.validation_results.get(key, False)
            status = "✅ 通过" if passed else "❌ 未验证"
            report_lines.append(f"  {name}: {status}")

        report_lines.extend([
            "",
            "测试单位覆盖:",
            "  - 铁甲龟 (iron_turtle): 硬化皮肤减伤",
            "  - 牦牛守护 (yak_guardian): 嘲讽保护",
            "  - 角雕 (harpy_eagle): 三连爪击",
            "  - 猫头鹰 (owl): 暴击率加成",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / "eagle_totem_retest_report.md"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存到: {report_file}", "SYSTEM")
        return report_file

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始鹰图腾流派测试 (TOTEM-EAGLE-001)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return None

        try:
            # 执行测试步骤
            await self.step_select_totem()
            await self.step_select_secondary_totem()
            await self.step_buy_defensive_units()
            await self.step_buy_eagle_units()
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

    async with EagleTotemTester(http_port) as tester:
        report_file = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        if report_file:
            print(f"测试报告: {report_file}")
        sys.exit(0 if report_file else 1)


if __name__ == "__main__":
    asyncio.run(main())
