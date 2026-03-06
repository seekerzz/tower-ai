import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ai_client.ai_game_client import AIGameClient, ClientConfig

async def run_test():
    config = ClientConfig(
        project_path=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        scene_path="",
        visual_mode=False,
        godot_ws_port=45678,
        http_port=8080
    )

    client = AIGameClient(config)
    await client._start_godot()
    await asyncio.sleep(2)
    connected = await client._connect_websocket()
    if not connected:
        print("❌ FAIL: Could not connect to WS.")
        sys.exit(1)

    client.ws_task = asyncio.create_task(client._ws_receive_loop())

    if client.websocket:
        await client.websocket.send('{"type": "observe"}')
        await asyncio.sleep(2)
        await client.websocket.send('{"actions": [{"action": "select_totem", "totem_type": "cow_totem"}]}')
        await asyncio.sleep(1)
        await client.websocket.send('{"actions": [{"action": "start_wave"}]}')

    await asyncio.sleep(5)

    logs = []
    while not client._obs_queue.empty():
        logs.append(client._obs_queue.get_nowait())
    await client.cleanup()

    has_mechanic_logs = False

    for log in logs:
        if not isinstance(log, str):
            print(f"❌ FAIL: Expected only plain string logs but got: {type(log)} - {log}")
            sys.exit(1)

        if "【" in log and "】" in log:
            if any(keyword in log for keyword in ["流血施加", "血池DOT", "吸血效果"]):
                has_mechanic_logs = True
                print(f"❌ FAIL: Found old mechanic log: {log}")
            if "动态治疗" in log or "回复核心" in log or "受到" in log:
                 print(f"❌ FAIL: Found spammy log: {log}")
                 sys.exit(1)

    if has_mechanic_logs:
         sys.exit(1)

    if not logs:
         print("❌ FAIL: Did not receive any logs.")
         sys.exit(1)

    print(f"✅ PASS: Initial check ok. Collected {len(logs)} logs.")
    sys.exit(0)

if __name__ == "__main__":
    asyncio.run(run_test())
