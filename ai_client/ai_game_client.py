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
import json
import logging
import sys
import signal
from pathlib import Path
from typing import Optional, Dict, Any
from dataclasses import dataclass

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

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
                    logger.debug(f"收到 WebSocket 消息: {data.get('event', 'unknown')}")

                    # 如果有等待的响应，设置结果
                    if self._pending_response and not self._pending_response.done():
                        self._pending_response.set_result(data)
                        logger.info(f"响应已设置: {data.get('event', 'unknown')}")
                    else:
                        # 没有等待的请求，只是更新状态
                        event_type = data.get('event', 'unknown')
                        if event_type != 'AI_Wakeup':  # 减少日志噪音
                            logger.info(f"收到未请求的状态更新: {event_type}")

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
            # 创建 Future 等待响应（必须先创建，避免响应到达时 Future 不存在）
            self._pending_response = asyncio.Future()

            message = {"actions": actions}
            await self.websocket.send(json.dumps(message))
            logger.info(f"发送动作: {len(actions)} 个")

            # 等待响应（带超时）
            try:
                response = await asyncio.wait_for(
                    self._pending_response,
                    timeout=30.0
                )
                return response

            except asyncio.TimeoutError:
                # 如果超时，返回最后一次收到的状态
                if self._last_state:
                    logger.warning(f"等待响应超时，返回最后一次状态: {self._last_state.get('event', 'unknown')}")
                    return self._last_state
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
        print(f'  curl -X POST http://127.0.0.1:{self.config.http_port}/action \\')
        print('       -H "Content-Type: application/json" \\')
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
