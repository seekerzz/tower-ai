#!/usr/bin/env python3
"""
鹰图腾流派测试启动脚本 (EAGLE-TOTEM-001)
集成AI客户端启动和测试执行
"""

import asyncio
import sys
import subprocess
import os
from pathlib import Path
from datetime import datetime

# 导入测试器
from eagle_totem_test_001 import EagleTotemTester


class EagleTotemTestRunner:
    """鹰图腾测试运行器"""

    def __init__(self, http_port=8080):
        self.http_port = http_port
        self.client_process = None
        self.log_file = None

        # 创建日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        self.log_file = log_dir / f"ai_client_eagle_totem_{timestamp}.log"

    def log(self, message, level="INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        log_entry = f"[{timestamp}] [{level}] {message}"
        print(log_entry)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")

    def start_ai_client(self):
        """启动AI客户端"""
        self.log("启动AI客户端...", "SYSTEM")

        # 查找Godot可执行文件
        godot_paths = [
            "/home/zhangzhan/bin/godot",
            "/usr/bin/godot4",
            "/usr/local/bin/godot4",
            "/usr/bin/godot",
        ]
        godot_exe = None
        for path in godot_paths:
            if os.path.exists(path):
                godot_exe = path
                break

        if not godot_exe:
            self.log("❌ 未找到Godot可执行文件", "ERROR")
            return False

        self.log(f"使用Godot: {godot_exe}", "SYSTEM")

        # 启动AI客户端
        cmd = [
            "python3", "ai_client/ai_game_client.py",
            "--project", ".",
            "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
            "--http-port", str(self.http_port),
        ]

        try:
            with open(self.log_file, "a") as log_f:
                self.client_process = subprocess.Popen(
                    cmd,
                    stdout=log_f,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=str(Path(__file__).parent.parent)
                )
            self.log(f"AI客户端进程启动: PID {self.client_process.pid}", "SYSTEM")
            return True
        except Exception as e:
            self.log(f"启动AI客户端失败: {e}", "ERROR")
            return False

    def stop_ai_client(self):
        """停止AI客户端"""
        if self.client_process:
            self.log("停止AI客户端...", "SYSTEM")
            try:
                self.client_process.terminate()
                self.client_process.wait(timeout=5)
            except:
                try:
                    self.client_process.kill()
                except:
                    pass
            self.client_process = None

    async def run_test(self):
        """运行测试"""
        self.log("=" * 60, "SYSTEM")
        self.log("启动EAGLE-TOTEM-001测试", "SYSTEM")
        self.log("=" * 60, "SYSTEM")

        # 启动AI客户端
        if not self.start_ai_client():
            return None

        # 等待AI客户端启动
        self.log("等待AI客户端启动...", "SYSTEM")
        await asyncio.sleep(5.0)

        try:
            # 运行测试
            async with EagleTotemTester(self.http_port) as tester:
                report_file = await tester.run_full_test()
                return report_file

        except Exception as e:
            self.log(f"测试执行失败: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            return None

        finally:
            self.stop_ai_client()


async def main():
    """主函数"""
    http_port = 8080
    if len(sys.argv) > 1:
        http_port = int(sys.argv[1])

    runner = EagleTotemTestRunner(http_port)
    report_file = await runner.run_test()

    print(f"\n{'=' * 60}")
    print(f"日志文件: {runner.log_file}")
    if report_file:
        print(f"测试报告: {report_file}")
        print("测试完成!")
        sys.exit(0)
    else:
        print("测试失败!")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
