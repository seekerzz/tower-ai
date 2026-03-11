"""AI Client 工具函数"""
import socket
import re
from dataclasses import dataclass
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


@dataclass(frozen=True)
class GodotIssue:
    """Godot 日志中检测到的问题"""

    severity: str  # info | warning | runtime_error | fatal
    category: str
    line: str


_FATAL_PATTERNS = [
    re.compile(r'FATAL:.*'),
    re.compile(r'CrashHandlerException:.*'),
    re.compile(r'Segmentation fault', re.IGNORECASE),
    re.compile(r'stack overflow', re.IGNORECASE),
]

_RUNTIME_ERROR_PATTERNS = [
    re.compile(r'SCRIPT ERROR:.*'),
    re.compile(r'Condition ".*" is true\.'),
    re.compile(r'Invalid call\.'),
]

_WARNING_PATTERNS = [
    re.compile(r'WARNING:.*'),
    re.compile(r'W\s+\d+:.*'),
]

_GENERIC_ERROR_PATTERN = re.compile(r'^ERROR:')


def classify_godot_issue(line: str) -> Optional[GodotIssue]:
    """将 Godot 输出行分类为告警/运行时错误/致命错误。"""
    text = line.strip()
    for pattern in _FATAL_PATTERNS:
        if pattern.search(text):
            return GodotIssue(severity="fatal", category="engine_crash", line=text)

    for pattern in _RUNTIME_ERROR_PATTERNS:
        if pattern.search(text):
            return GodotIssue(severity="runtime_error", category="script_error", line=text)

    if _GENERIC_ERROR_PATTERN.search(text):
        return GodotIssue(severity="runtime_error", category="engine_error", line=text)

    for pattern in _WARNING_PATTERNS:
        if pattern.search(text):
            return GodotIssue(severity="warning", category="warning", line=text)

    return None


def extract_stack_trace(lines: List[str], error_idx: int, context_before: int = 5, context_after: int = 20) -> str:
    """从错误行附近提取上下文堆栈。"""
    start = max(0, error_idx - context_before)
    end = min(error_idx + context_after, len(lines))
    context = lines[start:end]
    return '\n'.join(context)
