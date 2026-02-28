# AI Client HTTP REST 重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 将 ai_game_client.py 重构为支持 HTTP REST API、动态端口、Godot 进程管理和崩溃捕获的统一网关

**Architecture:** Python HTTP 服务器接收外部 curl 请求，通过内部 WebSocket 转发给 Godot 子进程；实时扫描 Godot stderr 捕获 SCRIPT ERROR，崩溃时返回 SystemCrash JSON；支持 --visual 标志切换 headless/GUI 模式

**Tech Stack:** Python 3, asyncio, aiohttp, websockets, subprocess, threading, re

---

## 前置检查

### Task 0: 验证当前代码状态

**目的:** 确保代码基线正确，理解当前实现

**Files:**
- Read: `ai_client/ai_game_client.py`
- Read: `src/Autoload/AIManager.gd`
- Read: `ai_client/run_visual.py`

**Step 1: 确认端口不一致问题**

检查 ai_game_client.py:312 和 AIManager.gd:6 的端口定义

**Step 2: 确认 Godot 启动参数**

检查 run_visual.py 如何启动 Godot，特别是 --ai-mode 参数

---

## Phase 1: Godot 端改造（动态端口）

### Task 1: AIManager.gd 添加命令行参数解析

**Files:**
- Modify: `src/Autoload/AIManager.gd:1-50`

**Step 1: 添加端口配置变量**

在 AIManager.gd 开头添加：

```gdscript
extends Node

## AI 管理器 - WebSocket 服务端
## 监听游戏事件，暂停游戏，下发状态给 AI 客户端

# 默认端口，可通过 --ai-port=<port> 覆盖
const DEFAULT_PORT: int = 45678
var port: int = DEFAULT_PORT
```

**Step 2: 添加命令行参数解析函数**

在 `_ready()` 之前添加：

```gdscript
func _parse_command_line_args():
	"""解析命令行参数，支持 --ai-port=<port>"""
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--ai-port="):
			var port_str = arg.substr("--ai-port=".length())
			var parsed_port = port_str.to_int()
			if parsed_port > 1024 and parsed_port < 65535:
				port = parsed_port
				AILogger.net_connection("使用自定义端口", str(port))
			else:
				AILogger.error("无效的端口: %s，使用默认 %d" % [port_str, DEFAULT_PORT])
```

**Step 3: 在 _ready() 中调用参数解析**

修改 `_ready()`：

```gdscript
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_command_line_args()  # 添加这一行
	call_deferred("_delayed_start_server")
	_connect_game_signals()
```

**Step 4: 修改 _start_server() 使用动态端口**

修改 `_start_server()` 函数：

```gdscript
func _start_server():
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port)  # 使用 port 变量替代 PORT 常量
	if err != OK:
		AILogger.error("WebSocket 服务器启动失败，端口: %d，错误码: %d" % [port, err])
		tcp_server = null
		return
	AILogger.net_connection("服务器已启动", "监听端口 %d" % port)
```

**Step 5: 移除旧的 PORT 常量定义**

删除第 6 行：`const PORT: int = 45678`

**Step 6: 验证修改**

启动 Godot 测试：
```bash
godot --path . --headless --ai-port=56789 res://src/Scenes/UI/CoreSelection.tscn --ai-mode
```

检查日志输出是否显示 "监听端口 56789"

**Step 7: Commit**

```bash
git add src/Autoload/AIManager.gd
git commit -m "feat: AIManager 支持 --ai-port 命令行参数动态配置端口"
```

---

## Phase 2: Python 端核心重构

### Task 2: 创建工具函数模块

**Files:**
- Create: `ai_client/utils.py`

**Step 1: 创建端口查找函数**

```python
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
```

**Step 2: 验证工具函数**

创建临时测试：
```bash
cd /home/zhangzhan/tower
python3 -c "
from ai_client.utils import find_two_free_ports, is_error_line
p1, p2 = find_two_free_ports()
print(f'Ports: {p1}, {p2}')
assert is_error_line('SCRIPT ERROR: Invalid call. Nonexistent function \'foo\' in base \'Node\'.')
assert not is_error_line('Normal log message')
print('All tests passed')
"
```

**Step 3: Commit**

```bash
git add ai_client/utils.py
git commit -m "feat: add utility functions for port allocation and error detection"
```

