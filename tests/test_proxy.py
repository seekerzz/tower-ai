import pytest
import os
import json
import asyncio
from unittest.mock import patch, MagicMock, AsyncMock
import tempfile
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from ai_client.ai_game_client import parse_args, ClientConfig, AIGameClient

def test_dynamic_port_allocation():
    # 测试 --agent-ws-port=0 时的动态端口分配
    with patch('sys.argv', ['ai_game_client.py', '--agent-ws-port=0', '--godot-port=0']):
        config = parse_args()
        assert config.agent_ws_port > 0
        assert config.godot_ws_port > 0
        assert config.agent_ws_port != config.godot_ws_port

@pytest.mark.asyncio
async def test_log_persistence():
    # 测试日志落盘功能
    config = ClientConfig(
        project_path="dummy",
        scene_path="dummy",
        visual_mode=False,
        godot_ws_port=10000,
        agent_ws_port=10001
    )

    client = AIGameClient(config)

    # Mock log file setup
    with tempfile.TemporaryDirectory() as tmpdir:
        client.log_dir = tmpdir
        client._init_logger()

        test_json = {
            "event": "ShopPhase",
            "narrative": "[Shop] Gold: 150, Available: [wolf,bat,eagle]"
        }
        test_msg = json.dumps(test_json)

        # 模拟从 Godot 收到消息
        await client._process_godot_message(test_msg)

        # 验证日志文件是否创建并包含正确内容
        log_files = os.listdir(tmpdir)
        assert len(log_files) > 0

        log_file_path = os.path.join(tmpdir, log_files[0])
        with open(log_file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            assert test_msg in content
            assert "[Shop] Gold: 150, Available: [wolf,bat,eagle]" in content

@pytest.mark.asyncio
async def test_bidirectional_proxy():
    # 测试双向透传
    config = ClientConfig(
        project_path="dummy",
        scene_path="dummy",
        visual_mode=False,
        godot_ws_port=10000,
        agent_ws_port=10001
    )

    client = AIGameClient(config)
    client.godot_ws = AsyncMock()

    # 模拟外部 Agent 连接
    mock_agent_ws = AsyncMock()
    client.connected_agents.add(mock_agent_ws)

    # 设置 _ws_connected 为 True 模拟已连接
    client._ws_connected = True

    # 模拟从 Agent 收到上行消息
    test_action = {"actions": [{"type": "start_wave"}]}
    await client._handle_agent_message(json.dumps(test_action), mock_agent_ws)

    # 验证是否发给了 Godot
    client.godot_ws.send.assert_called_once_with(json.dumps(test_action))

    # 模拟从 Godot 收到下行消息
    client.godot_ws.send.reset_mock()
    test_state = {"event": "WaveStarted"}

    # 禁用真实的日志落盘以防报错
    client._init_logger = MagicMock()
    client.log_file = None

    await client._process_godot_message(json.dumps(test_state))

    # 验证是否发给了所有连接的 Agent
    mock_agent_ws.send.assert_called_once_with(json.dumps(test_state))
