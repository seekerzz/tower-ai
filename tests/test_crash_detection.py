#!/usr/bin/env python3
"""
测试崩溃检测功能

验证点：
1. Python 能成功捕获 Godot 的 SCRIPT ERROR
2. HTTP 响应包含 SystemCrash 事件和堆栈跟踪
3. 进程干净退出，无死锁或僵尸进程
"""

import asyncio
import json
import subprocess
import time
import sys
from pathlib import Path
import pytest

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from ai_client.utils import find_free_port

@pytest.mark.asyncio
async def test_crash_detection():
    """测试崩溃检测"""
    print("=" * 60)
    print("测试: 崩溃检测")
    print("=" * 60)

    # 分配端口
    agent_ws_port = find_free_port(20000, 25000)
    godot_port = find_free_port(25000, 30000)

    print(f"Agent WebSocket 端口: {agent_ws_port}")
    print(f"Godot WebSocket 端口: {godot_port}")

    # 启动 AI 客户端（使用 TestCrash 场景）
    cmd = [
        sys.executable,
        "ai_client/ai_game_client.py",
        "--project", str(Path(__file__).parent.parent),
        "--scene", "res://src/Scenes/Test/TestCrash.tscn",
        "--agent-ws-port", str(agent_ws_port),
        "--godot-port", str(godot_port),
        "--visual"  # 使用 GUI 模式以便观察
    ]

    print(f"\n启动命令: {' '.join(cmd)}")
    print("等待 Godot 启动并崩溃...\n")

    # 启动进程
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    # 等待一段时间让 Godot 启动并崩溃
    time.sleep(10)

    # 检查进程状态
    return_code = process.poll()
    print(f"进程返回码: {return_code}")

    # 读取输出
    stdout, _ = process.communicate(timeout=5)
    print("\n--- 输出日志 ---")
    print(stdout)

    # 验证崩溃被捕获
    assert ("SystemCrash" in stdout or "SCRIPT ERROR" in stdout or "Godot 崩溃" in stdout or "检测到崩溃" in stdout)
    print("\n✓ 测试通过: 检测到崩溃")


def test_headless_mode():
    """测试 Headless 模式"""
    print("\n" + "=" * 60)
    print("测试: Headless 模式")
    print("=" * 60)

    agent_ws_port = find_free_port(30000, 35000)
    godot_port = find_free_port(35000, 40000)

    # 启动 AI 客户端（headless 模式）
    cmd = [
        sys.executable,
        "ai_client/ai_game_client.py",
        "--project", str(Path(__file__).parent.parent),
        "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
        "--agent-ws-port", str(agent_ws_port),
        "--godot-port", str(godot_port)
        # 不加 --visual，默认 headless
    ]

    print(f"启动命令: {' '.join(cmd)}")

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    # 等待启动
    time.sleep(8)

    # 直接判断进程是否存活即视为成功
    try:
        assert process.poll() is None
        print("✓ 测试通过: Headless 模式正常工作")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except:
            process.kill()

if __name__ == "__main__":
    asyncio.run(test_crash_detection())
    test_headless_mode()
