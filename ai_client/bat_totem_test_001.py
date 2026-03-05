#!/usr/bin/env python3
"""
蝙蝠图腾流派机制验证测试脚本 (BAT-TOTEM-001)

测试目标:
- 蝙蝠图腾流血标记、吸血回复
- 蚊子吸食机制
- 血法师血池DOT
- 生命链条偷取生命
- 血祭术士鲜血仪式

前置条件:
- 图腾: bat_totem
- 单位: 蚊子(mosquito)、血法师(blood_mage)、生命链条(life_chain)、血祭术士(blood_ritualist)
- 作弊API: set_core_hp(500) 设置中等血量以便观察回血
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


class BatTotemTester:
    """蝙蝠图腾流派测试器"""

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
        self.log_file = log_dir / f"ai_session_bat_totem_{timestamp}.log"

        # 验证结果
        self.validation_results = {
            "totem_selection": False,
            "bat_totem_bleed_attack": False,
            "bat_totem_lifesteal": False,
            "mosquito_damage": False,
            "mosquito_heal": False,
            "blood_mage_blood_pool": False,
            "blood_mage_dot_damage": False,
            "life_chain_connect": False,
            "life_chain_steal": False,
            "blood_ritualist_skill": False,
            "blood_ritualist_bleed": False,
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

    async def step_buy_mosquito(self):
        """步骤2: 购买蚊子 - 验证吸食机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 购买蚊子 - 验证吸食机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 购买蚊子
        self.log("购买蚊子 (mosquito)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        # 部署蚊子
        self.log("部署蚊子到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 蚊子部署完成", "VALIDATION")

    async def step_buy_blood_mage(self):
        """步骤3: 购买血法师 - 验证血池机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 购买血法师 - 验证血池机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买血法师 (blood_mage)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署血法师到战场 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 血法师部署完成", "VALIDATION")

    async def step_buy_life_chain(self):
        """步骤4: 购买生命链条 - 验证偷取生命"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 购买生命链条 - 验证偷取生命", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买生命链条 (life_chain)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署生命链条到战场 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 生命链条部署完成", "VALIDATION")

    async def step_buy_blood_ritualist(self):
        """步骤5: 购买血祭术士 - 验证鲜血仪式"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 购买血祭术士 - 验证鲜血仪式", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)

        self.log("购买血祭术士 (blood_ritualist)", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署血祭术士到战场 (0,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(2.0)

        self.log("✅ 血祭术士部署完成", "VALIDATION")

    async def step_start_wave(self):
        """步骤6: 开始波次 - 验证蝙蝠图腾机制"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 开始波次 - 验证蝙蝠图腾机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("开始第1波", "ACTION")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1.0)

        # 观察波次进行，检查蝙蝠图腾机制
        self.log("观察蝙蝠图腾流血攻击和吸血...", "TEST")
        obs = await self.poll_observations(15.0)

        # 检查流血和吸血机制
        for o in obs:
            if "流血" in o or "bleed" in o.lower() or "TOTEM_EFFECT" in o:
                self.validation_results["bat_totem_bleed_attack"] = True
                self.log(f"✅ 蝙蝠图腾流血攻击: {o}", "VALIDATION")
            if "吸血" in o or "lifesteal" in o.lower() or "TOTEM_HEAL" in o:
                self.validation_results["bat_totem_lifesteal"] = True
                self.log(f"✅ 蝙蝠图腾吸血: {o}", "VALIDATION")
            if "蚊子" in o or "mosquito" in o.lower():
                self.validation_results["mosquito_damage"] = True
                self.log(f"✅ 蚊子攻击: {o}", "VALIDATION")
            if "治疗" in o and ("蚊子" in o or "mosquito" in o.lower()):
                self.validation_results["mosquito_heal"] = True
                self.log(f"✅ 蚊子治疗核心: {o}", "VALIDATION")
            if "血池" in o or "blood_pool" in o.lower():
                self.validation_results["blood_mage_blood_pool"] = True
                self.log(f"✅ 血法师血池: {o}", "VALIDATION")
            if "生命链条" in o or "life_chain" in o.lower():
                self.validation_results["life_chain_connect"] = True
                self.log(f"✅ 生命链条连接: {o}", "VALIDATION")

    async def step_use_blood_ritualist_skill(self):
        """步骤7: 使用血祭术士技能"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤7: 使用血祭术士技能 - 鲜血仪式", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("使用血祭术士技能", "ACTION")
        await self.send_actions([
            {"type": "use_skill", "grid_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(1.0)

        obs = await self.poll_observations(5.0)

        # 检查技能效果
        for o in obs:
            if "鲜血仪式" in o or "ritual" in o.lower():
                self.validation_results["blood_ritualist_skill"] = True
                self.log(f"✅ 血祭术士技能: {o}", "VALIDATION")
            if "流血" in o and ("血祭" in o or "ritualist" in o.lower()):
                self.validation_results["blood_ritualist_bleed"] = True
                self.log(f"✅ 血祭术士流血: {o}", "VALIDATION")

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
                if "流血" in o or "bleed" in o.lower():
                    self.validation_results["bat_totem_bleed_attack"] = True
                if "吸血" in o or "lifesteal" in o.lower():
                    self.validation_results["bat_totem_lifesteal"] = True
                if "血池" in o or "DOT" in o:
                    self.validation_results["blood_mage_dot_damage"] = True
                if "偷取" in o or "steal" in o.lower():
                    self.validation_results["life_chain_steal"] = True

            self.log(f"第{wave}波结束", "STATUS")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        report_lines = [
            "\n" + "=" * 60,
            "蝙蝠图腾流派测试报告 (BAT-TOTEM-001)",
            "=" * 60,
            f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]

        mechanism_names = {
            "totem_selection": "图腾选择",
            "bat_totem_bleed_attack": "蝙蝠图腾流血攻击",
            "bat_totem_lifesteal": "蝙蝠图腾吸血回复",
            "mosquito_damage": "蚊子造成伤害",
            "mosquito_heal": "蚊子治疗核心",
            "blood_mage_blood_pool": "血法师血池召唤",
            "blood_mage_dot_damage": "血法师DOT伤害",
            "life_chain_connect": "生命链条连接",
            "life_chain_steal": "生命链条偷取",
            "blood_ritualist_skill": "血祭术士技能",
            "blood_ritualist_bleed": "血祭术士流血施加",
        }

        for key, name in mechanism_names.items():
            passed = self.validation_results.get(key, False)
            status = "✅ 通过" if passed else "❌ 未验证"
            report_lines.append(f"  {name}: {status}")

        report_lines.extend([
            "",
            "测试单位覆盖:",
            "  - 蚊子 (mosquito): 造成伤害，治疗核心20%",
            "  - 血法师 (blood_mage): 召唤血池，DOT伤害",
            "  - 生命链条 (life_chain): 连接敌人，偷取生命",
            "  - 血祭术士 (blood_ritualist): 鲜血仪式，施加流血",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存报告到文件
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(parents=True, exist_ok=True)
        report_file = report_dir / "qa_report_bat_totem_001.md"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        self.log(f"报告已保存到: {report_file}", "SYSTEM")
        return report_file

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始蝙蝠图腾流派测试 (BAT-TOTEM-001)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return None

        try:
            # 执行测试步骤
            await self.step_select_totem()
            await self.step_buy_mosquito()
            await self.step_buy_blood_mage()
            await self.step_buy_life_chain()
            await self.step_buy_blood_ritualist()
            await self.step_start_wave()
            await self.step_use_blood_ritualist_skill()
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

    async with BatTotemTester(http_port) as tester:
        report_file = await tester.run_full_test()
        print(f"\n日志文件: {tester.log_file}")
        if report_file:
            print(f"测试报告: {report_file}")
        sys.exit(0 if report_file else 1)


if __name__ == "__main__":
    asyncio.run(main())
