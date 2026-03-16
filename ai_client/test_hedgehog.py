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

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    args = parser.parse_args()

    base_url = args.base_url

    # We will test the hedgehog by doing normal coverage run with Hedgehog combo
    print("Testing Hedgehog via normal coverage run...")

if __name__ == "__main__":
    main()
