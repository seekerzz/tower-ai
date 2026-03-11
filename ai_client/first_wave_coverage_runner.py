#!/usr/bin/env python3
"""第一波图腾 × 单位组合覆盖测试 Runner（基于 HTTP 异步网关）。"""

import argparse
import json
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List


def http_json(method: str, url: str, data: Dict[str, Any] | None = None) -> Dict[str, Any]:
    raw = None if data is None else json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=raw, method=method)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


@dataclass
class CaseResult:
    totem_id: str
    combo_id: str
    success: bool
    crashes: int
    runtime_errors: int
    missing_key_events: List[str]


def poll_events(base_url: str, after_seq: int, wait_ms: int = 200) -> Dict[str, Any]:
    url = f"{base_url}/observations?after_seq={after_seq}&limit=500&wait_ms={wait_ms}"
    return http_json("GET", url)


def run_case(base_url: str, totem: str, combo: List[str], timeout_s: int = 60) -> CaseResult:
    request_id = f"case-{totem}-{'-'.join(combo)}-{int(time.time())}"
    actions = [{"type": "select_totem", "totem_id": totem}]
    for unit_key in combo:
        actions.extend([
            {"type": "cheat_set_shop_unit", "shop_index": 0, "unit_key": unit_key},
            {"type": "buy_unit", "shop_index": 0},
        ])
    actions.append({"type": "start_wave"})

    ack = http_json("POST", f"{base_url}/action", {"request_id": request_id, "actions": actions})
    if ack.get("status") != "accepted":
        return CaseResult(totem, "+".join(combo), False, 0, 1, ["action_not_accepted"])

    required = {"game_TotemSelected", "game_WaveStarted", "game_WaveEnded"}
    seen = set()
    crashes = 0
    runtime_errors = 0

    after_seq = 0
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        resp = poll_events(base_url, after_seq)
        events = resp.get("events", [])
        after_seq = resp.get("next_seq", after_seq)
        for evt in events:
            event_type = evt.get("event_type", "")
            if event_type in required:
                seen.add(event_type)
            if event_type == "system_crash":
                crashes += 1
            if event_type in {"godot_runtime_error", "action_forward_failed", "action_rejected_expired"}:
                runtime_errors += 1
            if event_type == "game_WaveEnded":
                missing = sorted(required - seen)
                return CaseResult(totem, "+".join(combo), len(missing) == 0 and crashes == 0, crashes, runtime_errors, missing)

    missing = sorted(required - seen)
    return CaseResult(totem, "+".join(combo), False, crashes, runtime_errors, missing + ["timeout"])


def main():
    parser = argparse.ArgumentParser(description="第一波覆盖测试")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--totems", default="wolf_totem,cow_totem,bat_totem,viper_totem,butterfly_totem,eagle_totem")
    parser.add_argument("--combos", default="wolf|tiger,cow|rabbit,bat|eagle,viper|snake")
    parser.add_argument("--output", default="logs/coverage_report.json")
    args = parser.parse_args()

    totems = [x.strip() for x in args.totems.split(",") if x.strip()]
    combos = [[u.strip() for u in c.split("|") if u.strip()] for c in args.combos.split(",") if c.strip()]

    results: List[CaseResult] = []
    for totem in totems:
        for combo in combos:
            print(f"Running case: totem={totem} combo={combo}")
            results.append(run_case(args.base_url, totem, combo))

    report = {
        "total": len(results),
        "passed": sum(1 for r in results if r.success),
        "failed": sum(1 for r in results if not r.success),
        "cases": [r.__dict__ for r in results],
    }

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved report: {out}")


if __name__ == "__main__":
    main()
