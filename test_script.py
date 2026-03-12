import requests
import time
import json
import subprocess

proc = subprocess.Popen(["python3", "ai_client/ai_game_client.py", "--project", ".", "--scene", "res://src/Scenes/UI/CoreSelection.tscn", "--http-port", "8080"])
time.sleep(10)

base_url = "http://127.0.0.1:8080"

def send_action(actions):
    resp = requests.post(f"{base_url}/action", json={"actions": actions})

send_action([{"type": "select_totem", "totem_id": "wolf_totem"}])
time.sleep(2)

send_action([
    {"type": "buy_unit", "shop_index": 0},
    {"type": "move_unit", "from_zone": "bench", "from_pos": 0, "to_zone": "grid", "to_pos": {"x": -1, "y": 0}}
])
time.sleep(2)

send_action([{"type": "start_wave"}])

time.sleep(20)

resp = requests.get(f"{base_url}/observations?after_seq=0&limit=1000")
data = resp.json()

for ev in data.get("events", []):
    etype = ev.get("event_type")
    if etype and etype.startswith("game_"):
        print(etype)
        payload = ev.get("payload", {})
        if etype in ["game_DamageDealt", "game_EnemyHit", "game_SkillActivated", "game_SkillUsed", "game_BuffApplied", "game_DebuffApplied", "game_ShieldGenerated", "game_ShieldAbsorbed"]:
            print(etype, json.dumps(payload, ensure_ascii=False))

proc.kill()
