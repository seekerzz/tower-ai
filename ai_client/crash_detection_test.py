#!/usr/bin/env python3
"""
崩溃检测改进验证测试

验证目标:
1. 崩溃检测是否及时 (检测到 ERROR: Parameter "t" is null)
2. 上下文收集是否完整 (前后50行日志)
3. 错误分类是否准确
4. 崩溃信息是否通过HTTP API正确返回
"""

import asyncio
import json
import time
import sys
import subprocess
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent))

import aiohttp


class CrashDetectionTester:
    """崩溃检测验证测试器"""

    def __init__(self, http_port=8082):
        self.http_port = http_port
        self.base_url = f"http://127.0.0.1:{http_port}"
        self.session: Optional[aiohttp.ClientSession] = None
        self.client_process = None
        self.test_results = {
            "crash_detected": False,
            "context_collected": False,
            "error_classified": False,
            "api_returned_crash": False,
            "crash_details": None
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
        print(f"[{timestamp}] [{level}] {message}")

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

        await asyncio.sleep(3.0)
        self.log(f"客户端PID: {self.client_process.pid}", "SYSTEM")

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
                        self.test_results["crash_detected"] = True
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

    async def get_status(self):
        """获取状态"""
        try:
            async with self.session.get(
                f"{self.base_url}/status",
                timeout=aiohttp.ClientTimeout(total=2)
            ) as resp:
                return await resp.json()
        except:
            return {}

    async def get_observations(self):
        """获取观测数据"""
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

    async def run_crash_test(self):
        """运行崩溃测试"""
        self.log("=" * 70, "SYSTEM")
        self.log("CRASH-002 崩溃检测验证测试", "SYSTEM")
        self.log("=" * 70, "SYSTEM")
        self.log("", "SYSTEM")
        self.log("测试目标:", "SYSTEM")
        self.log("  1. 验证崩溃检测是否及时", "SYSTEM")
        self.log("  2. 验证上下文收集是否完整", "SYSTEM")
        self.log("  3. 验证错误分类是否准确", "SYSTEM")
        self.log("  4. 验证HTTP API是否正确返回崩溃信息", "SYSTEM")
        self.log("", "SYSTEM")

        try:
            # 启动游戏客户端
            await self.start_game_client()

            # 等待游戏就绪
            if not await self.wait_for_game_ready():
                if self.test_results["crash_detected"]:
                    self.log("游戏启动时即崩溃", "ERROR")
                self.stop_game_client()
                return self.test_results

            # 步骤1: 选择图腾
            self.log("步骤1: 选择牛图腾 (cow_totem)", "TEST")
            await self.send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
            await asyncio.sleep(2.0)

            # 步骤2: 购买单位
            self.log("步骤2: 购买单位", "TEST")
            await self.send_actions([{"type": "buy_unit", "shop_index": 0}])
            await asyncio.sleep(1.0)

            # 步骤3: 部署单位
            self.log("步骤3: 部署单位到战场", "TEST")
            await self.send_actions([
                {"type": "move_unit", "from_zone": "bench", "to_zone": "grid",
                 "from_pos": 0, "to_pos": {"x": 1, "y": 0}}
            ])
            await asyncio.sleep(1.0)

            # 步骤4: 启动波次 - 触发CRASH-002
            self.log("步骤4: 启动第1波 - 触发CRASH-002", "TEST")
            await self.send_actions([{"type": "start_wave"}])

            # 等待崩溃发生
            self.log("等待崩溃检测...", "TEST")
            await asyncio.sleep(5.0)

            # 检查状态
            status = await self.get_status()
            self.log(f"状态检查: crashed={status.get('crashed')}", "TEST")

            if status.get("crashed"):
                self.test_results["crash_detected"] = True
                self.test_results["api_returned_crash"] = True
                self.log("✅ 崩溃检测成功 - HTTP API返回crashed=true", "VALIDATION")

            # 获取观测数据
            observations = await self.get_observations()
            self.log(f"获取到 {len(observations)} 条观测", "TEST")

            # 分析观测数据
            for obs in observations:
                if "系统严重报错" in obs or "Godot 引擎崩溃" in obs:
                    self.test_results["crash_detected"] = True
                    self.log("✅ 发现崩溃通知观测", "VALIDATION")

                    # 检查上下文
                    if "ERROR:" in obs:
                        self.test_results["error_classified"] = True
                        self.log("✅ 错误类型已分类", "VALIDATION")

                    # 检查堆栈信息
                    if "堆栈" in obs:
                        lines = obs.split("\n")
                        stack_start = False
                        stack_lines = []
                        for line in lines:
                            if "堆栈" in line:
                                stack_start = True
                                continue
                            if stack_start:
                                stack_lines.append(line)

                        self.test_results["crash_details"] = {
                            "observation_length": len(obs),
                            "stack_lines": len(stack_lines),
                            "full_observation": obs[:500]  # 前500字符
                        }

                        if len(stack_lines) > 1:
                            self.test_results["context_collected"] = True
                            self.log(f"✅ 堆栈信息包含 {len(stack_lines)} 行", "VALIDATION")
                        else:
                            self.log(f"⚠️ 堆栈信息较少 ({len(stack_lines)} 行)", "WARNING")

                    break

            # 再次检查状态
            status = await self.get_status()
            self.log(f"最终状态: godot_running={status.get('godot_running')}, crashed={status.get('crashed')}", "TEST")

            self.stop_game_client()
            await asyncio.sleep(2.0)

        except Exception as e:
            self.log(f"测试异常: {e}", "ERROR")
            import traceback
            traceback.print_exc()
            self.stop_game_client()

        return self.test_results

    def generate_report(self):
        """生成测试报告"""
        self.log("=" * 70, "SYSTEM")
        self.log("崩溃检测验证报告", "SYSTEM")
        self.log("=" * 70, "SYSTEM")

        print("\n" + "=" * 70)
        print("CRASH-002 崩溃检测验证报告")
        print("=" * 70)
        print(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()

        print("验证结果:")
        print(f"  1. 崩溃检测及时性: {'✅ 通过' if self.test_results['crash_detected'] else '❌ 失败'}")
        print(f"  2. 上下文收集完整性: {'✅ 通过' if self.test_results['context_collected'] else '❌ 失败'}")
        print(f"  3. 错误分类准确性: {'✅ 通过' if self.test_results['error_classified'] else '❌ 失败'}")
        print(f"  4. HTTP API崩溃返回: {'✅ 通过' if self.test_results['api_returned_crash'] else '❌ 失败'}")

        if self.test_results["crash_details"]:
            print()
            print("崩溃详情:")
            details = self.test_results["crash_details"]
            print(f"  观测长度: {details['observation_length']} 字符")
            print(f"  堆栈行数: {details['stack_lines']} 行")
            print()
            print("观测内容预览:")
            print(details['full_observation'])

        print()
        print("=" * 70)

        # 总结
        all_passed = all([
            self.test_results['crash_detected'],
            self.test_results['context_collected'],
            self.test_results['error_classified'],
            self.test_results['api_returned_crash']
        ])

        if all_passed:
            print("✅ 所有验证项通过 - 崩溃检测改进有效")
        else:
            print("⚠️ 部分验证项未通过 - 需要进一步改进")

        print("=" * 70)

        return all_passed


async def main():
    """主函数"""
    http_port = 8082
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    async with CrashDetectionTester(http_port) as tester:
        results = await tester.run_crash_test()
        all_passed = tester.generate_report()

        sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    asyncio.run(main())
