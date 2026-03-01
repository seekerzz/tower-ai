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