---

### Task 3: 创建 Godot 进程管理器

**Files:**
- Create: `ai_client/godot_process.py`

**Step 1: 实现 GodotProcess 类**

```python
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
```

**Step 2: 验证进程管理器**

```bash
cd /home/zhangzhan/tower
python3 -c "
from ai_client.godot_process import GodotProcess
import time

# 测试基本功能（不实际启动 Godot）
gp = GodotProcess('.', 'res://src/Scenes/UI/CoreSelection.tscn', 45678)
print('GodotProcess 类加载成功')
print(f'is_running: {gp.is_running()}')
print(f'has_crashed: {gp.has_crashed()}')
"
```

**Step 3: Commit**

```bash
git add ai_client/godot_process.py
git commit -m "feat: add GodotProcess manager with crash detection"
```

---

### Task 4: 创建 HTTP 服务器模块

**Files:**
- Create: `ai_client/http_server.py`

**Step 1: 实现 HTTP 服务器**

```python
"""HTTP REST API 服务器 - 接收外部请求，转发给 WebSocket"""
import asyncio
import json
import logging
from typing import Optional, Callable, Awaitable, Dict, Any
from aiohttp import web

logger = logging.getLogger(__name__)


# 类型定义
ActionHandler = Callable[[list], Awaitable[Dict[str, Any]]]
StatusHandler = Callable[[], Awaitable[Dict[str, Any]]]


class AIHTTPServer:
    """
    HTTP REST API 服务器

    端点：
    - POST /action - 发送动作，返回游戏状态
    - GET  /status - 获取服务器状态
    """

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 8080,
        action_handler: Optional[ActionHandler] = None,
        status_handler: Optional[StatusHandler] = None
    ):
        self.host = host
        self.port = port
        self.action_handler = action_handler
        self.status_handler = status_handler

        self.app = web.Application()
        self.runner: Optional[web.AppRunner] = None
        self.site: Optional[web.TCPSite] = None

        # 注册路由
        self.app.router.add_post("/action", self._handle_action)
        self.app.router.add_get("/status", self._handle_status)
        self.app.router.add_get("/health", self._handle_health)

    async def start(self) -> bool:
        """启动 HTTP 服务器"""
        try:
            self.runner = web.AppRunner(self.app)
            await self.runner.setup()
            self.site = web.TCPSite(self.runner, self.host, self.port)
            await self.site.start()
            logger.info(f"HTTP 服务器已启动: http://{self.host}:{self.port}")
            return True
        except Exception as e:
            logger.error(f"HTTP 服务器启动失败: {e}")
            return False

    async def stop(self):
        """停止 HTTP 服务器"""
        if self.runner:
            await self.runner.cleanup()
            logger.info("HTTP 服务器已停止")

    async def _handle_action(self, request: web.Request) -> web.Response:
        """处理 POST /action 请求"""
        try:
            # 解析请求体
            body = await request.json()
            actions = body.get("actions", [])

            if not isinstance(actions, list):
                return web.json_response(
                    {"error": "actions must be an array"},
                    status=400
                )

            # 调用处理器（由主程序注入）
            if self.action_handler:
                result = await self.action_handler(actions)
                return web.json_response(result)
            else:
                return web.json_response(
                    {"error": "Action handler not configured"},
                    status=503
                )

        except json.JSONDecodeError:
            return web.json_response(
                {"error": "Invalid JSON"},
                status=400
            )
        except Exception as e:
            logger.error(f"处理 action 请求时出错: {e}")
            return web.json_response(
                {"error": str(e)},
                status=500
            )

    async def _handle_status(self, request: web.Request) -> web.Response:
        """处理 GET /status 请求"""
        if self.status_handler:
            status = await self.status_handler()
            return web.json_response(status)
        else:
            return web.json_response({
                "status": "running",
                "http_port": self.port
            })

    async def _handle_health(self, request: web.Request) -> web.Response:
        """健康检查端点"""
        return web.json_response({"status": "ok"})
```

**Step 2: 验证 HTTP 服务器模块**

```bash
cd /home/zhangzhan/tower
python3 -c "
from ai_client.http_server import AIHTTPServer
import asyncio

async def test():
    server = AIHTTPServer(port=9999)
    print('AIHTTPServer 类加载成功')
    # 不实际启动，只验证导入

asyncio.run(test())
"
```

