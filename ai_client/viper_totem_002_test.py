#!/usr/bin/env python3
"""
毒蛇图腾核心机制验证测试 (复测) - task_viper_totem_002.md

验证目标:
- 每 5 秒对距离最远的 3 个敌人降下毒液
- 造成伤害并施加 3 层中毒

修复内容:
- 缩短观察时长至 30 秒，避免 HTTP 超时
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


class ViperTotemRetestTester:
    """毒蛇图腾核心机制复测器"""

    def __init__(self, http_port=8083):
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
            "totem_attack_triggered": False,
            "poison_damage_logged": False,
            "poison_stack_3": False,
        }

        # 统计数据
        self.totem_attack_count = 0
        self.poison_applications: List[int] = []
        self.logs_collected: List[str] = []

    async def setup(self):
        """设置测试环境"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_session_viper_totem_002_{timestamp}.log"

        self.session = aiohttp.ClientSession()
        self.test_start_time = datetime.now()

        with open(self.log_file, 'w') as f:
            f.write(f"# 毒蛇图腾核心机制复测 (task_viper_totem_002)\n")
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
        """选择图腾"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "totem_selection", "totem_id": totem_id}
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
        """购买单位"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"type": "purchase", "unit_id": unit_id}
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
        """部署单位到指定坐标"""
        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={
                    "type": "place_unit",
                    "unit_id": unit_id,
                    "grid_x": grid_x,
                    "grid_y": grid_y
                }
            ) as resp:
                result = await resp.json()
                if result.get("status") == "ok" or result.get("success"):
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
                if result.get("status") == "ok" or result.get("success"):
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
        """观察战斗日志 - 缩短时长避免超时"""
        self.log(f"开始观察战斗 {duration} 秒...")
        last_log_time = time.time()

        for i in range(duration):
            try:
                async with self.session.get(f"{self.base_url}/logs") as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        logs = data.get("logs", [])
                        for log_entry in logs:
                            await self.process_log(log_entry)
                            last_log_time = time.time()
            except Exception as e:
                self.log(f"获取日志失败：{e}")

            # 如果超过 10 秒没有新日志，可能战斗已结束
            if time.time() - last_log_time > 10 and i > 15:
                self.log("检测到超过 10 秒无新日志，可能战斗已结束")
                break

            await asyncio.sleep(1)

        self.log("战斗观察结束")

    async def process_log(self, log_entry: str):
        """处理单条日志"""
        log_text = log_entry.get("message", str(log_entry)) if isinstance(log_entry, dict) else str(log_entry)

        # 检测图腾攻击触发
        if "[TOTEM]" in log_text and "毒蛇图腾" in log_text and "毒液攻击" in log_text:
            self.totem_attack_count += 1
            self.validation_results["totem_attack_triggered"] = True
            self.log(f"✅ 检测到图腾攻击触发：{log_text}")

        # 检测毒液伤害
        if "[TOTEM_DAMAGE]" in log_text and "毒液" in log_text:
            self.validation_results["poison_damage_logged"] = True
            self.log(f"✅ 检测到毒液伤害：{log_text}")

        # 检测中毒层数
        if "中毒层数" in log_text or "中毒" in log_text:
            # 尝试提取层数
            import re
            match = re.search(r'层数 [::]\s*(\d+)', log_text)
            if match:
                stack = int(match.group(1))
                self.poison_applications.append(stack)
                if stack >= 3:
                    self.validation_results["poison_stack_3"] = True
                    self.log(f"✅ 检测到 3 层中毒：{log_text}")
                else:
                    self.log(f"检测到中毒层数 {stack}: {log_text}")
            else:
                self.log(f"检测到中毒相关日志：{log_text}")

        # 记录所有相关日志
        if any(keyword in log_text for keyword in ["毒蛇", "毒液", "中毒", "viper"]):
            self.log(f"相关日志：{log_text}")

    def generate_report(self) -> str:
        """生成测试报告"""
        passed = sum(self.validation_results.values())

        report = f"""# 毒蛇图腾核心机制验证测试报告 (复测 002)

## 测试信息
- 测试时间：{self.test_start_time}
- 日志文件：{self.log_file}
- HTTP 端口：{self.http_port}
- 测试任务：docs/qa_tasks/task_viper_totem_002.md

## 验证结果

| 验证项 | 结果 |
|--------|------|
| 毒蛇图腾选择 | {'✅ 通过' if self.validation_results['totem_selection'] else '❌ 失败'} |
| 单位部署 | {'✅ 通过' if self.validation_results['unit_deployed'] else '❌ 失败'} |
| 波次开始 | {'✅ 通过' if self.validation_results['wave_started'] else '❌ 失败'} |
| 毒液攻击触发 | {'✅ 通过' if self.validation_results['totem_attack_triggered'] else '❌ 失败'} |
| 毒液伤害日志 | {'✅ 通过' if self.validation_results['poison_damage_logged'] else '❌ 失败'} |
| 中毒层数 3 层 | {'✅ 通过' if self.validation_results['poison_stack_3'] else '❌ 失败'} |

## 统计数据
- 图腾攻击触发次数：{self.totem_attack_count}
- 中毒层数观测：{self.poison_applications if self.poison_applications else '无数据'}

## 结论

总计：{passed}/6 验证项通过

### 分析
"""
        if self.validation_results['totem_attack_triggered'] and self.validation_results['poison_stack_3']:
            report += "- ✅ 毒蛇图腾核心机制验证通过\n"
        elif self.validation_results['unit_deployed'] and self.validation_results['wave_started']:
            report += "- ⚠️ 单位部署成功但未检测到完整机制，可能需要更多样本或检查代码日志埋点\n"
        else:
            report += "- ❌ 测试执行失败\n"

        if not self.validation_results['totem_attack_triggered']:
            report += "- 未检测到毒液攻击触发日志，建议检查 MechanicViperTotem.gd 代码\n"

        report += f"\n---\n*报告生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n"
        return report

    async def run_test(self):
        """执行测试"""
        await self.setup()
        self.log("=" * 50)
        self.log("毒蛇图腾核心机制复测开始 (task_viper_totem_002)")
        self.log("=" * 50)

        # 等待服务器
        if not await self.wait_for_server():
            return self.generate_report()

        # 1. 选择毒蛇图腾
        self.log("\n=== 步骤 1: 选择毒蛇图腾 ===")
        await self.select_totem("viper_totem")

        # 2. 购买毒蛇图腾单位
        self.log("\n=== 步骤 2: 购买单位 ===")
        await self.purchase_unit("viper")

        # 3. 部署单位
        self.log("\n=== 步骤 3: 部署单位 ===")
        for coord in [(-1, 0), (1, 0), (-1, -1), (1, 1)]:
            if await self.deploy_unit("viper", coord[0], coord[1]):
                break
            await asyncio.sleep(0.5)

        # 4. 开始波次
        self.log("\n=== 步骤 4: 开始波次 ===")
        await self.start_wave()

        # 5. 观察战斗 (缩短至 30 秒)
        self.log("\n=== 步骤 5: 观察战斗 ===")
        await self.observe_battle(duration=30)

        # 生成报告
        report = self.generate_report()
        report_dir = Path("docs/player_reports")
        report_dir.mkdir(exist_ok=True)
        report_path = report_dir / "viper_totem_test_report_002.md"
        with open(report_path, 'w') as f:
            f.write(report)
        self.log(f"\n✅ 测试报告已保存到：{report_path}")

        await self.cleanup()
        return report


async def main():
    tester = ViperTotemRetestTester(http_port=8083)
    await tester.run_test()


if __name__ == "__main__":
    asyncio.run(main())
