import unittest
import asyncio
import json
import os
import shutil
import tempfile
import sys
from unittest.mock import patch, MagicMock, AsyncMock

# 确保可以导入 ai_client
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ai_client.ai_game_client import parse_args, ClientConfig, AIGameClient
from ai_client.utils import find_two_free_ports

class TestWSProxyConfig(unittest.TestCase):
    def test_dynamic_port_allocation(self):
        """测试使用 0 时动态分配端口"""
        test_args = ["ai_game_client.py", "--agent-ws-port", "0", "--godot-port", "0"]

        with patch("sys.argv", test_args):
            config = parse_args()

            # 断言都分配了有效的端口
            self.assertTrue(config.agent_ws_port > 0)
            self.assertTrue(config.godot_ws_port > 0)

            # 断言分配的端口不冲突
            self.assertNotEqual(config.agent_ws_port, config.godot_ws_port)

    def test_fixed_port_allocation(self):
        """测试指定端口"""
        test_args = ["ai_game_client.py", "--agent-ws-port", "12345", "--godot-port", "54321"]

        with patch("sys.argv", test_args):
            config = parse_args()

            self.assertEqual(config.agent_ws_port, 12345)
            self.assertEqual(config.godot_ws_port, 54321)


class TestWSProxyLogPersistence(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp_dir = tempfile.mkdtemp()

    async def asyncTearDown(self):
        shutil.rmtree(self.temp_dir)

    async def test_log_persistence(self):
        """测试日志持久化是否能正确提取 narrative 并落盘"""
        # 准备配置
        config = ClientConfig(
            project_path="dummy",
            scene_path="dummy",
            visual_mode=False,
            godot_ws_port=10000,
            agent_ws_port=10001,
            log_dir=self.temp_dir
        )

        client = AIGameClient(config)
        client._init_logging()

        # 模拟 Godot 发送的消息
        test_message_1 = json.dumps({"event": "AI_Wakeup", "narrative": "[Shop] Available units: wolf, bat"})
        test_message_2 = json.dumps({"event": "Ping"})
        test_message_3 = json.dumps({"event": "Combat", "narrative": "[Combat] wolf dealt 25 damage"})

        # 直接调用日志处理方法
        await client._process_and_log_message(test_message_1)
        await client._process_and_log_message(test_message_2)
        await client._process_and_log_message(test_message_3)

        # 验证文件是否存在
        log_files = os.listdir(self.temp_dir)
        self.assertTrue(len(log_files) > 0, "没有生成日志文件")

        log_file_path = os.path.join(self.temp_dir, log_files[0])
        with open(log_file_path, "r", encoding="utf-8") as f:
            content = f.read()

            # 验证内容
            self.assertIn("[NARRATIVE] [Shop] Available units: wolf, bat", content)
            self.assertIn("[NARRATIVE] [Combat] wolf dealt 25 damage", content)
            self.assertIn("[RAW JSON]", content)
            self.assertIn("Ping", content)

class TestWSProxyPassthrough(unittest.IsolatedAsyncioTestCase):
    async def test_bidirectional_passthrough(self):
        """测试双向 WebSocket 透传 (Godot <-> Proxy <-> Agent)"""

        # 创建客户端
        config = ClientConfig(
            project_path="dummy",
            scene_path="dummy",
            visual_mode=False,
            godot_ws_port=10000,
            agent_ws_port=10001
        )
        client = AIGameClient(config)
        client.godot_websocket = AsyncMock()
        client._ws_connected = True

        # Mock Agent WebSocket 连接
        agent_ws = AsyncMock()
        client.agent_websockets.add(agent_ws)

        # 模拟 AI -> Godot
        test_action = json.dumps({"actions": [{"type": "start_wave"}]})
        await client._forward_to_godot(test_action)
        client.godot_websocket.send.assert_called_once_with(test_action)

        # 模拟 Godot -> AI
        test_state = json.dumps({"event": "WaveStarted"})
        await client._process_and_log_message(test_state)
        agent_ws.send.assert_called_once_with(test_state)

if __name__ == "__main__":
    unittest.main()