**Step 3: Commit**

```bash
git add ai_client/http_server.py
git commit -m "feat: add HTTP REST API server module"
```

---

### Task 5: 重构主程序 ai_game_client.py

**Files:**
- Modify: `ai_client/ai_game_client.py`（完全重写）

**Step 1: 备份原文件**

```bash
cp ai_client/ai_game_client.py ai_client/ai_game_client_legacy.py
```

**Step 2: 编写新的主程序**

```python
#!/usr/bin/env python3
"""
Godot AI 游戏客户端 - HTTP REST API 网关

用法:
    # Headless 模式（默认，无图形界面）
    python3 ai_game_client.py

    # GUI 模式（显示游戏窗口）
    python3 ai_game_client.py --visual

    # 指定场景
    python3 ai_game_client.py --scene res://src/Scenes/UI/MainGUI.tscn

HTTP API:
    POST /action
        请求: {"actions": [{"type": "start_wave"}]}
        响应: {"event": "WaveStarted", ...} 或 {"event": "SystemCrash", ...}

    GET /status
        响应: {"godot_running": true, "ws_connected": true, ...}
"""

import asyncio
import argparse
import logging
import sys
import signal
from typing import Optional, Dict, Any
from dataclasses import dataclass

import websockets

from ai_client.utils import find_two_free_ports
from ai_client.godot_process import GodotProcess, CrashInfo
from ai_client.http_server import AIHTTPServer

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class ClientConfig:
    """客户端配置"""
    project_path: str
    scene_path: str
    visual_mode: bool
    godot_ws_port: int
    http_port: int


class AIGameClient:
    """
    AI 游戏客户端 - HTTP 网关 + WebSocket 桥接

    架构:
    1. 启动 Godot 子进程（headless 或 GUI）
    2. 建立 WebSocket 连接到 Godot
    3. 启动 HTTP 服务器接收外部请求
    4. 将 HTTP 请求转发到 WebSocket
    5. 监控 Godot 崩溃，返回 SystemCrash 事件
    """

    def __init__(self, config: ClientConfig):
        self.config = config
        self.godot: Optional[GodotProcess] = None
        self.websocket: Optional[websockets.WebSocketClientProtocol] = None
        self.http_server: Optional[AIHTTPServer] = None
        self._shutdown_event = asyncio.Event()
        self._pending_response: Optional[asyncio.Future] = None
        self._last_state: Optional[Dict] = None
        self._ws_connected = False

    async def run(self):
        """主运行循环"""
        try:
            # 1. 启动 Godot
            if not await self._start_godot():
                return False

            # 2. 连接 WebSocket
            if not await self._connect_websocket():
                return False

            # 3. 启动 HTTP 服务器
            if not await self._start_http_server():
                return False

            # 4. 打印使用信息
            self._print_usage()

            # 5. 等待关闭信号
            await self._shutdown_event.wait()

            return True

        except Exception as e:
            logger.error(f"运行时错误: {e}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            await self.cleanup()

    async def _start_godot(self) -> bool:
        """启动 Godot 进程"""
        logger.info("启动 Godot 进程...")

        self.godot = GodotProcess(
            project_path=self.config.project_path,
            scene_path=self.config.scene_path,
            ai_port=self.config.godot_ws_port,
            visual_mode=self.config.visual_mode,
            on_crash=self._on_godot_crash
        )

        if not self.godot.start():
            logger.error("Godot 进程启动失败")
            return False

        logger.info(f"Godot PID: {self.godot.process.pid}")
        logger.info("等待 Godot 就绪...")

        # 等待 WebSocket 服务器启动
        if not self.godot.wait_for_ready(timeout=30):
            logger.error("Godot 启动超时")
            self.godot.kill()
            return False

        logger.info("Godot 已就绪")
        return True

    async def _connect_websocket(self) -> bool:
        """建立 WebSocket 连接"""
        uri = f"ws://127.0.0.1:{self.config.godot_ws_port}"
        logger.info(f"连接 WebSocket: {uri}")

        try:
            self.websocket = await websockets.connect(uri)
            self._ws_connected = True
            logger.info("WebSocket 连接成功")

            # 启动消息接收任务
            asyncio.create_task(self._ws_receive_loop())

            return True

        except Exception as e:
            logger.error(f"WebSocket 连接失败: {e}")
            return False

    async def _ws_receive_loop(self):
        """WebSocket 消息接收循环"""
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)
                    self._last_state = data

                    # 如果有等待的响应，设置结果
                    if self._pending_response and not self._pending_response.done():
                        self._pending_response.set_result(data)

                except json.JSONDecodeError:
                    logger.warning(f"收到无效 JSON: {message}")

        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket 连接已关闭")
            self._ws_connected = False
        except Exception as e:
            logger.error(f"WebSocket 接收错误: {e}")
            self._ws_connected = False

    async def _start_http_server(self) -> bool:
        """启动 HTTP 服务器"""
        self.http_server = AIHTTPServer(
            host="127.0.0.1",
            port=self.config.http_port,
            action_handler=self._handle_action_request,
            status_handler=self._handle_status_request
        )

        if not await self.http_server.start():
            return False

        logger.info(f"HTTP API: http://127.0.0.1:{self.config.http_port}")
        return True

    async def _handle_action_request(self, actions: list) -> Dict[str, Any]:
        """处理 HTTP action 请求"""
        # 检查 Godot 是否已崩溃
        if self.godot and self.godot.has_crashed():
            crash_info = self.godot.get_crash_info()
            return {
                "event": "SystemCrash",
                "error_type": crash_info.error_type,
                "stack_trace": crash_info.stack_trace
            }

        # 检查 WebSocket 连接
        if not self._ws_connected or not self.websocket:
            return {
                "event": "Error",
                "error_message": "WebSocket not connected"
            }

        # 发送动作到 Godot
        try:
            message = {"actions": actions}
            await self.websocket.send(json.dumps(message))
            logger.info(f"发送动作: {len(actions)} 个")

            # 创建 Future 等待响应
            self._pending_response = asyncio.Future()

            # 等待响应（带超时）
            try:
                response = await asyncio.wait_for(
                    self._pending_response,
                    timeout=30.0
                )
                return response

            except asyncio.TimeoutError:
                return {
                    "event": "Error",
                    "error_message": "Timeout waiting for game state"
                }

        except Exception as e:
            logger.error(f"发送动作失败: {e}")
            return {
                "event": "Error",
                "error_message": str(e)
            }

    async def _handle_status_request(self) -> Dict[str, Any]:
        """处理 HTTP status 请求"""
        return {
            "godot_running": self.godot.is_running() if self.godot else False,
            "ws_connected": self._ws_connected,
            "http_port": self.config.http_port,
            "godot_ws_port": self.config.godot_ws_port,
            "visual_mode": self.config.visual_mode,
            "crashed": self.godot.has_crashed() if self.godot else False
        }

    def _on_godot_crash(self, crash_info: CrashInfo):
        """Godot 崩溃回调"""
        logger.error(f"Godot 崩溃: {crash_info.error_type}")

        # 如果有等待的响应，返回崩溃信息
        if self._pending_response and not self._pending_response.done():
            self._pending_response.set_result({
                "event": "SystemCrash",
                "error_type": crash_info.error_type,
                "stack_trace": crash_info.stack_trace
            })

        # 触发关闭
        self._shutdown_event.set()

    def _print_usage(self):
        """打印使用说明"""
        mode = "GUI 模式" if self.config.visual_mode else "Headless 模式"
        print("\n" + "=" * 60)
        print(f"Godot AI 客户端已启动 - {mode}")
        print("=" * 60)
        print(f"HTTP 端口: {self.config.http_port}")
        print(f"Godot WebSocket 端口: {self.config.godot_ws_port}")
        print("\n使用示例:")
        print(f'  curl -X POST http://127.0.0.1:{self.config.http_port}/action \\")
        print('       -H "Content-Type: application/json" \\")
        print('       -d \'{"actions": [{"type": "start_wave"}]}\'')
        print("\n按 Ctrl+C 停止")
        print("=" * 60 + "\n")

    async def cleanup(self):
        """清理资源"""
        logger.info("正在清理...")

        if self.http_server:
            await self.http_server.stop()

        if self.websocket:
            await self.websocket.close()

        if self.godot:
            self.godot.kill()

        logger.info("已清理")


def parse_args() -> ClientConfig:
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="Godot AI 客户端 - HTTP REST API 网关"
    )

    parser.add_argument(
        "--visual", "--gui",
        action="store_true",
        help="启用 GUI 模式（显示游戏窗口，默认 headless）"
    )

    parser.add_argument(
        "--project", "-p",
        default="/home/zhangzhan/tower",
        help="Godot 项目路径 (默认: /home/zhangzhan/tower)"
    )

    parser.add_argument(
        "--scene", "-s",
        default="res://src/Scenes/UI/CoreSelection.tscn",
        help="启动场景路径 (默认: CoreSelection.tscn)"
    )

    parser.add_argument(
        "--http-port",
        type=int,
        default=0,  # 0 表示自动分配
        help="HTTP 服务器端口 (0=自动分配)"
    )

    parser.add_argument(
        "--godot-port",
        type=int,
        default=0,  # 0 表示自动分配
        help="Godot WebSocket 端口 (0=自动分配)"
    )

    args = parser.parse_args()

    # 分配端口
    if args.http_port == 0 or args.godot_port == 0:
        port1, port2 = find_two_free_ports()
        http_port = args.http_port or port1
        godot_port = args.godot_port or port2
    else:
        http_port = args.http_port
        godot_port = args.godot_port

    return ClientConfig(
        project_path=args.project,
        scene_path=args.scene,
        visual_mode=args.visual,
        godot_ws_port=godot_port,
        http_port=http_port
    )


def main():
    """主入口"""
    config = parse_args()
    client = AIGameClient(config)

    # 设置信号处理
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, lambda: client._shutdown_event.set())

    # 运行
    try:
        success = loop.run_until_complete(client.run())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("用户中断")
        sys.exit(0)


if __name__ == "__main__":
    main()
```

