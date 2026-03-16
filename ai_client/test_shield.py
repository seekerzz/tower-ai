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

def test_shield():
    print("=== Testing Shield ===")
    base_url = "http://127.0.0.1:8080"
    request_id = f"test-shield-{int(time.time())}"

    actions = [
        {"type": "select_totem", "totem_id": "wolf_totem"},
        {"type": "cheat_set_shop_unit", "shop_index": 0, "unit_key": "rock_armor_cow"},
        {"type": "buy_unit", "shop_index": 0},
        {"type": "cheat_spawn_enemy", "enemy_type": "slime"}
    ]

    http_json("POST", f"{base_url}/action", {"request_id": request_id, "actions": actions})

    timeout_s = 20
    deadline = time.time() + timeout_s
    after_seq = 0
    found_shield = False

    while time.time() < deadline:
        resp = poll_events(base_url, after_seq)
        events = resp.get("events", [])
        after_seq = resp.get("next_seq", after_seq)

        for evt in events:
            if evt.get("source") == "godot_proc" and evt.get("event_type") == "godot_stdout":
                line = evt.get("payload", {}).get("line", "")
                if "shield" in line.lower() or "blocked" in line.lower():
                    print("Found output: ", line)
                    found_shield = True
                    break
            elif evt.get("event_type") == "game_shield_absorbed":
                print("Found shield absorbed event!")
                found_shield = True
                break

        if found_shield:
            print("SUCCESS: Shield test passed!")
            return

    print("FAILED: Did not detect Shield output in logs.")

def main():
    test_shield()

if __name__ == "__main__":
    main()
