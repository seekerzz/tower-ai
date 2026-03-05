"""Godot 进程管理器 - 启动、监控、崩溃检测"""
import subprocess
import threading
import time
import signal
import os
from pathlib import Path
from typing import Optional, Callable, List, Dict, Any
from dataclasses import dataclass, field

from ai_client.utils import (
    is_error_line, extract_stack_trace, classify_crash_type,
    CrashType, extract_crash_details, find_related_context,
    is_engine_error_line
)


@dataclass
class CrashInfo:
    """崩溃信息"""
    error_type: str
    stack_trace: str
    timestamp: float
    crash_type: CrashType = CrashType.UNKNOWN
    error_category: str = "unknown"  # 'script' | 'engine' | 'system' | 'unknown'
    crash_id: Optional[str] = None
    error_message: Optional[str] = None
    is_engine_internal: bool = False
    related_context: Dict[str, Any] = field(default_factory=dict)
    raw_output: List[str] = field(default_factory=list)
    # 游戏状态追踪
    game_state: Dict[str, Any] = field(default_factory=dict)


class GodotProcess:
    """
    管理 Godot 子进程的生命周期

    功能：
    - 启动 Godot（headless 或 GUI 模式）
    - 实时监控 stdout/stderr
    - 检测 SCRIPT ERROR 等崩溃
    - 强制终止进程
    """

    # 崩溃检测到后等待进程继续吐栈信息的时长（秒）
    CRASH_GRACE_SECONDS = 0.8

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

        # 崩溃收敛状态：先检测，再延迟收集并终止
        self._crash_error_line: Optional[str] = None
        self._crash_type: Optional[CrashType] = None
        self._crash_finalize_thread: Optional[threading.Thread] = None

        # 游戏状态追踪
        self._game_state: Dict[str, Any] = {
            'current_wave': None,
            'selected_totem': None,
            'deployed_units': [],
            'wave_active': False,
            'last_state_sync': None,
        }

    def _import_resources(self) -> bool:
        """导入Godot资源（在headless模式下运行前必须先导入）

        Returns:
            bool: 导入是否成功
        """
        import subprocess
        import os

        # 检查.godot/imported目录是否存在且有内容
        imported_dir = self.project_path / ".godot" / "imported"
        if imported_dir.exists() and any(imported_dir.iterdir()):
            return True  # 资源已导入

        print("[GodotProcess] 资源未导入，开始导入...")

        # 使用 --import 参数导入资源
        cmd = [
            "godot",
            "--path", str(self.project_path),
            "--import",
            "--headless"
        ]

        env = os.environ.copy()

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,  # 导入可能需要一些时间
                env=env
            )

            if result.returncode == 0:
                print("[GodotProcess] 资源导入完成")
                return True
            else:
                print(f"[GodotProcess] 资源导入失败: {result.stderr}")
                return False

        except subprocess.TimeoutExpired:
            print("[GodotProcess] 资源导入超时")
            return False
        except Exception as e:
            print(f"[GodotProcess] 资源导入异常: {e}")
            return False

    def start(self, verbose: bool = False, log_file: Optional[str] = None) -> bool:
        """启动 Godot 进程

        Args:
            verbose: 是否启用详细日志模式（添加 --verbose 参数）
            log_file: Godot 日志文件路径（添加 --log-file 参数）
        """
        # 先导入资源（如果是headless模式）
        if not self.visual_mode:
            if not self._import_resources():
                print("[GodotProcess] 警告: 资源导入失败，继续尝试启动...")

        # 使用shell=False时需要确保路径正确传递
        # 路径中的特殊字符（如连字符）可能导致问题
        project_path = str(self.project_path)

        cmd = [
            "godot",
            "--path", project_path,
            f"--ai-port={self.ai_port}",
            self.scene_path,
            "--ai-mode"
        ]

        if not self.visual_mode:
            cmd.append("--headless")

        # 可选参数
        if verbose:
            cmd.append("--verbose")

        if log_file:
            cmd.extend(["--log-file", log_file])

        # 设置环境变量：headless模式下不需要DISPLAY
        # Godot 4.6 --headless 使用 dummy 显示驱动，不依赖X11
        env = os.environ.copy()

        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # 合并 stderr 到 stdout
                text=True,
                bufsize=1,  # 行缓冲
                universal_newlines=True,
                env=env
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
                # 更新游戏状态追踪
                self._update_game_state(line)

            # 实时打印（调试用）
            print(f"[Godot] {line}")

            # 检测错误（非阻塞）- 使用新的 is_error_line 返回值
            is_error, crash_type = is_error_line(line)
            if is_error:
                self._mark_crash_detected(line, crash_type)

    def _update_game_state(self, line: str):
        """从输出中更新游戏状态追踪

        解析关键事件：
        - 波次开始/结束
        - 图腾选择
        - 单位部署
        - 状态同步
        """
        import re

        # 波次事件
        wave_match = re.search(r'第\s*(\d+)\s*波.*开始', line)
        if wave_match:
            self._game_state['current_wave'] = int(wave_match.group(1))
            self._game_state['wave_active'] = True
            return

        if '波次结束' in line or 'wave.*end' in line.lower():
            self._game_state['wave_active'] = False
            return

        # 图腾选择
        totem_match = re.search(r'选择图腾[：:]\s*(\w+)', line)
        if totem_match:
            self._game_state['selected_totem'] = totem_match.group(1)
            return

        # 单位部署
        deploy_match = re.search(r'部署.*\(\s*(\d+)\s*,\s*(\d+)\s*\)', line)
        if deploy_match:
            self._game_state['deployed_units'].append({
                'x': int(deploy_match.group(1)),
                'y': int(deploy_match.group(2)),
            })
            return

        # 状态同步时间戳
        if '状态同步' in line or 'STATE_SYNC' in line:
            self._game_state['last_state_sync'] = time.time()

    def _mark_crash_detected(self, error_line: str, crash_type: Optional[CrashType] = None):
        """标记崩溃并启动延迟收敛线程（避免阻塞输出读取线程）。

        Args:
            error_line: 触发崩溃的错误行
            crash_type: 崩溃类型分类
        """
        with self._lock:
            if self._crash_error_line is not None:
                return
            self._crash_error_line = error_line
            self._crash_type = crash_type

        # 根据崩溃类型调整日志输出
        crash_type_str = crash_type.value if crash_type else "UNKNOWN"
        print(f"[GodotProcess] 检测到崩溃 [{crash_type_str}]: {error_line}")

        # 对于引擎内部错误，增加额外的诊断信息
        if crash_type in (CrashType.PARAMETER_NULL, CrashType.ENGINE_ERROR):
            print(f"[GodotProcess] ⚠️ 这是 Godot 引擎内部错误，可能与 GDScript 代码无关")
            if crash_type == CrashType.PARAMETER_NULL:
                print(f"[GodotProcess] ℹ️ 检测到 CRASH-002 特征 (Parameter 't' is null)")

        self._crash_finalize_thread = threading.Thread(
            target=self._finalize_crash,
            daemon=True,
        )
        self._crash_finalize_thread.start()

    def _finalize_crash(self):
        """延迟收集崩溃上下文并终止进程。

        改进：
        - 根据崩溃类型调整等待时间
        - 收集更详细的上下文信息
        - 区分 SCRIPT ERROR 和 ENGINE ERROR
        """
        # 根据崩溃类型调整等待时间：引擎错误需要更多时间收集 C++ 栈
        base_wait = self.CRASH_GRACE_SECONDS
        if self._crash_type in (CrashType.PARAMETER_NULL, CrashType.ENGINE_ERROR):
            base_wait = 1.5  # 给引擎错误更多时间

        deadline = time.time() + base_wait
        while time.time() < deadline:
            if self._stop_monitoring.is_set():
                break
            # 若进程已退出，不必继续等待
            if not self.is_running():
                break
            time.sleep(0.05)

        with self._lock:
            if self._crashed:
                return
            self._crashed = True
            error_line = self._crash_error_line or "UNKNOWN ERROR"
            crash_type = self._crash_type or CrashType.UNKNOWN

            # 找到错误行索引
            error_idx = len(self._output_lines) - 1
            for i in range(len(self._output_lines) - 1, -1, -1):
                if self._output_lines[i] == error_line:
                    error_idx = i
                    break

            # 提取崩溃详情
            crash_details = extract_crash_details(error_line)

            # 收集相关上下文
            related_context = find_related_context(self._output_lines, error_idx)

            # 判断是否是引擎错误
            is_engine_err = is_engine_error_line(error_line)

            # 确定错误分类
            if crash_type == CrashType.SCRIPT_ERROR:
                error_category = 'script'
            elif is_engine_err:
                error_category = 'engine'
            elif crash_type == CrashType.SYSTEM_CRASH:
                error_category = 'system'
            else:
                error_category = 'unknown'

            # 提取栈跟踪（使用更大的上下文范围）
            stack_trace = extract_stack_trace(
                self._output_lines,
                error_idx,
                before=150,  # 增加上下文范围
                after=150,
                include_context=True,
                is_engine_error=is_engine_err
            )

            # 保存原始输出用于调试
            raw_output = self._output_lines.copy()

        # 构建崩溃信息
        self._crash_info = CrashInfo(
            error_type=error_line,
            stack_trace=stack_trace,
            timestamp=time.time(),
            crash_type=crash_type,
            error_category=error_category,
            crash_id=crash_details.get('crash_id'),
            error_message=crash_details.get('error_message'),
            is_engine_internal=crash_details.get('is_engine_internal', False),
            related_context=related_context,
            raw_output=raw_output[-500:] if len(raw_output) > 500 else raw_output,  # 保留最近500行
            game_state=self._game_state.copy(),
        )

        # 打印详细的崩溃摘要
        self._print_crash_summary(self._crash_info)

        if self.on_crash:
            self.on_crash(self._crash_info)

        # 强制终止进程
        self.kill()

    def _print_crash_summary(self, crash_info: CrashInfo):
        """打印崩溃摘要信息"""
        print("\n" + "=" * 70)
        print("【崩溃摘要】")
        print("=" * 70)
        print(f"崩溃类型: {crash_info.crash_type.value}")
        print(f"错误分类: {crash_info.error_category}")
        if crash_info.crash_id:
            print(f"崩溃ID: {crash_info.crash_id}")
        print(f"错误信息: {crash_info.error_type}")
        print(f"引擎内部错误: {'是' if crash_info.is_engine_internal else '否'}")
        print(f"时间戳: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(crash_info.timestamp))}")

        # 打印游戏状态
        gs = crash_info.game_state
        if gs.get('current_wave') is not None:
            print(f"\n游戏状态:")
            print(f"  当前波次: {gs['current_wave']}")
            print(f"  波次进行中: {'是' if gs['wave_active'] else '否'}")
        if gs.get('selected_totem'):
            print(f"  已选图腾: {gs['selected_totem']}")
        if gs.get('deployed_units'):
            print(f"  部署单位数: {len(gs['deployed_units'])}")

        # 打印相关上下文摘要
        ctx = crash_info.related_context
        if ctx.get('wave_events'):
            print(f"\n波次事件: {len(ctx['wave_events'])} 个")
        if ctx.get('totem_events'):
            print(f"图腾攻击事件: {len(ctx['totem_events'])} 个")
        if ctx.get('cpp_stack'):
            print(f"C++ 栈帧: {len(ctx['cpp_stack'])} 个")

        print("=" * 70 + "\n")

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

    def get_crash_summary(self) -> Dict[str, Any]:
        """获取崩溃摘要（用于日志记录和报告）"""
        if not self._crash_info:
            return {}

        info = self._crash_info
        return {
            'crash_type': info.crash_type.value,
            'error_category': info.error_category,
            'crash_id': info.crash_id,
            'error_type': info.error_type,
            'error_message': info.error_message,
            'is_engine_internal': info.is_engine_internal,
            'timestamp': info.timestamp,
            'has_cpp_stack': len(info.related_context.get('cpp_stack', [])) > 0,
            'wave_event_count': len(info.related_context.get('wave_events', [])),
            'totem_event_count': len(info.related_context.get('totem_events', [])),
            'game_state': info.game_state,
        }

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
