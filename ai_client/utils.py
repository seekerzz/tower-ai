"""AI Client 工具函数"""
import socket
import re
from typing import Optional, List, Dict, Any
from enum import Enum


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


class CrashType(Enum):
    """崩溃类型分类"""
    SCRIPT_ERROR = "SCRIPT_ERROR"          # GDScript 运行时错误
    ENGINE_ERROR = "ENGINE_ERROR"          # Godot 引擎内部错误
    FATAL_ERROR = "FATAL_ERROR"            # 致命错误
    SYSTEM_CRASH = "SYSTEM_CRASH"          # 系统级崩溃（段错误等）
    PARAMETER_NULL = "PARAMETER_NULL"      # CRASH-002 特定：Parameter "t" is null
    UNKNOWN = "UNKNOWN"                    # 未知类型


# Godot 错误检测模式 - 按优先级排序
GODOT_ERROR_PATTERNS = [
    # CRASH-002 特定模式 - 最高优先级
    (re.compile(r'Parameter\s+"t"\s+is\s+null', re.IGNORECASE), CrashType.PARAMETER_NULL),
    (re.compile(r'Parameter\s+"[^"]*"\s+is\s+null', re.IGNORECASE), CrashType.ENGINE_ERROR),

    # 系统级崩溃
    (re.compile(r'CrashHandlerException:.*'), CrashType.SYSTEM_CRASH),
    (re.compile(r'Segmentation\s+fault', re.IGNORECASE), CrashType.SYSTEM_CRASH),
    (re.compile(r'SIGSEGV'), CrashType.SYSTEM_CRASH),
    (re.compile(r'SIGABRT'), CrashType.SYSTEM_CRASH),

    # 致命错误
    (re.compile(r'FATAL:\s*(.+)', re.IGNORECASE), CrashType.FATAL_ERROR),

    # GDScript 运行时错误
    (re.compile(r'SCRIPT\s+ERROR:\s*(.+)', re.IGNORECASE), CrashType.SCRIPT_ERROR),
    (re.compile(r'Invalid\s+get\s+index'), CrashType.SCRIPT_ERROR),
    (re.compile(r'Invalid\s+call'), CrashType.SCRIPT_ERROR),
    (re.compile(r'Attempt\s+to\s+call'), CrashType.SCRIPT_ERROR),

    # Godot 引擎错误
    (re.compile(r'ERROR:\s*(.+)', re.IGNORECASE), CrashType.ENGINE_ERROR),
]

# Godot C++ 栈跟踪模式
GODOT_CPP_STACK_PATTERNS = [
    re.compile(r'at:\s+\([^)]+\)\s+'),           # at: (function) file:line
    re.compile(r'0x[0-9a-fA-F]+\s+in\s+'),        # 0xADDR in function
    re.compile(r'#[0-9]+\s+0x[0-9a-fA-F]+'),      # #N 0xADDR
    re.compile(r'\[([^\]]+)\]\s+\([^)]+\)'),     # [module] (function)
]

# 需要额外上下文的错误模式
ERROR_CONTEXT_PATTERNS = {
    'wave_start': re.compile(r'第\s*\d+\s*波.*开始|wave.*start', re.IGNORECASE),
    'totem_attack': re.compile(r'图腾.*攻击|totem.*attack', re.IGNORECASE),
    'enemy_spawn': re.compile(r'敌人.*生成|enemy.*spawn', re.IGNORECASE),
    'state_sync': re.compile(r'状态同步|STATE_SYNC', re.IGNORECASE),
}


def is_error_line(line: str) -> tuple[bool, Optional[CrashType]]:
    """检查一行输出是否是错误/崩溃标志

    Returns:
        (是否错误, 崩溃类型)
    """
    for pattern, crash_type in GODOT_ERROR_PATTERNS:
        if pattern.search(line):
            return True, crash_type
    return False, None


def is_engine_error_line(line: str) -> bool:
    """专门检测 Godot 引擎内部错误

    用于区分 SCRIPT ERROR（GDScript代码问题）和 ENGINE ERROR（引擎内部问题）

    Returns:
        是否是引擎内部错误
    """
    crash_type = classify_crash_type(line)
    return crash_type in (
        CrashType.ENGINE_ERROR,
        CrashType.PARAMETER_NULL,
        CrashType.FATAL_ERROR,
        CrashType.SYSTEM_CRASH,
    )


def classify_crash_type(line: str) -> CrashType:
    """根据错误行分类崩溃类型"""
    _, crash_type = is_error_line(line)
    return crash_type or CrashType.UNKNOWN


