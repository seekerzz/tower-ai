#!/usr/bin/env python3
"""
测试运行脚本 - 启动游戏客户端并执行测试
"""

import os
import subprocess
import sys
import time
import aiohttp
import asyncio
from pathlib import Path


def run_test(test_name: str, test_script: str):
    """运行单个测试"""
    print(f"\n{'='*60}")
    print(f"开始测试：{test_name}")
    print(f"测试脚本：{test_script}")
    print(f"{'='*60}\n")

    # 1. 启动游戏客户端（使用动态端口）
    print("启动 Godot 游戏客户端...")

    godot_process = subprocess.Popen(
        [
            sys.executable,
            "ai_client/ai_game_client.py",
            "--project", "/home/zhangzhan/tower-ai",
            "--scene", "res://src/Scenes/UI/CoreSelection.tscn"
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    print(f"Godot 客户端 PID: {godot_process.pid}")

    # 2. 等待客户端就绪（检测端口）
    print("等待游戏客户端就绪...")

    max_wait = 30  # 最长等待 30 秒
    http_port = None

    for i in range(max_wait):
        try:
            # 从 Godot 进程输出中查找 HTTP 端口
            # Godot 启动后会打印 "HTTP API: http://127.0.0.1:{port}"
            recent_output = godot_process.stdout.readline().strip()
            if recent_output:
                print(recent_output)
                if "HTTP API:" in recent_output:
                    # 提取端口号
                    import re
                    match = re.search(r'http://127\.0\.0\.1:(\d+)', recent_output)
                    if match:
                        http_port = int(match.group(1))
                        print(f"检测到 HTTP 端口：{http_port}")
                        break
        except:
            pass
        time.sleep(0.5)

    # 如果从输出中未找到端口，尝试通过轮询状态接口发现
    if not http_port:
        # 尝试常见端口范围
        for port in range(10000, 11000):
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    async def check_port(p):
                        async with aiohttp.ClientSession() as session:
                            async with session.get(f"http://127.0.0.1:{p}/status", timeout=1) as resp:
                                if resp.status == 200:
                                    data = await resp.json()
                                    if data.get("godot_running"):
                                        return p
                                return None
                    result = loop.run_until_complete(check_port(port))
                    if result:
                        http_port = port
                        print(f"发现运行中的 HTTP 端口：{http_port}")
                        break
                except:
                    pass
                finally:
                    loop.close()
            except:
                pass
        else:
            print("等待游戏客户端就绪超时 - 未找到 HTTP 端口")

    # 检查进程是否还在运行
    if godot_process.poll() is not None:
        print("游戏客户端启动失败")
        stdout, _ = godot_process.communicate()
        print(stdout)
        return False

    if not http_port:
        print("无法获取 HTTP 端口，测试无法继续")
        return False

    # 3. 运行测试脚本（传递 HTTP 端口环境变量）
    print(f"运行测试脚本 (HTTP 端口：{http_port})...")
    test_env = os.environ.copy()
    test_env["AI_HTTP_PORT"] = str(http_port)

    test_process = subprocess.Popen(
        [sys.executable, test_script],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=test_env
    )

    # 实时输出测试日志
    for line in test_process.stdout:
        print(line, end='')

    test_process.wait()

    # 4. 清理
    print("\n清理资源...")
    godot_process.terminate()
    try:
        godot_process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        godot_process.kill()

    print(f"测试完成 - 返回码：{test_process.returncode}")
    return test_process.returncode == 0


def main():
    """主函数"""
    import argparse
    import os

    parser = argparse.ArgumentParser(description="运行测试")
    parser.add_argument("--test", choices=["eagle", "viper", "both"], default="both",
                       help="运行哪个测试")

    args = parser.parse_args()

    tests = []
    if args.test in ["eagle", "both"]:
        tests.append(("鹰图腾测试", "ai_client/eagle_totem_002_test.py"))
    if args.test in ["viper", "both"]:
        tests.append(("毒蛇图腾测试", "ai_client/viper_totem_002_test.py"))

    results = []
    for test_name, test_script in tests:
        result = run_test(test_name, test_script)
        results.append((test_name, result))
        time.sleep(2)  # 测试间间隔

    # 汇总结果
    print("\n" + "="*60)
    print("测试结果汇总")
    print("="*60)

    for test_name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"{test_name}: {status}")

    all_passed = all(r for _, r in results)
    print(f"\n总体结果：{'✅ 全部通过' if all_passed else '❌ 有失败'}")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
