#!/usr/bin/env python3
"""
鹰图腾核心机制验证测试 (复测) - task_eagle_totem_002.md

验证目标:
- 暴击时有 30% 概率触发一次回响
- 造成等额伤害并施加攻击特效
- 日志标记：[TOTEM_EFFECT] 鹰图腾 触发暴击回响

修复内容:
- 修正单位部署坐标为 (-1,0) 或 (1,0)，避开核心位置 (0,0)
"""

import asyncio
import json
import time
import sys
import subprocess
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent))
import aiohttp


class EagleTotemRetestTester:
    """鹰图腾核心机制复测器"""

    def __init__(self, http_port=8082):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.log_file: Optional[Path] = None
        self.test_start_time: datetime = None

        # 验证结果
        self.validation_results = {
            "totem_selection": False,
            "unit_deployed": False,
            "wave_started": False,
            "crit_detected": False,
            "echo_triggered": False,
            "echo_damage_logged": False,
        }

        # 统计数据
        self.crit_count = 0
        self.echo_count = 0
        self.total_attacks = 0
        self.logs_collected: List[str] = []

    async def setup(self):
        """设置测试环境"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_eagle_totem_002_{timestamp}.log"

        self.session = aiohttp.ClientSession()
        self.test_start_time = datetime.now()

        # 清空日志
        with open(self.log_file, 'w') as f:
            f.write(f"# 鹰图腾核心机制复测 (task_eagle_totem_002)\n")
            f.write(f"# 测试开始时间：{self.test_start_time}\n\n")

    async def cleanup(self):
        """清理测试环境"""
        if self.session:
            await self.session.close()

    def log(self, message: str):
        """写入日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] {message}\n"
        with open(self.log_file, 'a') as f:
            f.write(log_line)
        self.logs_collected.append(log_line.strip())
        print(log_line.strip())

    async def wait_for_server(self, timeout=30):
        """等待 HTTP 服务器就绪"""
        start = time.time()
        while time.time() - start < timeout:
            try:
                async with self.session.get(f"{self.base_url}/health") as resp:
                    if resp.status == 200:
                        self.log("HTTP 服务器就绪")
                        return True
            except:
                pass
            await asyncio.sleep(0.5)
        self.log(f"错误：HTTP 服务器超时 ({timeout}s)")
        return False

    async def select_totem(self, totem_id: str) -> bool:
        """选择图腾 - 使用 select_totem 动作类型"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": [{"type": "select_totem", "totem_id": totem_id}]}
            ) as resp:
                result = await resp.json()
                if result.get("status") == "ok" or result.get("success"):
                    self.log(f"✅ 图腾选择成功：{totem_id}")
                    self.validation_results["totem_selection"] = True
                    return True
                else:
                    self.log(f"❌ 图腾选择失败：{result}")
                    return False
        except Exception as e:
            self.log(f"❌ 图腾选择异常：{e}")
            return False

    async def purchase_unit(self, unit_id: str) -> bool:
        """购买单位 - 使用 refresh_shop 和 buy_unit 动作"""
        try:
            # 先刷新商店
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": [{"type": "refresh_shop"}]}
            ) as resp:
                await resp.json()
            await asyncio.sleep(0.5)

            # 购买单位 (shop_index 0 表示第一个)
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": [{"type": "buy_unit", "shop_index": 0}]}
            ) as resp:
                result = await resp.json()
                if result.get("status") == "ok" or result.get("success"):
                    self.log(f"✅ 购买单位成功：{unit_id}")
                    return True
                else:
                    self.log(f"❌ 购买单位失败：{result}")
                    return False
        except Exception as e:
            self.log(f"❌ 购买单位异常：{e}")
            return False

    async def deploy_unit(self, unit_id: str, grid_x: int, grid_y: int) -> bool:
        """部署单位到指定坐标 - 使用 move_unit 动作"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={
                    "actions": [{
                        "type": "move_unit",
                        "from_zone": "bench",
                        "to_zone": "grid",
                        "from_pos": 0,
                        "to_pos": {"x": grid_x, "y": grid_y}
                    }]
                }
            ) as resp:
                result = await resp.json()
                # 修复：检查多种成功响应格式
                if result.get("status") == "ok" or result.get("success") or "placed" in str(result).lower():
                    self.log(f"✅ 单位部署成功：{unit_id} -> ({grid_x}, {grid_y})")
                    self.validation_results["unit_deployed"] = True
                    return True
                else:
                    error_msg = result.get("error", result.get("message", "未知错误"))
                    self.log(f"❌ 单位部署失败：{unit_id} -> ({grid_x}, {grid_y}): {error_msg}")
                    return False
        except Exception as e:
            self.log(f"❌ 单位部署异常：{e}")
            return False

    async def start_wave(self) -> bool:
        """开始波次"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "start_wave"}
            ) as resp:
                result = await resp.json()
                # 修复：检查多种成功响应格式
                if result.get("status") == "ok" or result.get("success") or "Wave already" in str(result):
                    self.log("✅ 波次开始")
                    self.validation_results["wave_started"] = True
                    return True
                else:
                    self.log(f"❌ 波次开始失败：{result}")
                    return False
        except Exception as e:
            self.log(f"❌ 波次开始异常：{e}")
            return False

    async def observe_battle(self, duration=30):
        """观察战斗日志"""
        self.log(f"开始观察战斗 {duration} 秒...")

        for i in range(duration):
            try:
                # 使用 /observations 端点获取日志
                async with self.session.get(f"{self.base_url}/observations") as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        observations = data.get("observations", [])
                        for obs in observations:
                            await self.process_log(obs)
            except Exception as e:
                self.log(f"获取日志失败：{e}")
            await asyncio.sleep(1)

        self.log("战斗观察结束")

    async def process_log(self, log_entry: str):
        """处理单条日志"""
        log_text = log_entry.get("message", str(log_entry)) if isinstance(log_entry, dict) else str(log_entry)

        # 检测暴击
        if "暴击" in log_text.lower():
            self.crit_count += 1
            self.validation_results["crit_detected"] = True
            self.log(f"检测到暴击：{log_text}")

        # 检测回响触发
        if "[TOTEM_EFFECT]" in log_text and "回响" in log_text:
            self.echo_count += 1
            self.validation_results["echo_triggered"] = True
            self.log(f"✅ 检测到回响触发：{log_text}")

        # 检测回响伤害
        if "回响伤害" in log_text:
            self.validation_results["echo_damage_logged"] = True
            self.log(f"✅ 检测到回响伤害：{log_text}")

        # 记录所有相关日志
        if any(keyword in log_text for keyword in ["鹰图腾", "暴击", "回响", "echo"]):
            self.log(f"相关日志：{log_text}")

    def generate_report(self) -> str:
        """生成测试报告"""
        total = sum(self.validation_results.values())
        passed = total

        report = f"""# 鹰图腾核心机制验证测试报告 (复测 002)

