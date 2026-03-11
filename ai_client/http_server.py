"""HTTP REST API 服务器 - 接收外部请求，转发给 WebSocket"""
import json
import logging
from typing import Optional, Callable, Awaitable, Dict, Any
from aiohttp import web

logger = logging.getLogger(__name__)

ActionHandler = Callable[[Dict[str, Any]], Awaitable[Dict[str, Any]]]
StatusHandler = Callable[[], Awaitable[Dict[str, Any]]]
ObservationsHandler = Callable[[Dict[str, Any]], Awaitable[Dict[str, Any]]]


class AIHTTPServer:
    """HTTP REST API 服务器。"""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 8080,
        action_handler: Optional[ActionHandler] = None,
        status_handler: Optional[StatusHandler] = None,
        observations_handler: Optional[ObservationsHandler] = None,
    ):
        self.host = host
        self.port = port
        self.action_handler = action_handler
        self.status_handler = status_handler
        self.observations_handler = observations_handler

        self.app = web.Application()
        self.runner: Optional[web.AppRunner] = None
        self.site: Optional[web.TCPSite] = None

        self.app.router.add_post("/action", self._handle_action)
        self.app.router.add_get("/status", self._handle_status)
        self.app.router.add_get("/health", self._handle_health)
        self.app.router.add_get("/observations", self._handle_observations)

    async def start(self) -> bool:
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
        if self.runner:
            await self.runner.cleanup()
            logger.info("HTTP 服务器已停止")

    async def _handle_action(self, request: web.Request) -> web.Response:
        try:
            body = await request.json()
            if not isinstance(body, dict):
                return web.json_response({"error": "request body must be an object"}, status=400)

            actions = body.get("actions", [])
            if not isinstance(actions, list):
                return web.json_response({"error": "actions must be an array"}, status=400)

            if self.action_handler:
                result = await self.action_handler(body)
                return web.json_response(result)

            return web.json_response({"error": "Action handler not configured"}, status=503)
        except json.JSONDecodeError:
            return web.json_response({"error": "Invalid JSON"}, status=400)
        except Exception as e:
            logger.error(f"处理 action 请求时出错: {e}")
            return web.json_response({"error": str(e)}, status=500)

    async def _handle_status(self, request: web.Request) -> web.Response:
        if self.status_handler:
            status = await self.status_handler()
            return web.json_response(status)
        return web.json_response({"status": "running", "http_port": self.port})

    async def _handle_health(self, request: web.Request) -> web.Response:
        return web.json_response({"status": "ok"})

    async def _handle_observations(self, request: web.Request) -> web.Response:
        if self.observations_handler:
            query = {k: v for k, v in request.query.items()}
            observations = await self.observations_handler(query)
            return web.json_response(observations)
        return web.json_response({"events": [], "next_seq": 0})
