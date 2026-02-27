#!/usr/bin/env python3
"""
启动带图形界面的Godot游戏并运行AI客户端
可以同时看到游戏画面和AI决策日志

用法:
    python3 run_visual.py              # 运行极简AI
    python3 run_visual.py --ai full    # 运行完整AI
    python3 run_visual.py --ai cheat   # 运行带作弊的AI（快速测试）
"""

import subprocess
import sys
import time
import signal
import argparse
from pathlib import Path


def log(msg, color=""):
    """打印带颜色的日志"""
    colors = {
        "green": "\033[92m",
        "blue": "\033[94m",
        "yellow": "\033[93m",
        "red": "\033[91m",
        "end": "\033[0m"
    }
    print(f"{colors.get(color, '')}{msg}{colors['end']}")


def start_godot(project_path, scene=None, ai_mode=False):
    """启动Godot游戏（带图形界面）"""
    log("启动Godot游戏...", "blue")
    if scene:
        log(f"场景: {scene}", "blue")
    if ai_mode:
        log("AI模式: 启用", "blue")
    log("等待游戏窗口出现...", "yellow")

    # 构建命令
    cmd = ["godot", "--path", project_path]
    if scene:
        cmd.append(scene)
    if ai_mode:
        cmd.append("--ai-mode")

    # 使用Popen启动，这样不会阻塞
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    return process


def wait_for_game(timeout=30):
    """等待游戏就绪"""
    log("等待游戏初始化（WebSocket服务器启动）...", "yellow")
    time.sleep(5)  # 给Godot足够时间启动
    log("游戏应该已就绪", "green")


def run_ai_client(ai_type="minimal"):
    """运行AI客户端"""
    client_dir = Path(__file__).parent

    if ai_type == "minimal":
        script = client_dir / "example_minimal.py"
        log("运行极简AI客户端...", "blue")
    elif ai_type == "full":
        script = client_dir / "ai_game_client.py"
        log("运行完整AI客户端...", "blue")
    else:
        log(f"未知的AI类型: {ai_type}", "red")
        return None

    try:
        # 直接运行，输出显示在当前终端
        subprocess.run([sys.executable, str(script)])
    except KeyboardInterrupt:
        log("\nAI客户端被中断", "yellow")


def main():
    parser = argparse.ArgumentParser(description="启动Godot游戏并运行AI客户端")
    parser.add_argument(
        "--ai", "-a",
        choices=["minimal", "full"],
        default="minimal",
        help="选择AI客户端类型 (默认: minimal)"
    )
    parser.add_argument(
        "--wait", "-w",
        type=int,
        default=5,
        help="等待Godot启动的秒数 (默认: 5)"
    )
    parser.add_argument(
        "--project", "-p",
        default="/home/zhangzhan/tower",
        help="Godot项目路径"
    )
    parser.add_argument(
        "--scene", "-s",
        default="res://src/Scenes/UI/CoreSelection.tscn",
        help="启动场景路径 (默认: CoreSelection.tscn)"
    )
    parser.add_argument(
        "--ai-mode", "-ai",
        action="store_true",
        default=True,
        help="启用AI模式 (默认: True)"
    )

    args = parser.parse_args()

    log("=" * 60, "green")
    log("Godot AI 可视化运行工具")
    log("=" * 60, "green")
    print()

    # 检查依赖
    try:
        import websockets
    except ImportError:
        log("缺少依赖: websockets", "red")
        log("安装: pip3 install websockets", "yellow")
        sys.exit(1)

    # 启动Godot
    godot_process = start_godot(args.project, args.scene, args.ai_mode)
    log(f"Godot PID: {godot_process.pid}", "blue")
    print()

    # 等待游戏启动
    time.sleep(args.wait)
    log("游戏应该已启动，开始连接AI客户端...", "green")
    print()

    try:
        # 运行AI客户端
        run_ai_client(args.ai)
    except KeyboardInterrupt:
        log("\n收到中断信号", "yellow")
    finally:
        # 询问是否关闭Godot
        print()
        response = input("是否关闭Godot游戏? [Y/n]: ").strip().lower()
        if response in ("", "y", "yes"):
            godot_process.terminate()
            log("已关闭Godot", "green")
        else:
            log(f"Godot继续运行 (PID: {godot_process.pid})", "blue")


if __name__ == "__main__":
    main()
