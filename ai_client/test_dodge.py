import argparse
import json
import time
import urllib.request
from typing import Any, Dict, List

def http_json(method: str, url: str, data: Dict[str, Any] | None = None) -> Dict[str, Any]:
    raw = None if data is None else json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=raw, method=method)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))

def poll_events(base_url: str, after_seq: int, wait_ms: int = 500) -> Dict[str, Any]:
    url = f"{base_url}/observations?after_seq={after_seq}&limit=500&wait_ms={wait_ms}"
    return http_json("GET", url)

def test_dodge():
    print("=== Testing Dodge ===")
    base_url = "http://127.0.0.1:8080"
    request_id = f"test-dodge-{int(time.time())}"

    actions = [
        {"type": "select_totem", "totem_id": "wolf_totem"},
        {"type": "cheat_set_shop_unit", "shop_index": 0, "unit_key": "pigeon"},
        {"type": "buy_unit", "shop_index": 0},
        {"type": "cheat_upgrade_unit", "grid_pos": {"x": 0, "y": 0}},
        {"type": "cheat_spawn_enemy", "enemy_type": "slime"}
    ]

    http_json("POST", f"{base_url}/action", {"request_id": request_id, "actions": actions})

    timeout_s = 20
    deadline = time.time() + timeout_s
    after_seq = 0
    found_dodge = False

    while time.time() < deadline:
        resp = poll_events(base_url, after_seq)
        events = resp.get("events", [])
        after_seq = resp.get("next_seq", after_seq)

        for evt in events:
            if evt.get("source") == "godot_proc" and evt.get("event_type") == "godot_stdout":
                line = evt.get("payload", {}).get("line", "")
                if "DODGE!" in line or "Dodge" in line:
                    print("Found output: ", line)
                    found_dodge = True
                    break
        if found_dodge:
            print("SUCCESS: Dodge test passed!")
            return

    print("FAILED: Did not detect Dodge output in logs.")

def main():
    test_dodge()

if __name__ == "__main__":
    main()
