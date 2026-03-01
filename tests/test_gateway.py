import asyncio
import json
import os
import pytest
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock

from ai_client.ai_game_client import AIGameClient, ClientConfig
from ai_client.http_server import AIHTTPServer
from ai_client.utils import find_free_port

@pytest.fixture
def mock_config():
    return ClientConfig(
        project_path="/tmp",
        scene_path="res://test.tscn",
        visual_mode=False,
        godot_ws_port=10001,
        http_port=10000
    )

@pytest.mark.asyncio
async def test_dynamic_port_allocation():
    from ai_client.ai_game_client import parse_args
    with patch("sys.argv", ["ai_game_client.py", "--http-port", "0", "--godot-port", "0"]):
        config = parse_args()
        assert config.http_port > 0
        assert config.godot_ws_port > 0
        assert config.http_port != config.godot_ws_port

@pytest.mark.asyncio
async def test_log_persistence(tmp_path):
    config = ClientConfig(
        project_path="/tmp",
        scene_path="res://test.tscn",
        visual_mode=False,
        godot_ws_port=10001,
        http_port=10000
    )
    client = AIGameClient(config)

    # Mock setup
    log_dir = tmp_path / "logs"
    client._log_dir = log_dir
    client._log_file = log_dir / "ai_session_test.log"
    os.makedirs(log_dir, exist_ok=True)

    test_msg = '{"event": "TestEvent", "narrative": "Something happened"}'

    # Mock self.websocket using __aiter__ mock that returns an async generator
    async def mock_aiter():
        yield test_msg
        await asyncio.sleep(10) # Prevent early exit

    mock_ws = AsyncMock()
    mock_ws.__aiter__.side_effect = lambda: mock_aiter()
    client.websocket = mock_ws

    # Run loop for a short time to process the mocked message
    import websockets.exceptions
    try:
        # Avoid hanging on websockets exceptions by mocking websockets package in this test logic
        await asyncio.wait_for(client._ws_receive_loop(), timeout=0.1)
    except asyncio.TimeoutError:
        pass
    except websockets.exceptions.ConnectionClosed:
        pass

    # Verify log file was created and contains the message
    assert client._log_file.exists(), "Log file was not created"
    content = client._log_file.read_text()
    assert "Something happened" in content
    assert "TestEvent" in content

@pytest.mark.asyncio
async def test_http_uplink_passthrough():
    config = ClientConfig(
        project_path="/tmp",
        scene_path="res://test.tscn",
        visual_mode=False,
        godot_ws_port=10001,
        http_port=10000
    )
    client = AIGameClient(config)
    client.websocket = AsyncMock()
    client._ws_connected = True

    actions = [{"type": "start_wave"}]

    # HTTP server's action handler
    response = await client._handle_action_request(actions)

    # Verify websocket.send was called immediately
    client.websocket.send.assert_called_once()
    call_arg = client.websocket.send.call_args[0][0]
    assert json.loads(call_arg) == {"actions": actions}

    # Verify response is immediate and indicates success
    assert response == {"status": "ok", "message": "Actions sent"}

@pytest.mark.asyncio
async def test_observations_buffer_read_and_clear():
    config = ClientConfig(
        project_path="/tmp",
        scene_path="res://test.tscn",
        visual_mode=False,
        godot_ws_port=10001,
        http_port=10000
    )
    client = AIGameClient(config)

    # Pre-populate queue
    test_msg_1 = "Battle started"
    test_msg_2 = "Hero dealt 50 damage"
    await client._obs_queue.put(test_msg_1)
    await client._obs_queue.put(test_msg_2)

    # Read observations
    obs_res = await client._handle_observations_request()
    assert "observations" in obs_res
    assert len(obs_res["observations"]) == 2
    assert obs_res["observations"] == [test_msg_1, test_msg_2]

    # Queue should be empty now
    obs_res_empty = await client._handle_observations_request()
    assert len(obs_res_empty["observations"]) == 0

@pytest.mark.asyncio
async def test_godot_crash_adds_to_observations():
    config = ClientConfig(
        project_path="/tmp",
        scene_path="res://test.tscn",
        visual_mode=False,
        godot_ws_port=10001,
        http_port=10000
    )
    client = AIGameClient(config)
    client._loop = asyncio.get_running_loop()

    from ai_client.godot_process import CrashInfo
    crash_info = CrashInfo(
        error_type="SCRIPT ERROR: Division by zero",
        stack_trace="At: res://src/test.gd:42",
        timestamp=12345.678
    )

    # Simulate crash callback
    client._on_godot_crash(crash_info)

    # Need to yield to event loop to allow call_soon_threadsafe to process
    await asyncio.sleep(0.01)

    # Read observations
    obs_res = await client._handle_observations_request()
    assert "observations" in obs_res
    assert len(obs_res["observations"]) == 1

    crash_text = obs_res["observations"][0]
    assert "SystemCrash" in crash_text or "系统严重报错" in crash_text
    assert "SCRIPT ERROR: Division by zero" in crash_text
    assert "At: res://src/test.gd:42" in crash_text