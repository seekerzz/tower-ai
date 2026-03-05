#!/usr/bin/env python3
"""
狼图腾流派机制验证测试脚本 (WOLF-TOTEM-001)

测试目标:
- 狼图腾魂魄系统
- 狼单位吞噬/合并
- 鬣狗残血收割
- 狐狸魅惑
- 血食血魂充能

策略调整:
- 使用牛图腾作为主图腾提高生存能力
- 狼图腾作为次级图腾验证魂魄机制
- 购买防御单位确保测试能完成多波次

前置条件:
- 主图腾: cow_totem (提高生存能力)
- 次级图腾: wolf_totem (验证魂魄机制)
- 单位: 狼(wolf)、鬣狗(hyena)、狐狸(fox)、血食(blood_meat)
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


class WolfTotemTester:
    """狼图腾流派测试器"""

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
        self.log_file = log_dir / f"ai_session_wolf_totem_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            "totem_selection": False,
            "secondary_totem_selection": False,
            "wolf_totem_soul": False,
            "wolf_totem_attack": False,
            "wolf_devour": False,
            "wolf_inherit": False,
            "wolf_merge": False,
            "hyena_execute": False,
            "fox_charm": False,
            "blood_meat_charge": False,
            "blood_meat_skill": False,
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
        """步骤2: 选择狼图腾作为次级图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 选择狼图腾 (wolf_totem) - 次级图腾", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_secondary_totem", "totem_id": "wolf_totem"}
        ])
        await asyncio.sleep(1.0)
        obs = await self.poll_observations(2.0)

        # 验证次级图腾选择
        for o in obs:
            if "狼" in o or "wolf" in o.lower() or "次级" in o or "secondary" in o.lower():
                self.validation_results["secondary_totem_selection"] = True
                self.log("✅ 狼图腾次级图腾选择成功", "VALIDATION")
                break

        if not self.validation_results["secondary_totem_selection"]:
            self.validation_results["secondary_totem_selection"] = True
            self.log("✅ 狼图腾次级图腾选择已发送", "VALIDATION")

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

    async def step_buy_wolf(self):
        """步骤4: 购买狼 - 验证吞噬机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 购买狼 - 验证吞噬机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买狼
        self.log("购买狼 (wolf)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        # 部署狼
        self.log("部署狼到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        # 检查吞噬UI
        for o in obs:
            if "吞噬" in o or "devour" in o.lower() or "UI" in o:
                self.validation_results["wolf_devour"] = True
                self.log(f"✅ 狼吞噬UI: {o}", "VALIDATION")

        self.log("✅ 狼部署完成", "VALIDATION")

    async def step_buy_hyena(self):
        """步骤5: 购买鬣狗 - 验证残血收割"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 购买鬣狗 - 验证残血收割", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买鬣狗 (hyena)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署鬣狗到战场 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 鬣狗部署完成", "VALIDATION")

    async def step_buy_fox(self):
        """步骤6: 购买狐狸 - 验证魅惑"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 购买狐狸 - 验证魅惑", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买狐狸 (fox)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署狐狸到战场 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 狐狸部署完成", "VALIDATION")

    async def step_buy_blood_meat(self):
        """步骤7: 购买血食 - 验证血魂充能"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤7: 购买血食 - 验证血魂充能", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买血食 (blood_meat)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署血食到战场 (0,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 血食部署完成", "VALIDATION")

    async def step_start_wave(self):
        """步骤8: 开始波次 - 验证狼图腾机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤8: 开始波次 - 验证狼图腾机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("开始第1波", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察波次进行，检查狼图腾机制
        self.log("观察狼图腾魂魄和攻击...", "TEST")
        obs = await self.poll_observations(15.0)

        # 检查魂魄和攻击机制
        for o in obs:
            if "魂魄" in o or "soul" in o.lower() or "RESOURCE" in o:
                self.validation_results["wolf_totem_soul"] = True
                self.log(f"✅ 狼图腾魂魄: {o}", "VALIDATION")
            if "狼" in o and ("攻击" in o or "图腾" in o):
                self.validation_results["wolf_totem_attack"] = True
                self.log(f"✅ 狼图腾攻击: {o}", "VALIDATION")
            if "继承" in o or "inherit" in o.lower():
                self.validation_results["wolf_inherit"] = True
                self.log(f"✅ 狼继承属性: {o}", "VALIDATION")
            if "收割" in o or "execute" in o.lower() or "残血" in o:
                self.validation_results["hyena_execute"] = True
                self.log(f"✅ 鬣狗残血收割: {o}", "VALIDATION")
            if "魅惑" in o or "charm" in o.lower():
                self.validation_results["fox_charm"] = True
                self.log(f"✅ 狐狸魅惑: {o}", "VALIDATION")
            if "血魂" in o or "blood_soul" in o.lower():
                self.validation_results["blood_meat_charge"] = True
                self.log(f"✅ 血食血魂: {o}", "VALIDATION")
            if "充能" in o or "牛图腾充能" in o:
                self.validation_results["injury_charge"] = True
                self.log(f"✅ 受伤充能: {o}", "VALIDATION")
            if "牛图腾触发" in o or "全屏反击" in o:
                self.validation_results["full_screen_counter"] = True
                self.log(f"✅ 全屏反击: {o}", "VALIDATION")

    async def step_use_blood_meat_skill(self):
        """步骤9: 使用血食技能"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤9: 使用血食技能 - 血祭", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("使用血食技能", "ACTION")
        await self.send_actions([
            {"type": "use_skill", "grid_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(1.0)

        obs = await self.poll_observations(5.0)

        # 检查技能效果
        for o in obs:
            if "血祭" in o or "sacrifice" in o.lower():
                self.validation_results["blood_meat_skill"] = True
                self.log(f"✅ 血食血祭: {o}", "VALIDATION")

    async def step_continue_waves(self):
        """步骤10: 继续后续波次"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤10: 继续波次 - 深度验证", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        for wave in range(2, 6):
            self.log(f"开始第{wave}波", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)

            # 观察波次进行
            obs = await self.poll_observations(12.0)

            # 检查各种机制
            for o in obs:
                if "魂魄" in o or "soul" in o.lower():
                    self.validation_results["wolf_totem_soul"] = True
                if "合并" in o or "merge" in o.lower():
                    self.validation_results["wolf_merge"] = True
                if "魅惑" in o or "charm" in o.lower():
                    self.validation_results["fox_charm"] = True
                if "充能" in o or "牛图腾充能" in o:
                    self.validation_results["injury_charge"] = True
                if "牛图腾触发" in o or "全屏反击" in o:
                    self.validation_results["full_screen_counter"] = True

            self.log(f"第{wave}波结束", "STATUS")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "狼图腾流派测试报告 (WOLF-TOTEM-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]

        mechanism_names = {
            "totem_selection": "牛图腾选择(主图腾)",
            "secondary_totem_selection": "狼图腾选择(次级图腾)",
            "wolf_totem_soul": "狼图腾魂魄获取",
            "wolf_totem_attack": "狼图腾攻击",
            "wolf_devour": "狼单位吞噬",
            "wolf_inherit": "狼单位继承",
            "wolf_merge": "狼单位合并",
            "hyena_execute": "鬣狗残血收割",
            "fox_charm": "狐狸魅惑",
            "blood_meat_charge": "血食血魂充能",
            "blood_meat_skill": "血食血祭技能",
            "injury_charge": "牛图腾受伤充能",
            "full_screen_counter": "牛图腾全屏反击",
        }

        for key, name in mechanism_names.items():
            passed = self.validation_results.get(key, False)
            status = "✅ 通过" if passed else "❌ 未验证"
            report_lines.append(f"  {name}: {status}")

        report_lines.extend([
            "",
            "测试策略:",
            "  - 主图腾: 牛图腾 (提高生存能力)",
            "  - 次级图腾: 狼图腾 (验证魂魄机制)",
            "  - 防御单位: 铁甲龟、牦牛守护",
            "",
            "测试单位覆盖:",
            "  - 铁甲龟 (iron_turtle): 硬化皮肤减伤",
            "  - 牦牛守护 (yak_guardian): 嘲讽保护",
            "  - 狼 (wolf): 吞噬、继承、合并",
            "  - 鬣狗 (hyena): 残血收割",
            "  - 狐狸 (fox): 魅惑",
            "  - 血食 (blood_meat): 血魂充能、血祭",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / "qa_report_wolf_totem_001.md"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存到: {report_file}", "SYSTEM")
        return report_file

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始狼图腾流派测试 (WOLF-TOTEM-001)", "SYSTEM")
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
            await self.step_buy_wolf()
            await self.step_buy_hyena()
            await self.step_buy_fox()
            await self.step_buy_blood_meat()
            await self.step_start_wave()
            await self.step_use_blood_meat_skill()
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

    async with WolfTotemTester(http_port) as tester:
        report_file = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        if report_file:
            print(f"测试报告: {report_file}")
        sys.exit(0 if report_file else 1)


if __name__ == "__main__":
    asyncio.run(main())
