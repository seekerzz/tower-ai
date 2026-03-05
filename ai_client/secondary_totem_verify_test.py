#!/usr/bin/env python3
"""
次级图腾机制修复验证测试

测试目标:
- 验证次级图腾机制实例化修复
- 主图腾: 牛图腾 (cow_totem)
- 次级图腾: 鹰图腾 (eagle_totem)
- 验证鹰图腾暴击回响机制是否能触发
"""

import asyncio
import sys
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from ai_client.eagle_totem_test import EagleTester


class SecondaryTotemVerifyTest(EagleTester):
    """次级图腾机制修复验证测试"""

    async def run_test(self):
        """运行验证测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("开始次级图腾机制修复验证测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")
        self.log("主图腾: 牛图腾 (cow_totem)", "SYSTEM")
        self.log("次级图腾: 鹰图腾 (eagle_totem)", "SYSTEM")
        self.log("验证目标: 鹰图腾暴击回响机制", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        if not await self.wait_for_game_ready():
            self.log("游戏未就绪", "ERROR")
            return False

        # 步骤1: 选择牛图腾作为主图腾
        self.log("\n步骤1: 选择主图腾 - 牛图腾", "SYSTEM")
        await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
        await asyncio.sleep(2)
        obs = await self.poll_observations(3)

        # 检查牛图腾选择成功
        cow_selected = any("cow_totem" in o or "牛图腾" in o for o in obs)
        if cow_selected:
            self.log("✅ 牛图腾主图腾选择成功", "VALIDATION")
        else:
            self.log("⚠️ 未检测到牛图腾选择确认，继续测试", "WARNING")

        # 步骤2: 等待次级图腾选择
        self.log("\n步骤2: 等待次级图腾选择界面", "SYSTEM")
        await asyncio.sleep(3)
        obs = await self.poll_observations(5)

        # 检查是否出现次级图腾选择
        secondary_selection = any("次级图腾" in o or "secondary" in o.lower() for o in obs)
        if secondary_selection:
            self.log("✅ 次级图腾选择界面出现", "VALIDATION")
        else:
            self.log("⚠️ 未检测到次级图腾选择界面，可能需要完成波次", "WARNING")

        # 步骤3: 购买单位并部署
        self.log("\n步骤3: 购买单位", "SYSTEM")
        await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
        await asyncio.sleep(0.5)

        # 部署单位
        await self.send_actions([{
            "type": "move_unit",
            "from_zone": "bench",
            "to_zone": "grid",
            "from_pos": 0,
            "to_pos": {"x": 1, "y": 0}
        }])
        await asyncio.sleep(1)
        obs = await self.poll_observations(2)

        # 步骤4: 开始波次
        self.log("\n步骤4: 开始波次", "SYSTEM")
        await self.send_actions([{"type": "start_wave"}])
        await asyncio.sleep(1)

        # 观察波次进行，寻找暴击回响日志
        self.log("\n步骤5: 观察暴击回响机制", "SYSTEM")
        self.log("等待暴击回响日志输出...", "SYSTEM")

        crit_echo_found = False
        for i in range(10):  # 观察10轮
            obs = await self.poll_observations(3)
            for o in obs:
                if "暴击回响" in o or "crit_echo" in o.lower() or "回响" in o:
                    self.log(f"✅ 检测到暴击回响: {o}", "VALIDATION")
                    crit_echo_found = True
                if "eagle_totem" in o.lower() or "鹰图腾" in o:
                    self.log(f"✅ 检测到鹰图腾相关: {o}", "VALIDATION")

            if crit_echo_found:
                break

            await asyncio.sleep(1)

        # 生成报告
        self.log("\n" + "=" * 60, "SYSTEM")
        self.log("测试报告生成", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        if crit_echo_found:
            self.log("✅ 次级图腾机制修复验证通过", "RESULT")
            self.log("鹰图腾暴击回响机制已正常触发", "RESULT")
        else:
            self.log("⚠️ 未检测到暴击回响日志", "RESULT")
            self.log("可能原因:", "RESULT")
            self.log("  - 暴击率较低，未触发暴击", "RESULT")
            self.log("  - 波次时间过短", "RESULT")
            self.log("  - 需要更多单位来提高暴击概率", "RESULT")

        return crit_echo_found


async def main():
    async with SecondaryTotemVerifyTest() as tester:
        result = await tester.run_test()
        sys.exit(0 if result else 1)


if __name__ == "__main__":
    asyncio.run(main())