def extract_crash_details(line: str) -> Dict[str, Any]:
    """提取崩溃详细信息

    Returns:
        包含 error_message, crash_type, is_engine_internal 等信息的字典
    """
    is_error, crash_type = is_error_line(line)
    if not is_error:
        return {}

    details = {
        'crash_type': crash_type,
        'error_line': line,
        'is_engine_internal': crash_type in (
            CrashType.PARAMETER_NULL,
            CrashType.ENGINE_ERROR,
            CrashType.FATAL_ERROR
        ),
        'is_script_error': crash_type == CrashType.SCRIPT_ERROR,
        'is_system_crash': crash_type == CrashType.SYSTEM_CRASH,
    }

    # 提取错误消息
    for pattern, _ in GODOT_ERROR_PATTERNS:
        match = pattern.search(line)
        if match:
            if hasattr(match, 'lastindex') and match.lastindex:
                details['error_message'] = match.group(1)
            else:
                details['error_message'] = match.group(0)
            break

    # CRASH-002 特定标记
    if crash_type == CrashType.PARAMETER_NULL:
        details['crash_id'] = 'CRASH-002'
        details['likely_cause'] = '波次开始时图腾攻击定时器竞争条件'

    return details


def is_cpp_stack_line(line: str) -> bool:
    """检查是否是 Godot C++ 栈跟踪行"""
    for pattern in GODOT_CPP_STACK_PATTERNS:
        if pattern.search(line):
            return True
    return False


def find_related_context(lines: List[str], error_idx: int) -> Dict[str, List[str]]:
    """查找与错误相关的上下文信息

    搜索波次开始、图腾攻击、敌人生成等关键事件
    """
    context = {
        'wave_events': [],
        'totem_events': [],
        'enemy_events': [],
        'state_syncs': [],
        'cpp_stack': [],
    }

    # 搜索范围：错误前后各100行
    start = max(0, error_idx - 100)
    end = min(len(lines), error_idx + 100)

    for i in range(start, end):
        line = lines[i]

        # 检测 C++ 栈
        if is_cpp_stack_line(line):
            context['cpp_stack'].append(f"[{i}] {line}")
            continue

        # 检测关键事件
        for event_type, pattern in ERROR_CONTEXT_PATTERNS.items():
            if pattern.search(line):
                context_key = {
                    'wave_start': 'wave_events',
                    'totem_attack': 'totem_events',
                    'enemy_spawn': 'enemy_events',
                    'state_sync': 'state_syncs',
                }[event_type]
                context[context_key].append(f"[{i}] {line}")

    return context


def extract_stack_trace(
    lines: List[str],
    error_idx: int,
    before: int = 100,
    after: int = 100,
    include_context: bool = True,
    is_engine_error: bool = False,
) -> str:
    """提取错误上下文（前后文），提高定位准确率。

    改进：
    - 增加默认上下文范围（100行）以捕获更多 Godot C++ 栈信息
    - 自动检测并包含 C++ 栈跟踪
    - 识别关键事件（波次开始、图腾攻击等）
    - 添加崩溃类型分类信息

    Args:
        lines: 所有输出行
        error_idx: 错误行索引
        before: 错误行前包含的行数
        after: 错误行后包含的行数
        include_context: 是否包含相关上下文分析
        is_engine_error: 是否是引擎错误（引擎错误通常没有GDScript栈，需要更多上下文）
    """
    if not lines:
        return ""

    error_idx = max(0, min(error_idx, len(lines) - 1))
    error_line = lines[error_idx]

    # 引擎错误需要更多上下文（通常没有GDScript栈）
    if is_engine_error:
        before = max(before, 150)
        after = max(after, 150)

    # 基础上下文
    start = max(0, error_idx - before)
    end = min(len(lines), error_idx + after + 1)
    context_lines = lines[start:end]

    # 构建输出
    output_parts = []

    # 1. 崩溃类型和详情
    crash_details = extract_crash_details(error_line)
    if crash_details:
        output_parts.append("=" * 60)
        output_parts.append("【崩溃分析】")
        output_parts.append(f"崩溃类型: {crash_details.get('crash_type', 'UNKNOWN')}")
        if 'crash_id' in crash_details:
            output_parts.append(f"崩溃ID: {crash_details['crash_id']}")
        if 'likely_cause' in crash_details:
            output_parts.append(f"可能原因: {crash_details['likely_cause']}")
        output_parts.append(f"引擎内部错误: {'是' if crash_details.get('is_engine_internal') else '否'}")
        output_parts.append("=" * 60)
        output_parts.append("")

    # 2. 基础上下文
    output_parts.append("【错误上下文】")
    for i, line in enumerate(context_lines, start=start):
        prefix = ">>> " if i == error_idx else "    "
        output_parts.append(f"{prefix}[{i}] {line}")

    # 3. 相关上下文分析
    if include_context:
        related = find_related_context(lines, error_idx)

        if related['wave_events']:
            output_parts.append("")
            output_parts.append("【波次事件】")
            output_parts.extend(related['wave_events'][-5:])  # 最近5个

        if related['totem_events']:
            output_parts.append("")
            output_parts.append("【图腾攻击事件】")
            output_parts.extend(related['totem_events'][-5:])

        if related['enemy_events']:
            output_parts.append("")
            output_parts.append("【敌人生成事件】")
            output_parts.extend(related['enemy_events'][-5:])

        if related['cpp_stack']:
            output_parts.append("")
            output_parts.append("【Godot C++ 栈跟踪】")
            output_parts.extend(related['cpp_stack'][:20])  # 最多20行

    return "\n".join(output_parts)
