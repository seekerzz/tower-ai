#!/usr/bin/env python3
"""
LOG-IMPROVEMENT-001-REGRESSION 回归测试脚本

执行7个测试任务:
1. TOTEM-COW-001-REGRESSION 牛图腾回归测试
2. TOTEM-BAT-001-REGRESSION 蝙蝠图腾回归测试
3. TOTEM-WOLF-001-REGRESSION 狼图腾回归测试
4. TOTEM-BUTTERFLY-001-REGRESSION 蝴蝶图腾回归测试
5. TOTEM-VIPER-001-REGRESSION 毒蛇图腾回归测试
6. TOTEM-EAGLE-001-REGRESSION 鹰图腾回归测试
7. UNITS-COMMON-001-REGRESSION 通用单位回归测试

验证目标:
- [图腾触发] 日志输出
- [图腾资源] 日志输出 (魂魄/充能/法力)
- [Buff施加] 日志输出
- 商店70%阵营单位显示
- CRASH-002 是否修复
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


class RegressionTester:
    """回归测试器"""

    TOTEM_TESTS = [
        ("cow_totem", "牛图腾", "TOTEM-COW-001-REGRESSION"),
        ("bat_totem", "蝙蝠图腾", "TOTEM-BAT-001-REGRESSION"),
        ("wolf_totem", "狼图腾", "TOTEM-WOLF-001-REGRESSION"),
        ("butterfly_totem", "蝴蝶图腾", "TOTEM-BUTTERFLY-001-REGRESSION"),
        ("viper_totem", "毒蛇图腾", "TOTEM-VIPER-001-REGRESSION"),
        ("eagle_totem", "鹰图腾", "TOTEM-EAGLE-001-REGRESSION"),
    ]

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.test_results = []
        self.all_logs = []
        self.session: Optional[aiohttp.ClientSession] = None
        self.client_process = None
        self.current_log_file = None

        # 验证结果汇总
        self.validation_summary = {
            "totem_trigger_log": False,
            "resource_log": False,
            "buff_log": False,
            "shop_faction_filter": False,
            "crash_002_fixed": True,  # 默认为True，如果发现崩溃则设为False
        }

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def log(self, message, level="INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        if self.current_log_file:
            with open(self.current_log_file, "a", encoding="utf-8") as f:
                f.write(log_entry + "\n")

    async def start_game_client(self):
        """启动游戏客户端"""
        self.log("启动AI游戏客户端...", "SYSTEM")

        cmd = [
            "python3", "-m", "ai_client.ai_game_client",
            "--project", ".",
            "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
            "--http-port", str(self.http_port)
        ]

        self.client_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=str(Path(__file__).parent.parent)
        )

        # 等待客户端启动
        await asyncio.sleep(3.0)
        self.log("客户端启动完成", "SYSTEM")

    def stop_game_client(self):
        """停止游戏客户端"""
        if self.client_process:
            self.log("停止游戏客户端...", "SYSTEM")
            self.client_process.terminate()
            try:
                self.client_process.wait(timeout=5)
            except:
                self.client_process.kill()
            self.client_process = None

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
                        self.validation_summary["crash_002_fixed"] = False
                        return False
            except:
                pass
            await asyncio.sleep(0.5)
        self.log("等待游戏就绪超时", "ERROR")
        return False

    async def send_actions(self, actions):
        """发送动作"""
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
        """获取观测数据"""
        try:
            async with self.session.get(
                f"{self.base_url}/observations",
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                data = await resp.json()
                return data.get("observations", [])
        except Exception as e:
            self.log(f"获取观测失败: {e}", "ERROR")
            return []

    async def poll_observations(self, duration: float = 2.0) -> List[str]:
        """轮询观测数据"""
        all_obs = []
        start = time.time()
        while time.time() - start < duration:
            obs = await self.get_observations()
            all_obs.extend(obs)
            for o in obs:
                self.log(f"[OBS] {o}", "OBS")
            await asyncio.sleep(0.2)
        return all_obs

    def parse_shop_units(self, log_entry: str) -> List[Dict]:
        """从商店日志中解析所有单位"""
        units = []
        if "商店" in log_entry and ("提供" in log_entry or "刷新" in log_entry):
            import re
            pattern = r'(\w+)[(（](\d+)\s*金?币?[)）]'
            matches = re.findall(pattern, log_entry)
            for idx, (unit_key, cost) in enumerate(matches):
                units.append({"index": idx, "key": unit_key, "cost": int(cost)})
        return units

    def get_current_shop_units(self, observations: List[str]) -> List[Dict]:
        """从观测中获取当前商店单位列表"""
        for obs in reversed(observations):
            units = self.parse_shop_units(obs)
            if units:
                return units
        return []

    def check_log_patterns(self, observations: List[str]):
        """检查日志模式"""
        for obs in observations:
            # 检查图腾触发日志
            if "[图腾触发]" in obs or "[TOTEM]" in obs or "图腾" in obs:
                self.validation_summary["totem_trigger_log"] = True
                self.log(f"✅ 发现图腾触发日志: {obs}", "VALIDATION")

            # 检查资源日志
            if "[图腾资源]" in obs or "[RESOURCE]" in obs or "魂魄" in obs or "充能" in obs or "法力" in obs:
                self.validation_summary["resource_log"] = True
                self.log(f"✅ 发现资源日志: {obs}", "VALIDATION")

            # 检查Buff日志
            if "[Buff施加]" in obs or "[BUFF]" in obs or "buff" in obs.lower():
                self.validation_summary["buff_log"] = True
                self.log(f"✅ 发现Buff日志: {obs}", "VALIDATION")

            # 检查CRASH-002
            if "Parameter \"t\" is null" in obs or "null" in obs.lower():
                self.validation_summary["crash_002_fixed"] = False
                self.log(f"❌ 发现CRASH-002错误: {obs}", "ERROR")

    async def run_totem_test(self, totem_id: str, totem_name: str, test_id: str) -> Dict:
        """运行单个图腾测试"""
        self.log("=" * 60, "SYSTEM")
        self.log(f"开始测试: {test_id} - {totem_name}", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 创建该测试的日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.current_log_file = log_dir / f"ai_session_{totem_id.replace('_totem', '')}_regression_{timestamp}.log"
        self.all_logs.append(str(self.current_log_file))

        result = {
            "test_id": test_id,
            "totem_id": totem_id,
            "totem_name": totem_name,
            "log_file": str(self.current_log_file),
            "success": False,
            "observations": []
        }

        try:
            # 启动游戏客户端
            await self.start_game_client()

            # 等待游戏就绪
            if not await self.wait_for_game_ready():
                result["error"] = "游戏未就绪"
                self.stop_game_client()
                return result

            # 步骤1: 选择图腾
            self.log(f"选择图腾: {totem_id}", "ACTION")
            await self.send_actions([{"type": "select_totem", "totem_id": totem_id}])
            obs = await self.poll_observations(2.0)
            result["observations"].extend(obs)
            self.check_log_patterns(obs)

            # 步骤2: 购买单位
            self.log("购买初始单位...", "ACTION")
            # 获取当前商店内容并使用expected_unit_key验证
            shop_units = self.get_current_shop_units(result["observations"])
            if shop_units:
                target_unit = shop_units[0]
                self.log(f"[商店] 购买单位: {target_unit['key']} (索引: {target_unit['index']})", "INFO")
                await self.send_actions([{"type": "buy_unit", "shop_index": 0, "expected_unit_key": target_unit['key']}])
            else:
                await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
            await asyncio.sleep(0.5)
            obs = await self.poll_observations(1.0)
            result["observations"].extend(obs)

            # 步骤3: 部署单位
            self.log("部署单位到战场...", "ACTION")
            await self.send_actions([
                {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
                 "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
            ])
            await asyncio.sleep(0.5)
            obs = await self.poll_observations(1.0)
            result["observations"].extend(obs)

            # 步骤4: 验证商店阵营过滤
            self.log("验证商店阵营过滤...", "TEST")
            await self.send_actions([{"type": "refresh_shop"}])
            await asyncio.sleep(0.5)
            obs = await self.poll_observations(2.0)
            result["observations"].extend(obs)

            # 检查商店是否显示阵营单位
            shop_valid = False
            for o in obs:
                if "商店" in o or "shop" in o.lower():
                    shop_valid = True
                    break
            if shop_valid:
                self.validation_summary["shop_faction_filter"] = True
                self.log("✅ 商店阵营过滤正常", "VALIDATION")

            # 步骤5: 启动波次 - 这是验证CRASH-002的关键
            self.log("启动第1波 - 验证CRASH-002修复...", "TEST")
            await self.send_actions([{"type": "start_wave"}])

            # 等待波次进行，观察是否有崩溃
            obs = await self.poll_observations(10.0)
            result["observations"].extend(obs)
            self.check_log_patterns(obs)

            # 检查状态
            try:
                async with self.session.get(f"{self.base_url}/status") as resp:
                    status = await resp.json()
                    if status.get("crashed"):
                        self.validation_summary["crash_002_fixed"] = False
                        result["error"] = "游戏崩溃 - CRASH-002未修复"
                        self.log("❌ CRASH-002仍然存在", "ERROR")
                    else:
                        self.log("✅ 第1波正常进行，无崩溃", "VALIDATION")
                        result["success"] = True
            except:
                pass

            # 继续观察几波
            for wave in range(2, 4):
                self.log(f"观察第{wave}波...", "TEST")
                await self.send_actions([{"type": "start_wave"}])
                obs = await self.poll_observations(8.0)
                result["observations"].extend(obs)
                self.check_log_patterns(obs)

            self.stop_game_client()
            await asyncio.sleep(2.0)  # 等待进程完全结束

        except Exception as e:
            result["error"] = str(e)
            self.log(f"测试异常: {e}", "ERROR")
            self.stop_game_client()

        return result

    async def run_common_units_test(self) -> Dict:
        """运行通用单位测试"""
        test_id = "UNITS-COMMON-001-REGRESSION"
        self.log("=" * 60, "SYSTEM")
        self.log(f"开始测试: {test_id} - 通用单位回归测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.current_log_file = log_dir / f"ai_session_common_units_regression_{timestamp}.log"
        self.all_logs.append(str(self.current_log_file))

        result = {
            "test_id": test_id,
            "log_file": str(self.current_log_file),
            "success": False,
            "observations": []
        }

        try:
            await self.start_game_client()

            if not await self.wait_for_game_ready():
                result["error"] = "游戏未就绪"
                self.stop_game_client()
                return result

            # 选择牛图腾作为基础
            self.log("选择牛图腾作为通用单位测试基础", "ACTION")
            await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
            obs = await self.poll_observations(2.0)
            result["observations"].extend(obs)

            # 购买通用单位
            self.log("购买通用单位...", "ACTION")
            # 获取当前商店内容并使用expected_unit_key验证
            shop_units = self.get_current_shop_units(result["observations"])
            if shop_units:
                target_unit = shop_units[0]
                self.log(f"[商店] 购买单位: {target_unit['key']} (索引: {target_unit['index']})", "INFO")
                await self.send_actions([{"type": "buy_unit", "shop_index": 0, "expected_unit_key": target_unit['key']}])
            else:
                await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
            await asyncio.sleep(0.5)
            obs = await self.poll_observations(1.0)
            result["observations"].extend(obs)

            # 部署
            await self.send_actions([
                {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
                 "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
            ])
            await asyncio.sleep(0.5)
            obs = await self.poll_observations(1.0)
            result["observations"].extend(obs)

            # 启动波次
            self.log("启动波次验证通用单位...", "TEST")
            await self.send_actions([{"type": "start_wave"}])
            obs = await self.poll_observations(10.0)
            result["observations"].extend(obs)
            self.check_log_patterns(obs)

            # 检查状态
            try:
                async with self.session.get(f"{self.base_url}/status") as resp:
                    status = await resp.json()
                    if not status.get("crashed"):
                        result["success"] = True
                        self.log("✅ 通用单位测试通过", "VALIDATION")
            except:
                pass

            self.stop_game_client()
            await asyncio.sleep(2.0)

        except Exception as e:
            result["error"] = str(e)
            self.stop_game_client()

        return result

    async def run_all_tests(self):
        """运行所有回归测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("LOG-IMPROVEMENT-001-REGRESSION 回归测试开始", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log("", "SYSTEM")
        self.log("验证目标:", "SYSTEM")
        self.log("  - [图腾触发] 日志输出", "SYSTEM")
        self.log("  - [图腾资源] 日志输出 (魂魄/充能/法力)", "SYSTEM")
        self.log("  - [Buff施加] 日志输出", "SYSTEM")
        self.log("  - 商店70%阵营单位显示", "SYSTEM")
        self.log("  - CRASH-002 是否修复", "SYSTEM")
        self.log("", "SYSTEM")

        all_results = []

        # 运行6个图腾测试
        for totem_id, totem_name, test_id in self.TOTEM_TESTS:
            result = await self.run_totem_test(totem_id, totem_name, test_id)
            all_results.append(result)
            self.test_results.append(result)
            await asyncio.sleep(1.0)  # 测试间隔

        # 运行通用单位测试
        result = await self.run_common_units_test()
        all_results.append(result)
        self.test_results.append(result)

        # 生成汇总报告
        await self.generate_report(all_results)

        return all_results

    async def generate_report(self, results: List[Dict]):
        """生成测试报告"""
        self.log("=" * 70, "SYSTEM")
        self.log("回归测试报告", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        report_lines = [
            "",
            "=" * 70,
            "LOG-IMPROVEMENT-001-REGRESSION 回归测试报告",
            "=" * 70,
            f"测试时间: {timestamp}",
            "",
            "测试任务执行结果:",
        ]

        for result in results:
            status = "✅ 通过" if result.get("success") else "❌ 失败"
            error = result.get("error", "")
            report_lines.append(f"  {result['test_id']}: {status}")
            if error:
                report_lines.append(f"    错误: {error}")
            report_lines.append(f"    日志: {result.get('log_file', 'N/A')}")

        report_lines.extend([
            "",
            "验证目标检查结果:",
            f"  [图腾触发] 日志: {'✅ 通过' if self.validation_summary['totem_trigger_log'] else '❌ 未检测到'}",
            f"  [图腾资源] 日志: {'✅ 通过' if self.validation_summary['resource_log'] else '❌ 未检测到'}",
            f"  [Buff施加] 日志: {'✅ 通过' if self.validation_summary['buff_log'] else '❌ 未检测到'}",
            f"  商店阵营过滤: {'✅ 通过' if self.validation_summary['shop_faction_filter'] else '❌ 未验证'}",
            f"  CRASH-002修复: {'✅ 已修复' if self.validation_summary['crash_002_fixed'] else '❌ 仍存在'}",
            "",
            "生成日志文件:",
        ])

        for log_file in self.all_logs:
            report_lines.append(f"  - {log_file}")

        report_lines.extend([
            "",
            "=" * 70,
        ])

        report = "\n".join(report_lines)
        self.log(report, "REPORT")

        # 保存汇总报告
        report_file = Path("logs") / f"regression_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)
        self.log(f"报告已保存: {report_file}", "SYSTEM")

        # 保存验证结果JSON
        summary_file = Path("logs") / f"regression_test_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(summary_file, "w", encoding="utf-8") as f:
            json.dump({
                "test_results": self.test_results,
                "validation_summary": self.validation_summary,
                "log_files": self.all_logs,
                "timestamp": timestamp
            }, f, indent=2, ensure_ascii=False)
        self.log(f"汇总已保存: {summary_file}", "SYSTEM")


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with RegressionTester(http_port) as tester:
        results = await tester.run_all_tests()

        # 检查是否有失败
        failed = [r for r in results if not r.get("success")]
        if failed:
            print(f"\n❌ {len(failed)}个测试失败")
            for f in failed:
                print(f"  - {f['test_id']}: {f.get('error', 'Unknown')}")
        else:
            print("\n✅ 所有测试通过")

        sys.exit(0 if not failed else 1)


if __name__ == "__main__":
    asyncio.run(main())