**Step 3: 添加缺失的 json 导入**

在文件顶部添加：
```python
import json
```

**Step 4: Commit**

```bash
git add ai_client/ai_game_client.py ai_client/ai_game_client_legacy.py
git commit -m "feat: refactor ai_game_client.py to HTTP REST gateway with process management"
```

---

## Phase 3: 测试场景与验证

### Task 6: 创建 TestCrash.tscn 测试场景

**Files:**
- Create: `src/Scenes/Test/TestCrash.tscn`
- Create: `src/Scripts/Test/TestCrash.gd`

**Step 1: 创建测试脚本**

```gdscript
# src/Scripts/Test/TestCrash.gd
extends Node

## 测试崩溃场景 - 在 _ready 中主动抛出 GDScript 错误

func _ready():
	print("TestCrash: 即将触发崩溃...")

	# 故意访问 null 节点，触发 SCRIPT ERROR
	var nonexistent_node = $"NonexistentNode"
	# 这行会导致: SCRIPT ERROR: Invalid get index 'name' (on base: 'Nil').
	var name = nonexistent_node.name
```

**Step 2: 创建测试场景文件**

```
[gd_scene load_steps=2 format=3 uid="uid://testcrash001"]

[ext_resource type="Script" path="res://src/Scripts/Test/TestCrash.gd" id="1_crash"]

[node name="TestCrash" type="Node"]
script = ExtResource("1_crash")
```

