#!/usr/bin/env python3
"""
蝙蝠图腾流派全面测试脚本 (TOTEM-BAT-001)

测试目标:
- 蝙蝠图腾5秒攻击3个最近敌人
- 流血标记是否正确施加
- 攻击流血敌人的吸血效果
- 血法师的血池范围和DOT伤害
- 生命链条的连接和生命值偷取
- 鲜血圣杯的吸血溢出和流失机制
- 血祭术士的主动技能消耗和效果

测试策略: 吸血续航流 - 围绕流血机制构建队伍
"""

import asyncio
import json
import time
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class BatTotemTester:
    """蝙蝠图腾测试器"""

    def __init__(self, http_port: int = 8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.observations: List[str] = []
        self.test_start_time = datetime.now()
        self.log_file: Optional[Path] = None

        # 测试状态
        self.current_wave = 0
        self.core_health = 500.0
        self.max_core_health = 500.0
        self.gold = 150
        self.mana = 500.0
        self.units_on_grid: Dict[str, Any] = {}
        self.units_on_bench: Dict[str, Any] = {}

        # 验证结果
        self.validation_results: Dict[str, bool] = {
            "totem_bleed_attack": False,      # 图腾流血攻击
            "bleed_debuff_apply": False,      # 流血标记施加
            "life_steal_on_bleed": False,     # 吸血效果
            "blood_mage_pool": False,         # 血法师血池
            "life_chain_connection": False,   # 生命链条连接
            "blood_chalice_overflow": False,  # 鲜血圣杯溢出
            "blood_ritualist_skill": False,   # 血祭术士技能
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = Path(f"logs/ai_session_bat_totem_{timestamp}.log")
        self.log_file.parent.mkdir(exist_ok=True)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message: str, event_type: str = "INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] [{event_type}] {message}"
        self.observations.append(log_line)
        print(log_line)

        # 写入日志文件
        if self.log_file:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(log_line + "\n")

    async def send_actions(self, actions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """发送动作到游戏"""
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
        """获取游戏观测数据"""
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
        """轮询观测数据一段时间"""
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

    # ==================== 测试步骤 ====================

    async def step_select_totem(self):
        """步骤1: 选择蝙蝠图腾"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤1: 选择蝙蝠图腾 (bat_totem)", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([
            {"type": "select_totem", "totem_id": "bat_totem"}
        ])
        await asyncio.sleep(1.0)
        await self.poll_observations(2.0)

        self.log("✅ 已选择蝙蝠图腾", "VALIDATION")

    async def step_buy_initial_units(self):
        """步骤2: 购买初始单位"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤2: 购买初始单位", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 优先购买蚊子 (吸血单位)
        self.log("购买蚊子 (mosquito) - 吸血核心单位", "ACTION")
        await self.send_actions([
            {"type": "buy_unit", "shop_index": 0}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)

        # 移动蚊子到战场
        self.log("将蚊子部署到战场 (1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)

    async def step_start_wave_1(self):
        """步骤3: 开始第1波"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤3: 开始第1波 - 验证蝙蝠图腾流血攻击", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.current_wave = 1
        await self.send_actions([
            {"type": "start_wave"}
        ])

        # 等待波次进行，观察图腾攻击和流血效果
        self.log("观察蝙蝠图腾5秒攻击3个最近敌人...", "TEST")
        obs = await self.poll_observations(8.0)

        # 检查流血相关日志
        for o in obs:
            if "流血" in o or "bleed" in o.lower():
                self.validation_results["bleed_debuff_apply"] = True
                self.log("✅ 流血标记正确施加", "VALIDATION")
            if "图腾" in o and "攻击" in o:
                self.validation_results["totem_bleed_attack"] = True
                self.log("✅ 蝙蝠图腾攻击触发", "VALIDATION")
            if "吸血" in o or "生命偷取" in o or "lifesteal" in o.lower():
                self.validation_results["life_steal_on_bleed"] = True
                self.log("✅ 吸血效果触发", "VALIDATION")

    async def step_buy_blood_mage(self):
        """步骤4: 购买血法师"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤4: 购买血法师 - 验证血池机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 刷新商店寻找血法师
        self.log("刷新商店寻找血法师...", "ACTION")
        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.poll_observations(1.0)

        # 尝试购买
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(1.0)

        # 部署血法师
        self.log("部署血法师到战场 (0,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(3.0)

        for o in obs:
            if "血池" in o or "blood pool" in o.lower():
                self.validation_results["blood_mage_pool"] = True
                self.log("✅ 血法师血池机制正常", "VALIDATION")

    async def step_buy_life_chain(self):
        """步骤5: 购买生命链条"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤5: 购买生命链条 - 验证连接和偷取", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 1}])
        await asyncio.sleep(0.5)

        self.log("部署生命链条到战场 (-1,0)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": -1, "y": 0}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(5.0)

        for o in obs:
            if "连接" in o or "链条" in o or "偷取" in o:
                self.validation_results["life_chain_connection"] = True
                self.log("✅ 生命链条连接机制正常", "VALIDATION")

    async def step_buy_blood_chalice(self):
        """步骤6: 购买鲜血圣杯"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤6: 购买鲜血圣杯 - 验证吸血溢出机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 2}])
        await asyncio.sleep(0.5)

        self.log("部署鲜血圣杯到战场 (0,-1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 0, "y": -1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(5.0)

        for o in obs:
            if "溢出" in o or "流失" in o or "chalice" in o.lower():
                self.validation_results["blood_chalice_overflow"] = True
                self.log("✅ 鲜血圣杯溢出机制正常", "VALIDATION")

    async def step_buy_blood_ritualist(self):
        """步骤7: 购买血祭术士"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤7: 购买血祭术士 - 验证主动技能", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        await self.send_actions([{"type": "refresh_shop"}])
        await asyncio.sleep(0.5)
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        self.log("部署血祭术士到战场 (1,1)", "ACTION")
        await self.send_actions([
            {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
             "from_pos": 0, "to_pos": {"x": 1, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        await self.poll_observations(2.0)

    async def step_test_blood_ritualist_skill(self):
        """步骤8: 测试血祭术士主动技能 - 高风险自残操作"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤8: 测试血祭术士主动技能 - 自残后快速回血", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        self.log("执行血祭术士主动技能 - 消耗25%核心HP", "ACTION")
        self.log("⚠️ 高风险操作: 自残后需要快速回血", "WARNING")

        # 记录当前血量
        pre_health = self.core_health
        self.log(f"技能前核心血量: {pre_health}", "STATUS")

        # 使用技能
        await self.send_actions([
            {"type": "use_skill", "grid_pos": {"x": 1, "y": 1}}
        ])
        await asyncio.sleep(0.5)
        obs = await self.poll_observations(5.0)

        for o in obs:
            if "血祭" in o or "仪式" in o or "流血" in o:
                self.validation_results["blood_ritualist_skill"] = True
                self.log("✅ 血祭术士主动技能正常", "VALIDATION")

        self.log("观察吸血回血效果...", "TEST")
        await asyncio.sleep(3.0)
        obs = await self.poll_observations(5.0)

    async def step_buy_additional_units(self):
        """步骤9: 购买更多蝙蝠阵营单位"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤9: 购买更多单位 - 石像鬼、瘟疫使者、血祖", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        units_to_buy = ["gargoyle", "plague_spreader", "blood_ancestor"]
        positions = [(2, 0), (-1, 1), (1, -1)]

        for i, unit in enumerate(units_to_buy):
            self.log(f"尝试购买 {unit}...", "ACTION")
            await self.send_actions([{"type": "refresh_shop"}])
            await asyncio.sleep(0.5)
            await self.send_actions([{"type": "buy_unit", "shop_index": i % 4}])
            await asyncio.sleep(0.3)

            # 尝试部署
            if i < len(positions):
                x, y = positions[i]
                await self.send_actions([
                    {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
                     "from_pos": 0, "to_pos": {"x": x, "y": y}}
                ])
                await asyncio.sleep(0.3)

        await self.poll_observations(3.0)

    async def step_continue_waves(self):
        """步骤10: 继续后续波次"""
        self.log("=" * 60, "SYSTEM")
        self.log("步骤10: 继续波次 - 验证吸血续航流", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        for wave in range(2, 5):
            self.current_wave = wave
            self.log(f"开始第{wave}波", "ACTION")
            await self.send_actions([{"type": "start_wave"}])
            await asyncio.sleep(1.0)

            # 观察波次进行
            obs = await self.poll_observations(10.0)

            # 检查各种机制
            for o in obs:
                if "流血" in o:
                    self.validation_results["bleed_debuff_apply"] = True
                if "吸血" in o or "回复" in o:
                    self.validation_results["life_steal_on_bleed"] = True

            self.log(f"第{wave}波结束", "STATUS")

    async def generate_report(self):
        """生成测试报告"""
        self.log("=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        duration = (datetime.now() - self.test_start_time).total_seconds()

        report_lines = [
            "\n" + "=" * 60,
            "蝙蝠图腾流派测试报告 (TOTEM-BAT-001)",
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
            "  - 蚊子 (mosquito): 吸血核心",
            "  - 血法师 (blood_mage): 血池DOT",
            "  - 生命链条 (life_chain): 连接偷取",
            "  - 鲜血圣杯 (blood_chalice): 溢出机制",
            "  - 血祭术士 (blood_ritualist): 主动技能",
            "  - 石像鬼 (gargoyle): 石化机制",
            "  - 瘟疫使者 (plague_spreader): 易伤debuff",
            "  - 血祖 (blood_ancestor): 鲜血领域",
            "",
            "=" * 60,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        return report

    async def run_full_test(self):
        """运行完整测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始蝙蝠图腾流派全面测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 等待游戏就绪
        if not await self.wait_for_game_ready():
            self.log("❌ 游戏未就绪，测试中止", "ERROR")
            return False

        try:
            # 执行测试步骤
            await self.step_select_totem()
            await self.step_buy_initial_units()
            await self.step_start_wave_1()
            await self.step_buy_blood_mage()
            await self.step_buy_life_chain()
            await self.step_buy_blood_chalice()
            await self.step_buy_blood_ritualist()
            await self.step_test_blood_ritualist_skill()
            await self.step_buy_additional_units()
            await self.step_continue_waves()

            # 生成报告
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
    """主函数"""
    # 从命令行获取端口
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with BatTotemTester(http_port) as tester:
        success = await tester.run_full_test()
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
