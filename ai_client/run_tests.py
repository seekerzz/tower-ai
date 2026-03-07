#!/usr/bin/env python3
"""
测试运行脚本 - 启动游戏客户端并执行测试
"""

import subprocess
import sys
import time
import signal
import os
from pathlib import Path

def run_test(test_name: str, test_script: str):
    """运行单个测试"""
    print(f"\n{'='*60}")
    print(f"开始测试：{test_name}")
    print(f"测试脚本：{test_script}")
    print(f"{'='*60}\n")

    # 1. 启动游戏客户端
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

    # 2. 等待客户端就绪
    print("等待游戏客户端就绪...")
    time.sleep(5)  # 等待启动

    # 检查进程是否还在运行
    if godot_process.poll() is not None:
        print("游戏客户端启动失败")
        stdout, _ = godot_process.communicate()
        print(stdout)
        return False

    # 3. 运行测试脚本
    print("运行测试脚本...")
    test_process = subprocess.Popen(
        [sys.executable, test_script],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
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
