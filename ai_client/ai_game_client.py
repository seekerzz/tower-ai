#!/usr/bin/env python3
"""
Godot AI 游戏客户端 - WebSocket 代理网关

用法:
    # Headless 模式（默认，无图形界面）
    python3 ai_game_client.py

    # GUI 模式（显示游戏窗口）
    python3 ai_game_client.py --visual

    # 指定场景
    python3 ai_game_client.py --scene res://src/Scenes/UI/MainGUI.tscn

WebSocket API:
    - 连接 Agent WebSocket 端口
    - 下行: 自动收到包含 narrative 等事件的 JSON
    - 上行: 发送类似 {"actions": [{"type": "start_wave"}]} 的 JSON 给 Godot
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
from typing import Optional, Dict, Any
from dataclasses import dataclass

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

import websockets

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


class AIGameClient:
    """
    AI 游戏客户端 - HTTP 网关 + WebSocket 桥接

    架构:
    1. 启动 Godot 子进程（headless 或 GUI）
    2. 建立 WebSocket 连接到 Godot (下行)
    3. 启动本地 WebSocket Server 供外部 Agent 连接 (上行)
    4. 将 Godot 的事件透明转发给所有已连接的 Agents，并将 Agents 的指令转发给 Godot
    5. 将带 narrative 的事件落盘到本地日志文件
    """

    def __init__(self, config: ClientConfig):
        self.config = config
        self.godot: Optional[GodotProcess] = None
        self.godot_ws: Optional[websockets.WebSocketClientProtocol] = None
        self.agent_ws_server = None
        self.connected_agents = set()
        self._shutdown_event = asyncio.Event()
        self._ws_connected = False

        # 为日志系统
        self.log_dir = "logs"
        self.log_file = None
        self._init_logger()

    def _init_logger(self):
        """初始化日志落盘系统"""
        if not os.path.exists(self.log_dir):
            os.makedirs(self.log_dir, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = os.path.join(self.log_dir, f"ai_session_{timestamp}.log")
        logger.info(f"AI 会话日志: {self.log_file}")

        # 初始化文件，写入一条启动信息
        try:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(f"=== AI Session Started at {datetime.now()} ===\n")
        except Exception as e:
            logger.error(f"无法初始化日志文件: {e}")
            self.log_file = None

    def _append_to_log(self, text: str):
        if not self.log_file:
            return
        try:
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(text + "\n")
        except Exception as e:
            logger.error(f"写入日志失败: {e}")

    async def run(self):
        """主运行循环"""
        try:
            # 1. 启动 Godot
            if not await self._start_godot():
                return False

            # 2. 连接到 Godot WebSocket
            if not await self._connect_godot_websocket():
                return False

            # 3. 启动 Agent WebSocket 服务器
            if not await self._start_agent_websocket_server():
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

    async def _connect_godot_websocket(self) -> bool:
        """建立 WebSocket 连接到 Godot"""
        uri = f"ws://127.0.0.1:{self.config.godot_ws_port}"
        logger.info(f"连接 Godot WebSocket: {uri}")

        try:
            self.godot_ws = await websockets.connect(uri)
            self._ws_connected = True
            logger.info("Godot WebSocket 连接成功")

            # 启动消息接收任务
            asyncio.create_task(self._godot_ws_receive_loop())

            return True

        except Exception as e:
            logger.error(f"Godot WebSocket 连接失败: {e}")
            return False

    async def _godot_ws_receive_loop(self):
        """Godot WebSocket 消息接收循环"""
        try:
            async for message in self.godot_ws:
                await self._process_godot_message(message)
        except websockets.exceptions.ConnectionClosed:
            logger.info("Godot WebSocket 连接已关闭")
            self._ws_connected = False
        except Exception as e:
            logger.error(f"Godot WebSocket 接收错误: {e}")
            self._ws_connected = False

    async def _process_godot_message(self, message: str):
        """处理来自 Godot 的消息，转发给所有 Agent 并落盘"""

        # 日志落盘
        try:
            data = json.loads(message)
            if 'narrative' in data:
                self._append_to_log(f"Raw JSON: {message}")
                self._append_to_log(f"Narrative: {data['narrative']}")
                self._append_to_log("-" * 40)
        except json.JSONDecodeError:
            pass

        # 转发给所有已连接的 Agent
        disconnected = set()
        for agent in self.connected_agents:
            try:
                await agent.send(message)
            except websockets.exceptions.ConnectionClosed:
                disconnected.add(agent)

        for agent in disconnected:
            self.connected_agents.remove(agent)

    async def _start_agent_websocket_server(self) -> bool:
        """启动 Agent WebSocket 服务器"""
        try:
            self.agent_ws_server = await websockets.serve(
                self._handle_agent_connection,
                "127.0.0.1",
                self.config.agent_ws_port
            )
            logger.info(f"Agent WebSocket 服务器已启动: ws://127.0.0.1:{self.config.agent_ws_port}")
            return True
        except Exception as e:
            logger.error(f"启动 Agent WebSocket 服务器失败: {e}")
            return False

    async def _handle_agent_connection(self, websocket):
        """处理单个 Agent 连接"""
        logger.info(f"Agent 已连接: {websocket.remote_address}")
        self.connected_agents.add(websocket)
        try:
            async for message in websocket:
                await self._handle_agent_message(message, websocket)
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Agent 已断开: {websocket.remote_address}")
        except Exception as e:
            logger.error(f"Agent 连接错误: {e}")
        finally:
            if websocket in self.connected_agents:
                self.connected_agents.remove(websocket)

    async def _handle_agent_message(self, message: str, websocket):
        """处理来自 Agent 的消息，转发给 Godot"""
        if self.godot_ws and self._ws_connected:
            try:
                await self.godot_ws.send(message)
            except Exception as e:
                logger.error(f"转发消息给 Godot 失败: {e}")
        else:
            logger.warning("Godot WebSocket 未连接，丢弃 Agent 消息")

    def _on_godot_crash(self, crash_info: CrashInfo):
        """Godot 崩溃回调"""
        logger.error(f"Godot 崩溃: {crash_info.error_type}")

        # 发送崩溃消息给所有代理
        crash_msg = json.dumps({
            "event": "SystemCrash",
            "error_type": crash_info.error_type,
            "stack_trace": crash_info.stack_trace
        })
        # Note: asyncio.create_task is safe here for non-async context if loop is running
        for agent in self.connected_agents:
            asyncio.create_task(agent.send(crash_msg))

        # 触发关闭
        self._shutdown_event.set()

    def _print_usage(self):
        """打印使用说明"""
        mode = "GUI 模式" if self.config.visual_mode else "Headless 模式"
        print("\n" + "=" * 60)
        print(f"Godot AI 客户端已启动 - {mode}")
        print("=" * 60)
        print(f"Agent WebSocket 端口: {self.config.agent_ws_port}")
        print(f"Godot WebSocket 端口: {self.config.godot_ws_port}")
        print("\n使用示例:")
        print(f'  wscat -c ws://127.0.0.1:{self.config.agent_ws_port}')
        print("\n按 Ctrl+C 停止")
        print("=" * 60 + "\n")

    async def cleanup(self):
        """清理资源"""
        logger.info("正在清理...")

        if self.agent_ws_server:
            self.agent_ws_server.close()
            await self.agent_ws_server.wait_closed()

        if self.godot_ws:
            await self.godot_ws.close()

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
        "--agent-ws-port",
        type=int,
        default=0,  # 0 表示自动分配
        help="Agent WebSocket 端口 (0=自动分配)"
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
