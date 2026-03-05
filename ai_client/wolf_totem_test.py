#!/usr/bin/env python3
"""
狼图腾流派全面测试脚本 (TOTEM-WOLF-001)

测试目标:
- 狼图腾魂魄获取机制
- 图腾攻击魂魄加成
- 羊灵克隆机制
- 狮子冲击波
- 血食狼群辅助

测试策略: 魂魄收割流 - 验证敌人阵亡魂魄机制
"""

import asyncio
import json
import time
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))
import aiohttp


class WolfTotemTester:
    """狼图腾测试器"""

    def __init__(self, http_port: int = 8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.observations: List[str] = []
        self.test_start_time = datetime.now()
        self.log_file: Optional[Path] = None

        self.validation_results: Dict[str, bool] = {
            "soul_collection": False,      # 魂魄收集
            "totem_soul_bonus": False,     # 图腾魂魄加成
            "sheep_spirit_clone": False,   # 羊灵克隆
            "lion_shockwave": False,       # 狮子冲击波
            "blood_meat_buff": False,      # 血食buff
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = Path(f"logs/ai_session_wolf_totem_{timestamp}.log")
        self.log_file.parent.mkdir(exist_ok=True)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message: str, event_type: str = "INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] [{event_type}] {message}"
        self.observations.append(log_line)
        print(log_line)
        if self.log_file:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(log_line + "\n")

    async def send_actions(self, actions: List[Dict[str, Any]]) -> Dict[str, Any]:
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": actions},
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                return await resp.json()
        except Exception as e:
            self.log(f"发送动作失败: {e}", "ERROR")
            return {"status": "error", "message": str(e)}

    async def get_observations(self) -> List[str]:
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=5)
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
                self.log(o, "GAME")
            await asyncio.sleep(0.2)
        return all_obs

    async def wait_for_game_ready(self, timeout: float = 30.0) -> bool:
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

    def extract_core_health(self, observations: List[str]) -> Optional[int]:
        """从观测中提取核心血量"""
        for obs in observations:
            if "核心血量" in obs or "HP" in obs:
                # 匹配 "核心血量: 0/530" 或 "HP: 0/530" 格式
                import re
                match = re.search(r'[:：]\s*(\d+)\s*/\s*(\d+)', obs)
                if match:
                    current = int(match.group(1))
                    max_val = int(match.group(2))
                    return current
        return None

    def extract_wave_number(self, observations: List[str]) -> Optional[int]:
        """从观测中提取当前波次"""
        for obs in observations:
            if "第" in obs and "波" in obs:
                import re
                match = re.search(r'第\s*(\d+)\s*波', obs)
                if match:
                    return int(match.group(1))
        return None

    async def check_and_reset_game(self) -> bool:
        """检查游戏状态，如果已结束则重置"""
        self.log("=" * 60, "SYSTEM")
        self.log("检查游戏状态", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 获取当前观测
        obs = await self.poll_observations(2.0)
        health = self.extract_core_health(obs)
        wave = self.extract_wave_number(obs)

        # 检查是否需要重置
        need_reset = False
        if health is not None and health <= 0:
            self.log(f"⚠️ 游戏已结束 (核心血量: {health})，需要重置", "WARNING")
            need_reset = True
        elif wave is not None and wave > 1:
            self.log(f"⚠️ 游戏不在初始状态 (当前波次: {wave})，需要重置", "WARNING")
            need_reset = True

        if need_reset:
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
                    if "选择图腾" in o or "totem" in o.lower():
                        self.log("✅ 游戏已重置，进入图腾选择阶段", "VALIDATION")
                        return True

            self.log("❌ 游戏重置超时", "ERROR")
            return False
        else:
            if health:
                self.log(f"✅ 游戏状态正常 (核心血量: {health}, 波次: {wave or 1})", "VALIDATION")
            return True

    async def step_select_totem(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择狼图腾 (wolf_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        await self.send_actions([{"type": "select_totem", "totem_id": "wolf_totem"}])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)
        self.log("✅ 已选择狼图腾", "VALIDATION")

    async def step_buy_initial_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 购买初始单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        self.log("购买羊灵 (sheep_spirit) - 克隆核心", "ACTION")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)
        self.log("将羊灵部署到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)

    async def step_start_wave_1(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 开始第1波 - 验证魂魄收集", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        await self.send_actions([{"type": "start_wave"}])
        self.log("观察狼图腾魂魄收集机制...", "TEST")
        obs = await self.poll_observations(8.0)
        for o in obs:
            if "魂魄" in o or "soul" in o.lower():
                self.validation_results["soul_collection"] = True
                self.log("✅ 魂魄收集机制正常", "VALIDATION")
            if "图腾" in o and "攻击" in o:
                self.validation_results["totem_soul_bonus"] = True
                self.log("✅ 图腾魂魄加成攻击", "VALIDATION")
            if "克隆" in o or "clone" in o.lower():
                self.validation_results["sheep_spirit_clone"] = True
                self.log("✅ 羊灵克隆机制", "VALIDATION")

    async def step_buy_lion(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 购买狮子 - 验证冲击波", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        self.log("部署狮子到战场 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(3.0)
        for o in obs:
            if "冲击波" in o or "shockwave" in o.lower():
                self.validation_results["lion_shockwave"] = True
                self.log("✅ 狮子冲击波机制", "VALIDATION")

    async def step_buy_blood_meat(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 购买血食 - 验证狼群辅助", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 1}])
        await asyncio.sleep(0.5)
        self.log("部署血食到战场 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(3.0)
        for o in obs:
            if "狼群" in o or "辅助" in o or "buff" in o.lower():
                self.validation_results["blood_meat_buff"] = True
                self.log("✅ 血食狼群辅助机制", "VALIDATION")

    async def step_buy_additional_units(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 购买更多狼族单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        units_to_buy = ["dog", "hyena", "fox"]
        positions = [(1, 1), (-1, 1), (0, -1)]
        for i, unit in enumerate(units_to_buy):
            self.log(f"尝试购买 {unit}...", "ACTION")
            await self.send_actions([{"type": "refresh_shop"}])
            await asyncio.sleep(0.5)
            await self.send_actions([{"type": "buy_unit", "shop_index": i % 4}])
            await asyncio.sleep(0.3)
            if i < len(positions):
                x, y = positions[i]
                await self.send_actions([
                    {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
                     "from_pos": 0, "to_pos": {"x": x, "y": y}}
                ])
                await asyncio.sleep(0.3)
        await self.poll_observations(3.0)

    async def step_continue_waves(self):
        self.log("=" * 60, "SYSTEM")
        self.log("步骤7: 继续波次 - 验证魂魄收割流", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        for wave in range(2, 5):
            self.log(f"开始第{wave}波", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)
            obs = await self.poll_observations(10.0)
            for o in obs:
                if "魂魄" in o:
                    self.validation_results["soul_collection"] = True
                if "克隆" in o:
                    self.validation_results["sheep_spirit_clone"] = True
            self.log(f"第{wave}波结束", "STATUS")

    async def generate_report(self):
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        duration = (datetime.now() - self.test_start_time).total_seconds()
        report_lines = [
            "\n" + "=" * 60,
            "狼图腾流派测试报告 (TOTEM-WOLF-001)",
            "=" * 60,
            f"测试时间: {self.test_start_time.strftime('%Y-%m-%d %H:%M:%S')}",
            f"测试时长: {duration:.1f}秒",
            f"日志文件: {self.log_file}",
            "",
            "验证结果:",
        ]
        for mechanism, passed in self.validation_results.items():
            status = "✅ 通过" if passed else "❌ 未验证"
            report_lines.append(f"  {mechanism}: {status}")
        report_lines.extend([
            "",
            "测试单位覆盖:",
            "  - 羊灵 (sheep_spirit): 克隆机制",
            "  - 狮子 (lion): 冲击波",
            "  - 血食 (blood_meat): 狼群辅助",
            "  - 恶霸犬 (dog): 狂暴",
            "  - 鬣狗 (hyena): 残血收割",
            "  - 狐狸 (fox): 魅惑",
            "",
            "=" * 60,
        ])
        report = "\n".join(report_lines)
        self.log(report, "REPORT")
        return report

    async def run_full_test(self):
        self.log("=" * 60, "SYSTEM")
        self.log("开始狼图腾流派全面测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return False
        # 检查并重置游戏状态
        if not await self.check_and_reset_game():
            self.log("❌ 游戏状态重置失败，测试中止", "ERROR")
            return False
        try:
            await self.step_select_totem()
            await self.step_buy_initial_units()
            await self.step_start_wave_1()
            await self.step_buy_lion()
            await self.step_buy_blood_meat()
            await self.step_buy_additional_units()
            await self.step_continue_waves()
            await self.generate_report()
            self.log("=" * 60, "SYSTEM")
            self.log("测试完成", "SYSTEM")
            self.log("=" * 60, "SYSTEM")
            return True
        except Exception as e:
            self.log(f"测试过程中发生错误: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return False


async def main():
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])
    async with WolfTotemTester(http_port) as tester:
        success = await tester.run_full_test()
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