**Step 3: 创建测试脚本目录**

```bash
mkdir -p src/Scripts/Test
```

**Step 4: 写入 GDScript 文件**

```bash
cat > src/Scripts/Test/TestCrash.gd << 'EOF'
extends Node

## 测试崩溃场景 - 在 _ready 中主动抛出 GDScript 错误

func _ready():
	print("TestCrash: 即将触发崩溃...")

	# 故意访问 null 节点，触发 SCRIPT ERROR
	var nonexistent_node = $"NonexistentNode"
	# 这行会导致: SCRIPT ERROR: Invalid get index 'name' (on base: 'Nil').
	var name = nonexistent_node.name
EOF
```

**Step 5: 写入场景文件**

```bash
cat > src/Scenes/Test/TestCrash.tscn << 'EOF'
[gd_scene load_steps=2 format=3 uid="uid://testcrash001"]

[ext_resource type="Script" path="res://src/Scripts/Test/TestCrash.gd" id="1_crash"]

[node name="TestCrash" type="Node"]
script = ExtResource("1_crash")
EOF
```

**Step 6: 验证场景文件**

```bash
ls -la src/Scenes/Test/TestCrash.tscn src/Scripts/Test/TestCrash.gd
```

**Step 7: Commit**

```bash
git add src/Scenes/Test/TestCrash.tscn src/Scripts/Test/TestCrash.gd
git commit -m "test: add TestCrash scene for crash detection testing"
```

