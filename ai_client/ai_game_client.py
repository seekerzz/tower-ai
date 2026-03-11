#!/usr/bin/env python3
"""Godot AI 游戏客户端 - 非阻塞 HTTP 网关 + WebSocket 桥接。"""

import argparse
import asyncio
import json
import logging
import signal
import sys
import uuid
from collections import deque
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any, Deque, List

sys.path.insert(0, str(Path(__file__).parent.parent))

import websockets

from ai_client.utils import find_two_free_ports, GodotIssue
from ai_client.godot_process import GodotProcess, CrashInfo
from ai_client.http_server import AIHTTPServer

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class ClientConfig:
    project_path: str
    scene_path: str
    visual_mode: bool
    godot_ws_port: int
    http_port: int


@dataclass
class ActionEnvelope:
    request_id: str
    actions: list
    submitted_ts_ms: int
    ttl_ms: int
    apply_mode: str


@dataclass
class EventRecord:
    seq: int
    session_id: str
    ts_ms: int
    source: str
    event_type: str
    payload: Dict[str, Any]
    request_id: Optional[str] = None


class AIGameClient:
    """非阻塞 AI Gateway。"""

    def __init__(self, config: ClientConfig):
        self.config = config
        self.godot: Optional[GodotProcess] = None
        self.websocket: Optional[websockets.WebSocketClientProtocol] = None
        self.http_server: Optional[AIHTTPServer] = None

        self._shutdown_event = asyncio.Event()
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._ws_connected = False

        self._session_id = datetime.now().strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
        self._seq = 0
        self._event_buffer: Deque[EventRecord] = deque(maxlen=50000)
        self._event_cond = asyncio.Condition()

        self._action_queue: asyncio.Queue[ActionEnvelope] = asyncio.Queue(maxsize=1000)
        self._scheduler_task: Optional[asyncio.Task] = None
        self._ws_task: Optional[asyncio.Task] = None

        self._log_dir = Path("logs")
        self._log_dir.mkdir(exist_ok=True)
        self._event_log_file = self._log_dir / f"ai_session_{self._session_id}.jsonl"

    async def run(self):
        self._loop = asyncio.get_running_loop()
        try:
            if not await self._start_godot():
                return False

            if self.godot and not self.godot.has_crashed() and not await self._connect_websocket():
                return False

            if not await self._start_http_server():
                return False

            self._scheduler_task = asyncio.create_task(self._action_scheduler_loop())
            self._print_usage()
            await self._shutdown_event.wait()
            return True
        except Exception as e:
            logger.error(f"运行时错误: {e}")
            return False
        finally:
            await self.cleanup()

    async def _start_godot(self) -> bool:
        logger.info("启动 Godot 进程...")
        self.godot = GodotProcess(
            project_path=self.config.project_path,
            scene_path=self.config.scene_path,
            ai_port=self.config.godot_ws_port,
            visual_mode=self.config.visual_mode,
            on_crash=self._on_godot_crash,
            on_issue=self._on_godot_issue,
            on_output=self._on_godot_output,
        )

        if not self.godot.start():
            logger.error("Godot 进程启动失败")
            return False

        logger.info(f"Godot PID: {self.godot.process.pid}")
        logger.info("等待 Godot 就绪...")

        if not self.godot.wait_for_ready(timeout=30):
            if self.godot.has_crashed():
                logger.error("Godot 启动时崩溃")
            else:
                logger.error("Godot 启动超时")
                self.godot.kill()
                return False

        logger.info("Godot 已就绪")
        await self._publish_event("gateway", "godot_ready", {"pid": self.godot.process.pid if self.godot.process else None})
        return True

    async def _connect_websocket(self) -> bool:
        uri = f"ws://127.0.0.1:{self.config.godot_ws_port}"
        logger.info(f"连接 WebSocket: {uri}")
        try:
            self.websocket = await websockets.connect(uri)
            self._ws_connected = True
            await self._publish_event("gateway", "ws_connected", {"uri": uri})
            self._ws_task = asyncio.create_task(self._ws_receive_loop())
            return True
        except Exception as e:
            logger.error(f"WebSocket 连接失败: {e}")
            await self._publish_event("gateway", "ws_connect_failed", {"error": str(e)})
            return False

    async def _ws_receive_loop(self):
        try:
            async for raw in self.websocket:
                event_payload: Dict[str, Any]
                event_type = "godot_text"
                request_id = None
                parsed = None
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError:
                    parsed = None

                if isinstance(parsed, dict):
                    event_type = "godot_event"
                    request_id = parsed.get("request_id")
                    event_payload = {"raw": raw, "json": parsed}
                    if "event" in parsed:
                        event_type = f"game_{parsed['event']}"
                else:
                    event_payload = {"raw": raw}

                await self._publish_event("godot_ws", event_type, event_payload, request_id=request_id)

        except websockets.exceptions.ConnectionClosed:
            self._ws_connected = False
            await self._publish_event("gateway", "ws_disconnected", {"reason": "connection_closed"})
        except Exception as e:
            logger.error(f"WebSocket 接收错误: {e}")
            self._ws_connected = False
            await self._publish_event("gateway", "ws_receive_error", {"error": str(e)})

    async def _action_scheduler_loop(self):
        while not self._shutdown_event.is_set():
            envelope = await self._action_queue.get()
            now_ms = int(datetime.now().timestamp() * 1000)

            if now_ms - envelope.submitted_ts_ms > envelope.ttl_ms:
                await self._publish_event(
                    "scheduler",
                    "action_rejected_expired",
                    {"ttl_ms": envelope.ttl_ms, "actions": envelope.actions},
                    request_id=envelope.request_id,
                )
                self._action_queue.task_done()
                continue

            if not self.websocket or not self._ws_connected:
                await self._publish_event(
                    "scheduler",
                    "action_rejected_ws_not_connected",
                    {"actions": envelope.actions},
                    request_id=envelope.request_id,
                )
                self._action_queue.task_done()
                continue

            # next_safe_tick: 在网关端体现为异步发送（不阻塞主流程）
            if envelope.apply_mode == "next_safe_tick":
                await asyncio.sleep(0)

            msg = {"actions": envelope.actions, "request_id": envelope.request_id}
            try:
                await self.websocket.send(json.dumps(msg, ensure_ascii=False))
                await self._publish_event(
                    "scheduler",
                    "action_forwarded",
                    {"actions": envelope.actions, "queue_depth": self._action_queue.qsize()},
                    request_id=envelope.request_id,
                )
            except Exception as e:
                await self._publish_event(
                    "scheduler",
                    "action_forward_failed",
                    {"error": str(e), "actions": envelope.actions},
                    request_id=envelope.request_id,
                )
            finally:
                self._action_queue.task_done()

    async def _start_http_server(self) -> bool:
        self.http_server = AIHTTPServer(
            host="127.0.0.1",
            port=self.config.http_port,
            action_handler=self._handle_action_request,
            status_handler=self._handle_status_request,
            observations_handler=self._handle_observations_request,
        )
        if not await self.http_server.start():
            return False

        logger.info(f"HTTP API: http://127.0.0.1:{self.config.http_port}")
        await self._publish_event("gateway", "http_started", {"port": self.config.http_port})
        return True

    async def _handle_action_request(self, body: Dict[str, Any]) -> Dict[str, Any]:
        if self.godot and self.godot.has_crashed():
            crash_info = self.godot.get_crash_info()
            return {
                "event": "SystemCrash",
                "error_type": crash_info.error_type if crash_info else "unknown",
                "stack_trace": crash_info.stack_trace if crash_info else "",
            }

        request_id = body.get("request_id") or uuid.uuid4().hex
        actions = body.get("actions", [])
        ttl_ms = int(body.get("ttl_ms", 30000))
        apply_mode = body.get("apply_mode", "next_safe_tick")

        envelope = ActionEnvelope(
            request_id=request_id,
            actions=actions,
            submitted_ts_ms=int(datetime.now().timestamp() * 1000),
            ttl_ms=ttl_ms,
            apply_mode=apply_mode,
        )

        try:
            self._action_queue.put_nowait(envelope)
        except asyncio.QueueFull:
            await self._publish_event("gateway", "action_rejected_backpressure", {"actions": actions}, request_id=request_id)
            return {
                "status": "rejected",
                "reason": "queue_full",
                "request_id": request_id,
                "queue_depth": self._action_queue.qsize(),
            }

        await self._publish_event(
            "gateway",
            "action_submitted",
            {
                "actions": actions,
                "apply_mode": apply_mode,
                "ttl_ms": ttl_ms,
                "queue_depth": self._action_queue.qsize(),
            },
            request_id=request_id,
        )

        return {
            "status": "accepted",
            "request_id": request_id,
            "accepted_at": int(datetime.now().timestamp() * 1000),
            "queue_depth": self._action_queue.qsize(),
            "estimated_apply_tick": "next_safe_tick",
        }

    async def _handle_status_request(self) -> Dict[str, Any]:
        return {
            "godot_running": self.godot.is_running() if self.godot else False,
            "ws_connected": self._ws_connected,
            "http_port": self.config.http_port,
            "godot_ws_port": self.config.godot_ws_port,
            "visual_mode": self.config.visual_mode,
            "crashed": self.godot.has_crashed() if self.godot else False,
            "session_id": self._session_id,
            "event_buffer_size": len(self._event_buffer),
            "action_queue_depth": self._action_queue.qsize(),
            "next_seq": self._seq + 1,
        }

    async def _handle_observations_request(self, query: Dict[str, Any]) -> Dict[str, Any]:
        after_seq = int(query.get("after_seq", 0))
        limit = max(1, min(2000, int(query.get("limit", 200))))
        wait_ms = max(0, min(30000, int(query.get("wait_ms", 0))))

        events = self._slice_events(after_seq=after_seq, limit=limit)
        if not events and wait_ms > 0:
            timeout = wait_ms / 1000.0
            try:
                async with self._event_cond:
                    await asyncio.wait_for(self._event_cond.wait(), timeout=timeout)
            except asyncio.TimeoutError:
                pass
            events = self._slice_events(after_seq=after_seq, limit=limit)

        next_seq = events[-1]["seq"] if events else after_seq
        return {
            "session_id": self._session_id,
            "events": events,
            "next_seq": next_seq,
            "has_more": bool(self._event_buffer and self._event_buffer[-1].seq > next_seq),
            "buffer_tail_seq": self._event_buffer[-1].seq if self._event_buffer else 0,
        }

    def _slice_events(self, after_seq: int, limit: int) -> List[Dict[str, Any]]:
        selected = [asdict(e) for e in self._event_buffer if e.seq > after_seq]
        return selected[:limit]

    async def _publish_event(
        self,
        source: str,
        event_type: str,
        payload: Dict[str, Any],
        request_id: Optional[str] = None,
    ):
        self._seq += 1
        record = EventRecord(
            seq=self._seq,
            session_id=self._session_id,
            ts_ms=int(datetime.now().timestamp() * 1000),
            source=source,
            event_type=event_type,
            payload=payload,
            request_id=request_id,
        )
        self._event_buffer.append(record)
        try:
            with open(self._event_log_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(asdict(record), ensure_ascii=False) + "\n")
        except Exception as e:
            logger.error(f"写入事件日志失败: {e}")

        async with self._event_cond:
            self._event_cond.notify_all()

    def _on_godot_output(self, line: str):
        if self._loop and not self._loop.is_closed():
            asyncio.run_coroutine_threadsafe(
                self._publish_event("godot_proc", "godot_stdout", {"line": line}),
                self._loop,
            )

    def _on_godot_issue(self, issue: GodotIssue):
        if self._loop and not self._loop.is_closed():
            asyncio.run_coroutine_threadsafe(
                self._publish_event("godot_proc", f"godot_{issue.severity}", {"category": issue.category, "line": issue.line}),
                self._loop,
            )

    def _on_godot_crash(self, crash_info: CrashInfo):
        logger.error(f"Godot 崩溃: {crash_info.error_type}")
        payload = {
            "error_type": crash_info.error_type,
            "stack_trace": crash_info.stack_trace,
            "timestamp": crash_info.timestamp,
        }
        if self._loop and not self._loop.is_closed():
            asyncio.run_coroutine_threadsafe(
                self._publish_event("godot_proc", "system_crash", payload),
                self._loop,
            )

    def _print_usage(self):
        mode = "GUI 模式" if self.config.visual_mode else "Headless 模式"
        print("\n" + "=" * 60)
        print(f"Godot AI 客户端已启动 - {mode}")
        print("=" * 60)
        print(f"HTTP 控制端口: {self.config.http_port}")
        print(f"Godot WebSocket 端口: {self.config.godot_ws_port}")
        print(f"Session ID: {self._session_id}")
        print(f"事件日志文件: {self._event_log_file}")
        print("\n发送动作示例:")
        print(f'  curl -X POST http://127.0.0.1:{self.config.http_port}/action \\\n       -H "Content-Type: application/json" \\\n       -d \'{{"request_id":"demo-1","actions":[{{"type":"start_wave"}}]}}\'')
        print("\n读取观测示例:")
        print(f"  curl 'http://127.0.0.1:{self.config.http_port}/observations?after_seq=0&limit=200&wait_ms=200'")
        print("\n按 Ctrl+C 停止")
        print("=" * 60 + "\n")

    async def cleanup(self):
        logger.info("正在清理...")

        if self._scheduler_task:
            self._scheduler_task.cancel()
            try:
                await self._scheduler_task
            except asyncio.CancelledError:
                pass

        if self._ws_task:
            self._ws_task.cancel()
            try:
                await self._ws_task
            except asyncio.CancelledError:
                pass

        if self.http_server:
            await self.http_server.stop()

        if self.websocket:
            await self.websocket.close()

        if self.godot:
            self.godot.kill()

        logger.info("已清理")


def parse_args() -> ClientConfig:
    parser = argparse.ArgumentParser(description="Godot AI 客户端 - 非阻塞 HTTP REST 网关")
    parser.add_argument("--visual", "--gui", action="store_true", help="启用 GUI 模式")
    parser.add_argument("--project", "-p", default="/home/zhangzhan/tower", help="Godot 项目路径")
    parser.add_argument("--scene", "-s", default="res://src/Scenes/UI/CoreSelection.tscn", help="启动场景路径")
    parser.add_argument("--http-port", type=int, default=0, help="HTTP 服务器端口 (0=自动分配)")
    parser.add_argument("--godot-port", type=int, default=0, help="Godot WebSocket 端口 (0=自动分配)")
    args = parser.parse_args()

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
        http_port=http_port,
    )


def main():
    config = parse_args()
    client = AIGameClient(config)

    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, lambda: client._shutdown_event.set())

    try:
        success = loop.run_until_complete(client.run())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("用户中断")
        sys.exit(0)


if __name__ == "__main__":
    main()
