#!/usr/bin/env python3
"""
Godot AI 游戏客户端 - 双向 WebSocket 代理

用法:
    # Headless 模式（默认，无图形界面）
    python3 ai_game_client.py

    # GUI 模式（显示游戏窗口）
    python3 ai_game_client.py --visual

    # 指定场景
    python3 ai_game_client.py --scene res://src/Scenes/UI/MainGUI.tscn

WebSocket Proxy:
    Agent连接到 --agent-ws-port，向游戏发送action，接收游戏的实时state和narrative。
"""

import asyncio
import argparse
import json
import logging
import sys
import signal
import os
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any, Set
from dataclasses import dataclass

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

import websockets
from websockets.server import serve, WebSocketServerProtocol

from ai_client.utils import find_two_free_ports
from ai_client.godot_process import GodotProcess, CrashInfo

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
    agent_ws_port: int
    log_dir: str = "logs"


class AIGameClient:
    """
    AI 游戏客户端 - WebSocket 代理
    """

    def __init__(self, config: ClientConfig):
        self.config = config
        self.godot: Optional[GodotProcess] = None

        self.godot_websocket: Optional[websockets.WebSocketClientProtocol] = None
        self._ws_connected = False

        self.agent_websockets: Set[WebSocketServerProtocol] = set()

        self._shutdown_event = asyncio.Event()
        self._last_state: Optional[Dict] = None

        self._init_logging()

    def _init_logging(self):
        """初始化日志持久化"""
        os.makedirs(self.config.log_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file_path = os.path.join(self.config.log_dir, f"ai_session_{timestamp}.log")
        logger.info(f"会话日志将保存在: {self.log_file_path}")

    async def _process_and_log_message(self, message: str):
        """处理来自 Godot 的消息，提取 narrative 并落盘"""
        try:
            data = json.loads(message)
            self._last_state = data
            event_type = data.get('event', 'unknown')

            # 记录完整的通信日志以及提取的 narrative
            narrative = data.get('narrative')

            # 以追加模式写入完整的通信日志
            with open(self.log_file_path, "a", encoding="utf-8") as f:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                f.write(f"[{timestamp}] [RAW JSON] {message}\n")
                if narrative:
                    f.write(f"[{timestamp}] [NARRATIVE] {narrative}\n")

            if event_type != 'Ping':
                logger.debug(f"收到 Godot 消息: {event_type}")

            # 转发给所有连接的 AI Agent
            if self.agent_websockets:
                tasks = []
                for agent_ws in self.agent_websockets:
                    tasks.append(asyncio.create_task(agent_ws.send(message)))
                if tasks:
                    await asyncio.gather(*tasks, return_exceptions=True)

        except json.JSONDecodeError:
            logger.warning(f"收到无效 JSON: {message}")
        except Exception as e:
            logger.error(f"处理并转发 Godot 消息时出错: {e}")

    async def _forward_to_godot(self, message: str):
        """将 AI Agent 的消息转发给 Godot"""
        if self._ws_connected and self.godot_websocket:
            try:
                await self.godot_websocket.send(message)
                logger.info(f"成功将消息转发给 Godot: {message[:100]}...")
            except Exception as e:
                logger.error(f"转发给 Godot 失败: {e}")
        else:
            logger.warning("Godot WebSocket 未连接，无法转发消息")

    async def _handle_agent_connection(self, websocket: WebSocketServerProtocol, path: str = ""):
        """处理外部 AI Agent 的 WebSocket 连接"""
        logger.info(f"AI Agent 已连接: {websocket.remote_address}")
        self.agent_websockets.add(websocket)
        try:
            async for message in websocket:
                # 收到来自 AI Agent 的请求，透传给 Godot
                logger.debug(f"收到来自 AI Agent 的消息: {message[:100]}...")
                await self._forward_to_godot(message)
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"AI Agent 断开连接: {websocket.remote_address}")
        except Exception as e:
            logger.error(f"处理 AI Agent 消息时出错: {e}")
        finally:
            self.agent_websockets.remove(websocket)

    async def run(self):
        """主运行循环"""
        try:
            # 1. 启动 Godot
            if not await self._start_godot():
                return False

            # 2. 连接到 Godot WebSocket
            if not await self._connect_godot_websocket():
                return False

            # 3. 启动 Agent WebSocket 代理服务器
            server = await serve(self._handle_agent_connection, "127.0.0.1", self.config.agent_ws_port)
            logger.info(f"Agent WebSocket 代理服务器已启动，监听端口: {self.config.agent_ws_port}")

            # 4. 打印使用信息
            self._print_usage()

            # 5. 等待关闭信号
            await self._shutdown_event.wait()

            server.close()
            await server.wait_closed()
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

    async def _connect_godot_websocket(self) -> bool:
        """建立与 Godot 的 WebSocket 连接"""
        uri = f"ws://127.0.0.1:{self.config.godot_ws_port}"
        logger.info(f"连接 Godot WebSocket: {uri}")

        try:
            self.godot_websocket = await websockets.connect(uri)
            self._ws_connected = True
            logger.info("Godot WebSocket 连接成功")

            # 启动消息接收任务
            asyncio.create_task(self._godot_receive_loop())

            return True

        except Exception as e:
            logger.error(f"Godot WebSocket 连接失败: {e}")
            return False

    async def _godot_receive_loop(self):
        """接收 Godot WebSocket 消息并分发"""
        try:
            async for message in self.godot_websocket:
                await self._process_and_log_message(message)

        except websockets.exceptions.ConnectionClosed:
            logger.info("Godot WebSocket 连接已关闭")
            self._ws_connected = False
        except Exception as e:
            logger.error(f"Godot WebSocket 接收错误: {e}")
            self._ws_connected = False

    def _on_godot_crash(self, crash_info: CrashInfo):
        """Godot 崩溃回调"""
        logger.error(f"Godot 崩溃: {crash_info.error_type}")

        # 通知所有 Agent
        crash_msg = json.dumps({
            "event": "SystemCrash",
            "error_type": crash_info.error_type,
            "stack_trace": crash_info.stack_trace
        })

        for agent_ws in self.agent_websockets:
            asyncio.create_task(agent_ws.send(crash_msg))

        # 触发关闭
        self._shutdown_event.set()

    def _print_usage(self):
        """打印使用说明"""
        mode = "GUI 模式" if self.config.visual_mode else "Headless 模式"
        print("\n" + "=" * 60)
        print(f"Godot AI 客户端已启动 - {mode}")
        print("=" * 60)
        print(f"Godot 内部 WebSocket 端口: {self.config.godot_ws_port}")
        print(f"Agent WebSocket 端口: {self.config.agent_ws_port}")
        print("\n使用示例 (连接并监听):")
        print(f'  python3 -m websockets ws://127.0.0.1:{self.config.agent_ws_port}')
        print("\n按 Ctrl+C 停止")
        print("=" * 60 + "\n")

    async def cleanup(self):
        """清理资源"""
        logger.info("正在清理...")

        if self.godot_websocket:
            await self.godot_websocket.close()

        # 强制关闭所有 Agent 连接
        for agent_ws in list(self.agent_websockets):
            await agent_ws.close()

        if self.godot:
            self.godot.kill()

        logger.info("已清理")


def parse_args() -> ClientConfig:
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="Godot AI 客户端 - 双向 WebSocket 代理"
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
        "--agent-ws-port",
        type=int,
        default=0,  # 0 表示自动分配
        help="AI Agent WebSocket 端口 (0=自动分配)"
    )

    parser.add_argument(
        "--godot-port",
        type=int,
        default=0,  # 0 表示自动分配
        help="Godot WebSocket 端口 (0=自动分配)"
    )

    args = parser.parse_args()

    # 分配端口
    if args.agent_ws_port == 0 or args.godot_port == 0:
        port1, port2 = find_two_free_ports()
        agent_ws_port = args.agent_ws_port or port1
        godot_port = args.godot_port or port2
    else:
        agent_ws_port = args.agent_ws_port
        godot_port = args.godot_port

    return ClientConfig(
        project_path=args.project,
        scene_path=args.scene,
        visual_mode=args.visual,
        godot_ws_port=godot_port,
        agent_ws_port=agent_ws_port
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