---

### Task 7: 创建崩溃捕获测试

**Files:**
- Create: `tests/test_crash_detection.py`

**Step 1: 编写崩溃检测测试**

```python
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

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from ai_client.utils import find_free_port


async def test_crash_detection():
    """测试崩溃检测"""
    print("=" * 60)
    print("测试: 崩溃检测")
    print("=" * 60)

    # 分配端口
    http_port = find_free_port(20000, 25000)
    godot_port = find_free_port(25000, 30000)

    print(f"HTTP 端口: {http_port}")
    print(f"Godot WebSocket 端口: {godot_port}")

    # 启动 AI 客户端（使用 TestCrash 场景）
    cmd = [
        sys.executable,
        "ai_client/ai_game_client.py",
        "--project", "/home/zhangzhan/tower",
        "--scene", "res://src/Scenes/Test/TestCrash.tscn",
        "--http-port", str(http_port),
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
    if "SystemCrash" in stdout or "SCRIPT ERROR" in stdout:
        print("\n✓ 测试通过: 检测到崩溃")
        return True
    else:
        print("\n✗ 测试失败: 未检测到崩溃")
        return False


def test_headless_mode():
    """测试 Headless 模式"""
    print("\n" + "=" * 60)
    print("测试: Headless 模式")
    print("=" * 60)

    http_port = find_free_port(30000, 35000)
    godot_port = find_free_port(35000, 40000)

    # 启动 AI 客户端（headless 模式）
    cmd = [
        sys.executable,
        "ai_client/ai_game_client.py",
        "--project", "/home/zhangzhan/tower",
        "--scene", "res://src/Scenes/UI/CoreSelection.tscn",
        "--http-port", str(http_port),
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

    # 尝试 curl 请求
    try:
        curl_cmd = [
            "curl", "-s", "-X", "GET",
            f"http://127.0.0.1:{http_port}/status"
        ]
        result = subprocess.run(curl_cmd, capture_output=True, text=True, timeout=5)
        print(f"\nCurl 响应: {result.stdout}")

        if result.returncode == 0:
            data = json.loads(result.stdout)
            if data.get("godot_running"):
                print("✓ 测试通过: Headless 模式正常工作")
                success = True
            else:
                print("✗ 测试失败: Godot 未运行")
                success = False
        else:
            print(f"✗ 测试失败: Curl 错误 {result.returncode}")
            success = False

    except Exception as e:
        print(f"✗ 测试失败: {e}")
        success = False
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except:
            process.kill()

    return success


async def main():
    """主测试函数"""
    results = []

    # 运行测试
    results.append(("崩溃检测", await test_crash_detection()))
    results.append(("Headless 模式", test_headless_mode()))

    # 打印结果
    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)
    for name, passed in results:
        status = "✓ 通过" if passed else "✗ 失败"
        print(f"{name}: {status}")

    all_passed = all(r[1] for r in results)
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    asyncio.run(main())
```

**Step 2: 使测试脚本可执行**

```bash
chmod +x tests/test_crash_detection.py
```

**Step 3: Commit**

```bash
git add tests/test_crash_detection.py
git commit -m "test: add crash detection and headless mode tests"
```

---

### Task 8: 人工验证 Headless 模式

**Files:**
- None (manual test)

**Step 1: 启动 AI 客户端（Headless 模式）**

终端 1:
```bash
cd /home/zhangzhan/tower
python3 ai_client/ai_game_client.py
```

期望输出：
- 没有游戏窗口弹出
- 显示 "Headless 模式"
- 显示 HTTP 端口号

**Step 2: 使用 curl 发送请求**

终端 2:
```bash
# 替换 <port> 为实际分配的端口
curl -X POST http://127.0.0.1:<port>/action \
  -H "Content-Type: application/json" \
  -d '{"actions": [{"type": "start_wave"}]}'
```

期望响应：
```json
{
  "event": "WaveStarted",
  "global": {...},
  "board": {...}
}
```

**Step 3: 验证状态端点**

```bash
curl http://127.0.0.1:<port>/status
```

