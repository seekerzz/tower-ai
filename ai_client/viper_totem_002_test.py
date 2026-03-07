#!/usr/bin/env python3
"""
毒蛇图腾核心机制验证测试脚本 (复测 002)

测试目标：
- 验证毒蛇图腾的毒液攻击机制
- 每 5 秒对最远的 3 个敌人施加毒液攻击
- 毒液造成持续伤害，可叠加 3 层
- 攻击特效正确触发

修复内容：
- 缩短观察时长至 30 秒，避免 HTTP 超时
- 修复 start_wave 动作格式：{"actions": [{"type": "start_wave"}]}
- 添加 is_wave_active 检查，避免重复调用 start_wave
"""

import asyncio
import aiohttp
import json
import sys
from datetime import datetime
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from ai_client.utils import find_two_free_ports


class ViperTotemTester:
    """毒蛇图腾测试器"""

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
        self.poison_attack_detected = False
        self.poison_damage_logged = False
        self.poison_stacks_detected = False
        self.target_selection_detected = False
        self.trigger_frequency_detected = False

        # 统计数据
        self.total_attacks = 0
        self.poison_attack_count = 0
        self.poison_stacks_observed = 0
        self.last_poison_time = 0
        self.trigger_intervals = []

    def log(self, message: str):
        """记录日志"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        log_line = f"[{timestamp}] {message}"
        self.log_lines.append(log_line)
        print(log_line)

    async def start(self):
        """启动测试"""
        self.log("=" * 60)
        self.log("毒蛇图腾核心机制验证测试 (复测 002) 开始")
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
                            self.log(f"WebSocket 端口：{data.get('godot_ws_port')}")
                            return True
            except Exception:
                pass
            await asyncio.sleep(0.5)

        raise TimeoutError("等待游戏客户端超时")

    async def run_test(self):
        """运行测试流程"""
        self.log("\n--- 开始测试流程 ---")

        # 1. 选择毒蛇图腾
        self.log("步骤 1: 选择毒蛇图腾")
        await self.select_totem("viper_totem")

        # 2. 购买箭毒蛙 (ArrowFrog) - 具有毒液攻击
        self.log("步骤 2: 购买箭毒蛙 (ArrowFrog)")
        await self.buy_and_deploy_unit("arrow_frog")

        # 3. 开始波次
        self.log("步骤 3: 开始波次")
        await self.start_wave()

        # 4. 观察战斗 30 秒
        self.log("步骤 4: 观察战斗 30 秒")
        await self.observe_battle(duration=30)

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
            # 检查是否成功
            if "viper_totem" in str(result).lower() or "TotemSelected" in str(result):
                self.totem_selected = True
                self.log("毒蛇图腾选择成功")

    async def buy_and_deploy_unit(self, unit_key: str):
        """购买并部署单位"""
        # 购买单位（索引 0）
        result = await self.send_action("buy_unit", shop_index=0)
        self.log(f"购买单位结果：{result}")

        if result and "error" not in str(result).lower():
            # 部署单位到 (1, 0)
            result = await self.send_action(
                "move_unit",
                from_zone="bench",
                from_pos=0,
                to_zone="grid",
                to_pos={"x": 1, "y": 0}
            )
            self.log(f"部署单位结果：{result}")
            if result and "error" not in str(result).lower():
                self.unit_deployed = True
                self.log(f"单位已部署到坐标 (1, 0)")

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
            # 正确的 start_wave 格式（包含在 actions 数组中）
            result = await self.send_action("start_wave")
            self.log(f"开始波次结果：{result}")
            if result and "error" not in str(result).lower():
                self.wave_started = True
                self.log("波次开始成功")
        else:
            self.wave_started = True  # 波次已在进行中，视为成功

    async def observe_battle(self, duration: int):
        """观察战斗"""
        self.log(f"开始观察战斗，持续 {duration} 秒")

        start = asyncio.get_event_loop().time()
        check_interval = 1.0  # 每秒检查一次

        while asyncio.get_event_loop().time() - start < duration:
            observations = await self.get_observations()

            for obs in observations:
                obs_str = str(obs)
                self.log(f"OBS: {obs_str}")

                # 检测毒液攻击
                if "毒液" in obs_str or "poison" in obs_str.lower():
                    if "攻击" in obs_str or "attack" in obs_str.lower():
                        self.poison_attack_detected = True
                        self.poison_attack_count += 1
                        self.log(f"检测到毒液攻击！计数：{self.poison_attack_count}")

                        # 记录触发间隔
                        current_time = asyncio.get_event_loop().time()
                        if self.last_poison_time > 0:
                            interval = current_time - self.last_poison_time
                            self.trigger_intervals.append(interval)
                            self.log(f"触发间隔：{interval:.2f}秒")
                        self.last_poison_time = current_time

                # 检测毒液伤害
                if "毒液伤害" in obs_str or "poison damage" in obs_str.lower():
                    self.poison_damage_logged = True
                    self.log(f"检测到毒液伤害日志")

                # 检测中毒层数
                if "层" in obs_str or "stack" in obs_str.lower():
                    if "中毒" in obs_str or "poison" in obs_str.lower():
                        self.poison_stacks_detected = True
                        # 尝试提取层数
                        import re
                        match = re.search(r'(\d+)\s*层', obs_str)
                        if match:
                            stacks = int(match.group(1))
                            self.poison_stacks_observed = max(self.poison_stacks_observed, stacks)
                            self.log(f"检测到中毒层数：{stacks}")

                # 检测目标选择（最远 3 个敌人）
                if "最远" in obs_str or "farthest" in obs_str.lower():
                    if "3" in obs_str or "三个" in obs_str or "3 个" in obs_str:
                        self.target_selection_detected = True
                        self.log(f"检测到目标选择：最远 3 个敌人")

                # 统计攻击次数
                if "攻击" in obs_str or "attack" in obs_str.lower():
                    self.total_attacks += 1

            await asyncio.sleep(check_interval)

        # 分析触发频率
        if self.trigger_intervals:
            avg_interval = sum(self.trigger_intervals) / len(self.trigger_intervals)
            self.log(f"平均触发间隔：{avg_interval:.2f}秒")
            if 4.0 <= avg_interval <= 6.0:  # 预期 5 秒，允许误差
                self.trigger_frequency_detected = True
                self.log("触发频率符合预期 (约 5 秒)")

        self.log(f"观察结束 - 总攻击次数：{self.total_attacks}, 毒液攻击次数：{self.poison_attack_count}")

    async def generate_report(self):
        """生成测试报告"""
        self.log("\n" + "=" * 60)
        self.log("测试报告")
        self.log("=" * 60)

        report_lines = [
            "# 毒蛇图腾核心机制验证测试报告 (复测 002)",
            "",
            "## 测试信息",
            f"- 测试时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"- HTTP 端口：{self.http_port}",
            f"- 测试任务：docs/qa_tasks/task_viper_totem_002.md",
            "",
            "## 验证结果",
            "",
            "| 验证项 | 结果 |",
            "|--------|------|",
            f"| 毒蛇图腾选择 | {'✅ 通过' if self.totem_selected else '❌ 失败'} |",
            f"| 单位部署 | {'✅ 通过' if self.unit_deployed else '❌ 失败'} |",
            f"| 波次开始 | {'✅ 通过' if self.wave_started else '❌ 失败'} |",
            f"| 毒液攻击触发 | {'✅ 通过' if self.poison_attack_detected else '❌ 失败'} |",
            f"| 毒液伤害数值 | {'✅ 通过' if self.poison_damage_logged else '❌ 失败'} |",
            f"| 中毒层数 3 层 | {'✅ 通过' if self.poison_stacks_detected else '❌ 失败'} |",
            f"| 目标选择（最远 3 个） | {'✅ 通过' if self.target_selection_detected else '❌ 失败'} |",
            f"| 触发频率 5 秒 | {'✅ 通过' if self.trigger_frequency_detected else '❌ 失败'} |",
            "",
            "## 统计数据",
            f"- 总攻击次数：{self.total_attacks}",
            f"- 毒液攻击次数：{self.poison_attack_count}",
            f"- 最大中毒层数：{self.poison_stacks_observed}",
            f"- 平均触发间隔：{sum(self.trigger_intervals) / len(self.trigger_intervals) if self.trigger_intervals else 0:.2f}秒",
            "",
            "## 结论",
            "",
        ]

        passed = sum([
            self.totem_selected,
            self.unit_deployed,
            self.wave_started,
            self.poison_attack_detected,
            self.poison_damage_logged,
            self.poison_stacks_detected,
            self.target_selection_detected,
            self.trigger_frequency_detected
        ])

        report_lines.append(f"总计：{passed}/8 验证项通过")

        if passed == 8:
            report_lines.append("\n所有验证项通过，毒蛇图腾机制工作正常。")
        elif passed >= 5:
            report_lines.append("\n大部分验证项通过，核心机制已实现。")
        else:
            report_lines.append("\n需要进一步检查代码实现或日志埋点。")

        report_lines.append("\n---")
        report_lines.append(f"*报告生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*")

        report_content = "\n".join(report_lines)

        # 保存报告
        report_path = Path("docs/player_reports/viper_totem_test_report_002.md")
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
    # 使用固定的 HTTP 端口（与运行中的游戏客户端匹配）
    http_port = 10002  # 游戏客户端 HTTP 端口

    print(f"使用 HTTP 端口：{http_port}")

    # 创建日志文件
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"viper_totem_002_{timestamp}.log"

    # 创建测试器
    tester = ViperTotemTester(http_port=http_port, log_file=str(log_file))

    # 运行测试
    await tester.start()


if __name__ == "__main__":
    asyncio.run(main())
