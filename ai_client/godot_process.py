"""Godot 进程管理器 - 启动、监控、崩溃检测"""
import subprocess
import threading
import time
import signal
import os
from pathlib import Path
from typing import Optional, Callable, List
from dataclasses import dataclass

from ai_client.utils import is_error_line, extract_stack_trace


@dataclass
class CrashInfo:
    """崩溃信息"""
    error_type: str
    stack_trace: str
    timestamp: float


class GodotProcess:
    """
    管理 Godot 子进程的生命周期

    功能：
    - 启动 Godot（headless 或 GUI 模式）
    - 实时监控 stdout/stderr
    - 检测 SCRIPT ERROR 等崩溃
    - 强制终止进程
    """

    def __init__(
        self,
        project_path: str,
        scene_path: str,
        ai_port: int,
        visual_mode: bool = False,
        on_crash: Optional[Callable[[CrashInfo], None]] = None
    ):
        self.project_path = Path(project_path)
        self.scene_path = scene_path
        self.ai_port = ai_port
        self.visual_mode = visual_mode
        self.on_crash = on_crash

        self.process: Optional[subprocess.Popen] = None
        self._monitor_thread: Optional[threading.Thread] = None
        self._stop_monitoring = threading.Event()
        self._output_lines: List[str] = []
        self._lock = threading.Lock()
        self._crashed = False
        self._crash_info: Optional[CrashInfo] = None

    def start(self) -> bool:
        """启动 Godot 进程"""
        cmd = [
            "godot",
            "--path", str(self.project_path),
            f"--ai-port={self.ai_port}",
            self.scene_path,
            "--ai-mode"
        ]

        if not self.visual_mode:
            cmd.append("--headless")

        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # 合并 stderr 到 stdout
                text=True,
                bufsize=1,  # 行缓冲
                universal_newlines=True
            )

            # 启动监控线程
            self._stop_monitoring.clear()
            self._monitor_thread = threading.Thread(target=self._monitor_output)
            self._monitor_thread.daemon = True
            self._monitor_thread.start()

            return True

        except Exception as e:
            print(f"[GodotProcess] 启动失败: {e}")
            return False

    def _monitor_output(self):
        """后台线程：监控 Godot 输出"""
        if not self.process or not self.process.stdout:
            return

        for line in self.process.stdout:
            if self._stop_monitoring.is_set():
                break

            line = line.rstrip()
            with self._lock:
                self._output_lines.append(line)

            # 实时打印（调试用）
            print(f"[Godot] {line}")

            # 检测错误
            if is_error_line(line):
                self._handle_crash(line)

    def _handle_crash(self, error_line: str):
        """处理崩溃检测"""
        if self._crashed:
            return

        self._crashed = True

        # 提取堆栈跟踪
        with self._lock:
            error_idx = len(self._output_lines) - 1
            stack_trace = extract_stack_trace(self._output_lines, error_idx)

        self._crash_info = CrashInfo(
            error_type=error_line,
            stack_trace=stack_trace,
            timestamp=time.time()
        )

        print(f"[GodotProcess] 检测到崩溃: {error_line}")

        # 回调通知
        if self.on_crash:
            self.on_crash(self._crash_info)

        # 强制终止进程
        self.kill()

    def kill(self):
        """强制终止 Godot 进程"""
        if not self.process:
            return

        try:
            # 先尝试优雅终止
            self.process.terminate()

            # 等待最多 2 秒
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                # 强制杀死
                self.process.kill()
                self.process.wait()

        except Exception as e:
            print(f"[GodotProcess] 终止进程时出错: {e}")
        finally:
            self._stop_monitoring.set()

    def is_running(self) -> bool:
        """检查进程是否仍在运行"""
        if not self.process:
            return False
        return self.process.poll() is None

    def has_crashed(self) -> bool:
        """检查是否检测到崩溃"""
        return self._crashed

    def get_crash_info(self) -> Optional[CrashInfo]:
        """获取崩溃信息"""
        return self._crash_info

    def get_recent_output(self, lines: int = 50) -> List[str]:
        """获取最近的输出"""
        with self._lock:
            return self._output_lines[-lines:]

    def wait_for_ready(self, timeout: float = 30.0) -> bool:
        """等待 Godot 就绪（WebSocket 服务器启动）"""
        start = time.time()
        while time.time() - start < timeout:
            if not self.is_running():
                return False

            # 检查输出中是否有 "服务器已启动" 字样
            with self._lock:
                for line in self._output_lines:
                    if "服务器已启动" in line or "STATE_OPEN" in line:
                        return True

            time.sleep(0.1)

        return False