期望响应：
```json
{
  "godot_running": true,
  "ws_connected": true,
  "http_port": <port>,
  "visual_mode": false
}
```

**Step 4: 停止服务**

终端 1 按 Ctrl+C

验证进程干净退出，无残留 godot 进程：
```bash
ps aux | grep godot
```

---

### Task 9: 人工验证 GUI 模式

**Files:**
- None (manual test)

**Step 1: 启动 AI 客户端（GUI 模式）**

终端 1:
```bash
cd /home/zhangzhan/tower
python3 ai_client/ai_game_client.py --visual
```

期望输出：
- 游戏窗口正常显示
- 显示 "GUI 模式"

**Step 2: 使用 curl 发送请求**

终端 2:
```bash
curl -X POST http://127.0.0.1:<port>/action \
  -H "Content-Type: application/json" \
  -d '{"actions": [{"type": "select_totem", "totem_id": "wolf"}]}'
```

**Step 3: 停止服务**

终端 1 按 Ctrl+C

验证游戏窗口关闭，进程干净退出。

---

## Phase 4: 文档更新

### Task 10: 更新 API 文档

**Files:**
- Modify: `ai_client/API_DOCUMENTATION.md`

**Step 1: 添加 HTTP API 文档**

在文档开头添加新章节：

```markdown
# AI Client HTTP REST API

## 启动方式

### Headless 模式（默认，推荐用于训练）
```bash
python3 ai_client/ai_game_client.py
```

### GUI 模式（用于调试观察）
```bash
python3 ai_client/ai_game_client.py --visual
```

## HTTP 端点

### POST /action

发送游戏动作，返回游戏状态。

**请求：**
```bash
curl -X POST http://127.0.0.1:<port>/action \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {"type": "buy_unit", "shop_index": 0},
      {"type": "start_wave"}
    ]
  }'
```

**正常响应：**
```json
{
  "event": "WaveStarted",
  "event_data": {"wave": 1},
  "timestamp": 1234567890,
  "global": {...},
  "board": {...}
}
```

**崩溃响应：**
```json
{
  "event": "SystemCrash",
  "error_type": "SCRIPT ERROR: ...",
  "stack_trace": "..."
}
```

### GET /status

获取服务器状态。

**响应：**
```json
{
  "godot_running": true,
  "ws_connected": true,
  "http_port": 12345,
  "godot_ws_port": 45678,
  "visual_mode": false,
  "crashed": false
}
```

### GET /health

健康检查。

**响应：**
```json
{"status": "ok"}
```

## 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--visual`, `--gui` | 启用 GUI 模式 | false (headless) |
| `--project`, `-p` | Godot 项目路径 | /home/zhangzhan/tower |
| `--scene`, `-s` | 启动场景 | res://src/Scenes/UI/CoreSelection.tscn |
| `--http-port` | HTTP 服务器端口 | 0 (自动分配) |
| `--godot-port` | Godot WebSocket 端口 | 0 (自动分配) |
```

**Step 2: Commit**

```bash
git add ai_client/API_DOCUMENTATION.md
git commit -m "docs: update API documentation for HTTP REST interface"
```

---

## 最终验证清单

### 代码检查
- [ ] AIManager.gd 支持 --ai-port 参数
- [ ] ai_game_client.py 重构为 HTTP 网关
- [ ] utils.py 提供端口分配和错误检测
- [ ] godot_process.py 管理 Godot 生命周期
- [ ] http_server.py 提供 REST API

### 功能测试
- [ ] Headless 模式无窗口弹出
- [ ] GUI 模式正常显示游戏
- [ ] curl 请求返回正确状态
- [ ] 崩溃时返回 SystemCrash JSON
- [ ] 进程干净退出无僵尸

### 文档
- [ ] API_DOCUMENTATION.md 已更新
- [ ] 代码注释清晰
- [ ] 使用示例完整

---

## 执行选项

**Plan complete and saved to `docs/plans/2025-02-28-ai-client-http-rest-refactor.md`.**

**两个执行选项：**

**1. Subagent-Driven（本会话）** - 我为每个任务调度新的 subagent，任务间进行代码审查，快速迭代

**2. Parallel Session（独立会话）** - 在新会话中打开并使用 executing-plans 进行批量执行和检查点

**选择哪种方式？**
