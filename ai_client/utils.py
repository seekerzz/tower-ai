"""AI Client 工具函数"""
import socket
import re
from typing import Optional, List


def find_free_port(start: int = 10000, end: int = 60000) -> int:
    """查找一个可用端口"""
    for port in range(start, end):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('127.0.0.1', port))
                return port
            except OSError:
                continue
    raise RuntimeError(f"无法找到可用端口 (范围: {start}-{end})")


def find_two_free_ports() -> tuple[int, int]:
    """查找两个连续可用端口"""
    port1 = find_free_port()
    # 第二个端口从 port1+1 开始找，避免冲突
    port2 = find_free_port(start=port1 + 1)
    return port1, port2


# Godot 错误检测模式
GODOT_ERROR_PATTERNS = [
    re.compile(r'SCRIPT ERROR:.*'),  # GDScript 运行时错误
    re.compile(r'ERROR:.*'),          # Godot 引擎错误
    re.compile(r'FATAL:.*'),          # 致命错误
    re.compile(r'CrashHandlerException:.*'),  # Windows 崩溃
    re.compile(r'Segmentation fault'),        # Linux 崩溃
]


def is_error_line(line: str) -> bool:
    """检查一行输出是否是错误/崩溃标志"""
    for pattern in GODOT_ERROR_PATTERNS:
        if pattern.search(line):
            return True
    return False


def extract_stack_trace(lines: List[str], error_idx: int) -> str:
    """从错误行开始提取堆栈跟踪"""
    # 收集错误行及后续 20 行作为上下文
    context = lines[error_idx:min(error_idx + 20, len(lines))]
    return '\n'.join(context)
