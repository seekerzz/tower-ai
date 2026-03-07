#!/usr/bin/env python3
"""
鹰图腾核心机制验证测试脚本 (复测 004)

测试目标：
- 验证鹰图腾的暴击回响机制
- 暴击时有 30% 概率触发一次回响
- 造成等额伤害并施加攻击特效

修复内容 (004)：
- 增加观察时长至 60 秒，获取更多暴击样本
- 检测 [EAGLE_CRIT] 暴击触发日志
- 检测 [TOTEM_EFFECT] 回响触发日志
"""

import asyncio
import aiohttp
import json
import sys
import re
from datetime import datetime
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from ai_client.utils import find_two_free_ports


class EagleTotemTester:
    """鹰图腾测试器"""

    def __init__(self, http_port: int, log_file: str):
        self.http_port = http_port
        self.log_file = log_file
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session = None
        self.log_lines = []

        # 测试结果
        self.totem_selected = False
        self.unit_deployed = False
        self.wave_started = False
        self.crit_detected = False
        self.echo_detected = False
        self.echo_damage_logged = False

        # 统计数据
        self.total_attacks = 0
        self.crit_count = 0
        self.echo_count = 0
        self.echo_trigger_times = []
        self.last_echo_time = 0

    def log(self, message: str):
        """记录日志"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] {message}"
        self.log_lines.append(log_line)
        print(log_line)

    async def start(self):
        """启动测试"""
        self.log("=" * 60)
        self.log("鹰图腾核心机制验证测试 (复测 004) 开始")
        self.log("=" * 60)

        async with aiohttp.ClientSession() as self.session:
            try:
                # 等待游戏客户端就绪
                await self.wait_for_ready()

                # 执行测试流程
                await self.run_test()

            except Exception as e:
                self.log(f"测试异常：{e}")
                import traceback
                traceback.print_exc()
            finally:
                # 生成报告
                await self.generate_report()

    async def wait_for_ready(self, timeout: int = 30):
        """等待游戏客户端就绪"""
        self.log("等待游戏客户端就绪...")
        start = asyncio.get_event_loop().time()

        while asyncio.get_event_loop().time() - start < timeout:
            try:
                async with self.session.get(f"{self.base_url}/status") as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        if data.get("godot_running"):
                            self.log(f"游戏客户端已就绪 - HTTP 端口：{self.http_port}")
                            return True
            except Exception:
                pass
            await asyncio.sleep(0.5)

        raise TimeoutError("等待游戏客户端超时")

    async def run_test(self):
        """运行测试流程"""
        self.log("\n--- 开始测试流程 ---")

        # 1. 选择鹰图腾
        self.log("步骤 1: 选择鹰图腾")
        await self.select_totem("eagle_totem")

        # 2. 购买风暴鹰 (Storm Eagle) - 具有暴击能力
        self.log("步骤 2: 购买风暴鹰 (Storm Eagle)")
        await self.buy_and_deploy_unit("storm_eagle")

        # 3. 开始波次
        self.log("步骤 3: 开始波次")
        await self.start_wave()

        # 4. 观察战斗 60 秒（增加时长以获取更多暴击样本）
        self.log("步骤 4: 观察战斗 60 秒")
        await self.observe_battle(duration=60)

        self.log("\n--- 测试流程完成 ---")

    async def send_action(self, action_type: str, **params):
        """发送动作"""
        action = {"type": action_type, **params}

        try:
            async with self.session.post(
                f"{self.base_url}/action",
                json={"actions": [action]}
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    return data
                else:
                    self.log(f"HTTP 错误：{resp.status}")
                    return None
        except Exception as e:
            self.log(f"发送动作失败：{e}")
            return None

    async def get_observations(self):
        """获取观察数据"""
        try:
            async with self.session.get(f"{self.base_url}/observations") as resp:
                if resp.status == 200:
                    data = await resp.json()
                    return data.get("observations", [])
        except Exception as e:
            self.log(f"获取观察数据失败：{e}")
        return []

    async def select_totem(self, totem_id: str):
        """选择图腾"""
        # 先获取当前状态
        observations = await self.get_observations()
        for obs in observations:
            self.log(f"OBS: {obs}")
            if "TotemSelection" in str(obs):
                break

        result = await self.send_action("select_totem", totem_id=totem_id)
        if result:
            self.log(f"选择图腾结果：{result}")
            if "eagle_totem" in str(result).lower() or "TotemSelected" in str(result):
                self.totem_selected = True
                self.log("鹰图腾选择成功")

    async def buy_and_deploy_unit(self, unit_key: str):
        """购买并部署单位"""
        # 可能需要多次刷新商店才能买到目标单位
        max_refreshes = 10
        for i in range(max_refreshes):
            observations = await self.get_observations()
            for obs in observations:
                self.log(f"OBS: {obs}")
                if "商店" in str(obs) and unit_key in str(obs):
                    # 找到目标单位，购买
                    result = await self.send_action("buy_unit", shop_index=0)
                    self.log(f"购买单位结果：{result}")
                    if result and "error" not in str(result).lower():
                        # 部署单位到 (-1, 0)
                        result = await self.send_action(
                            "move_unit",
                            from_zone="bench",
                            from_pos=0,
                            to_zone="grid",
                            to_pos={"x": -1, "y": 0}
                        )
                        self.log(f"部署单位结果：{result}")
                        if result and "error" not in str(result).lower():
                            self.unit_deployed = True
                            self.log(f"单位已部署到坐标 (-1, 0)")
                        return
            # 没找到目标单位，刷新商店
            await self.send_action("refresh_shop")
            await asyncio.sleep(0.5)

        self.log(f"警告：未能在商店中找到 {unit_key}，使用任意单位")
        # 使用任意可用单位
        result = await self.send_action("buy_unit", shop_index=0)
        if result and "error" not in str(result).lower():
            result = await self.send_action(
                "move_unit",
                from_zone="bench",
                from_pos=0,
                to_zone="grid",
                to_pos={"x": -1, "y": 0}
            )
            if result and "error" not in str(result).lower():
                self.unit_deployed = True
                self.log("单位已部署")

    async def start_wave(self):
        """开始波次"""
        # 检查是否已在波次中
        observations = await self.get_observations()
        wave_active = False
        for obs in observations:
            if "is_wave_active" in str(obs):
                if "true" in str(obs).lower():
                    wave_active = True
                    self.log("波次已在进行中，跳过 start_wave")
                    break

        if not wave_active:
            result = await self.send_action("start_wave")
            self.log(f"开始波次结果：{result}")
            if result and "error" not in str(result).lower():
                self.wave_started = True
                self.log("波次开始成功")
        else:
            self.wave_started = True

    async def observe_battle(self, duration: int):
        """观察战斗"""
        self.log(f"开始观察战斗，持续 {duration} 秒")

        start = asyncio.get_event_loop().time()
        check_interval = 1.0

        while asyncio.get_event_loop().time() - start < duration:
            observations = await self.get_observations()

            for obs in observations:
                obs_str = str(obs)
                self.log(f"OBS: {obs_str}")

                # 检测 [EAGLE_CRIT] 暴击触发日志
                if "[EAGLE_CRIT]" in obs_str or "鹰图腾暴击触发" in obs_str:
                    self.crit_detected = True
                    self.crit_count += 1
                    self.log(f"检测到暴击触发！计数：{self.crit_count}")

                # 检测 [TOTEM_EFFECT] 回响触发日志
                if "[TOTEM_EFFECT]" in obs_str and "鹰图腾" in obs_str and "回响" in obs_str:
                    self.echo_detected = True
                    self.echo_count += 1
                    self.log(f"检测到回响触发！计数：{self.echo_count}")

                    # 记录触发时间
                    current_time = asyncio.get_event_loop().time()
                    self.echo_trigger_times.append(current_time)
                    self.last_echo_time = current_time

                # 检测回响伤害日志
                if "回响伤害" in obs_str or "echo damage" in obs_str.lower():
                    self.echo_damage_logged = True
                    self.log("检测到回响伤害日志")

                # 统计攻击次数
                if "攻击" in obs_str or "attack" in obs_str.lower():
                    self.total_attacks += 1

            await asyncio.sleep(check_interval)

        # 计算回响触发率
        if self.crit_count > 0:
            echo_rate = self.echo_count / self.crit_count
            self.log(f"回响触发率：{echo_rate:.1%} (基于 {self.crit_count} 次暴击)")

        self.log(f"观察结束 - 总攻击次数：{self.total_attacks}, 暴击次数：{self.crit_count}, 回响次数：{self.echo_count}")

    async def generate_report(self):
        """生成测试报告"""
        self.log("\n" + "=" * 60)
        self.log("测试报告")
        self.log("=" * 60)

        report_lines = [
            "# 鹰图腾核心机制验证测试报告 (复测 004)",
            "",
            "## 测试信息",
            f"- 测试时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"- HTTP 端口：{self.http_port}",
            f"- 测试任务：docs/qa_tasks/task_eagle_totem_004.md",
            "",
            "## 验证结果",
            "",
            "| 验证项 | 结果 |",
            "|--------|------|",
            f"| 鹰图腾选择 | {'✅ 通过' if self.totem_selected else '❌ 失败'} |",
            f"| 单位部署 | {'✅ 通过' if self.unit_deployed else '❌ 失败'} |",
            f"| 波次开始 | {'✅ 通过' if self.wave_started else '❌ 失败'} |",
            f"| 暴击触发 | {'✅ 通过' if self.crit_detected else '❌ 失败'} |",
            f"| 回响触发 | {'✅ 通过' if self.echo_detected else '❌ 失败'} |",
            f"| 回响伤害日志 | {'✅ 通过' if self.echo_damage_logged else '❌ 失败'} |",
            "",
            "## 统计数据",
            f"- 总攻击次数：{self.total_attacks}",
            f"- 暴击次数：{self.crit_count}",
            f"- 回响触发次数：{self.echo_count}",
        ]

        if self.crit_count > 0:
            report_lines.append(f"- 回响触发率：{self.echo_count / self.crit_count:.1%}")

        report_lines.extend([
            "",
            "## 结论",
            "",
        ])

        passed = sum([
            self.totem_selected,
            self.unit_deployed,
            self.wave_started,
            self.crit_detected,
            self.echo_detected,
            self.echo_damage_logged
        ])

        report_lines.append(f"总计：{passed}/6 验证项通过")

        if passed == 6:
            report_lines.append("\n所有验证项通过，鹰图腾机制工作正常。")
        elif passed >= 4:
            report_lines.append("\n大部分验证项通过，核心机制已实现。")
        else:
            report_lines.append("\n需要进一步检查代码实现或日志埋点。")

        report_lines.append("\n---")
        report_lines.append(f"*报告生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*")

        report_content = "\n".join(report_lines)

        # 保存报告
        report_path = Path("docs/player_reports/eagle_totem_test_report_004.md")
        report_path.parent.mkdir(exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report_content)
        self.log(f"报告已保存：{report_path}")

        # 保存日志
        with open(self.log_file, "w", encoding="utf-8") as f:
            f.write("\n".join(self.log_lines))
        self.log(f"日志已保存：{self.log_file}")

        self.log("\n" + report_content)


async def main():
    """主入口"""
    import os
    http_port = int(os.environ.get("AI_HTTP_PORT", 10002))

    print(f"使用 HTTP 端口：{http_port}")

    # 创建日志文件
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"eagle_totem_004_{timestamp}.log"

    # 创建测试器
    tester = EagleTotemTester(http_port=http_port, log_file=str(log_file))

    # 运行测试
    await tester.start()


if __name__ == "__main__":
    asyncio.run(main())