## 测试信息
- 测试时间：{self.test_start_time}
- 日志文件：{self.log_file}
- HTTP 端口：{self.http_port}
- 测试任务：docs/qa_tasks/task_eagle_totem_002.md

## 验证结果

| 验证项 | 结果 |
|--------|------|
| 鹰图腾选择 | {'✅ 通过' if self.validation_results['totem_selection'] else '❌ 失败'} |
| 单位部署 | {'✅ 通过' if self.validation_results['unit_deployed'] else '❌ 失败'} |
| 波次开始 | {'✅ 通过' if self.validation_results['wave_started'] else '❌ 失败'} |
| 暴击触发 | {'✅ 通过' if self.validation_results['crit_detected'] else '❌ 失败'} |
| 回响触发 | {'✅ 通过' if self.validation_results['echo_triggered'] else '❌ 失败'} |
| 回响伤害日志 | {'✅ 通过' if self.validation_results['echo_damage_logged'] else '❌ 失败'} |

## 统计数据
- 总攻击次数：{self.total_attacks}
- 暴击次数：{self.crit_count}
- 回响触发次数：{self.echo_count}
- 回响触发率：{self.echo_count/self.crit_count*100 if self.crit_count > 0 else 0:.1f}% (基于暴击样本)

## 结论

总计：{passed}/6 验证项通过

### 分析
"""
        if self.validation_results['echo_triggered']:
            report += "- ✅ 鹰图腾暴击回响机制验证通过\n"
        elif self.validation_results['unit_deployed'] and self.validation_results['wave_started']:
            report += "- ⚠️ 单位部署成功但未检测到回响触发，可能需要更多样本或检查代码日志埋点\n"
        else:
            report += "- ❌ 测试执行失败，单位未成功部署或波次未开始\n"

        report += f"\n---\n*报告生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n"
        return report

    async def run_test(self):
        """执行测试"""
        await self.setup()
        self.log("=" * 50)
        self.log("鹰图腾核心机制复测开始 (task_eagle_totem_002)")
        self.log("=" * 50)

        # 等待服务器
        if not await self.wait_for_server():
            return self.generate_report()

        # 1. 选择鹰图腾
        self.log("\n=== 步骤 1: 选择鹰图腾 ===")
        await self.select_totem("eagle_totem")

        # 2. 购买角雕 (harpy_eagle) - 第 3 次攻击必定暴击
        self.log("\n=== 步骤 2: 购买角雕 ===")
        await self.purchase_unit("harpy_eagle")

        # 3. 部署单位到 (-1, 0) 避开核心
        self.log("\n=== 步骤 3: 部署单位 ===")
        # 尝试多个坐标
        for coord in [(-1, 0), (1, 0), (-1, -1), (1, 1)]:
            if await self.deploy_unit("harpy_eagle", coord[0], coord[1]):
                break
            await asyncio.sleep(0.5)

        # 4. 开始波次
        self.log("\n=== 步骤 4: 开始波次 ===")
        await self.start_wave()

        # 5. 观察战斗
        self.log("\n=== 步骤 5: 观察战斗 ===")
        await self.observe_battle(duration=30)

        # 生成报告
        report = self.generate_report()
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(exist_ok=True)
        report_path = report_dir / "eagle_totem_test_report_002.md"
        with open(report_path, 'w') as f:
            f.write(report)
        self.log(f"\n✅ 测试报告已保存到：{report_path}")

        await self.cleanup()
        return report


async def main():
    tester = EagleTotemRetestTester(http_port=8082)
    await tester.run_test()


if __name__ == "__main__":
    asyncio.run(main())
