#!/usr/bin/env python3
"""
检查 Jules 任务状态 - 验证成功的版本

使用方法:
    python check_jules_status.py --session-id SESSION_ID
    python check_jules_status.py --task-id feat-auth-login
"""

import os
import sys
import json
import time
import requests
from pathlib import Path

API_KEY = os.getenv('JULES_API_KEY')
PROXY = os.getenv('HTTP_PROXY', 'http://127.0.0.1:10808')
BASE_URL = "https://jules.googleapis.com/v1alpha"


def get_session_status(session_id: str):
    """获取会话状态"""

    headers = {"X-Goog-Api-Key": API_KEY}
    proxies = {"http": PROXY, "https": PROXY} if PROXY else None

    try:
        resp = requests.get(
            f"{BASE_URL}/sessions/{session_id}",
            headers=headers,
            proxies=proxies,
            timeout=30
        )
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"错误: {e}")
        return None


def monitor_session(session_id: str, timeout: int = 3600, poll_interval: int = 30):
    """监控会话直到完成"""

    print(f"=" * 60)
    print(f"监控任务: {session_id}")
    print(f"URL: https://jules.google.com/session/{session_id}")
    print(f"=" * 60)

    start = time.time()
    check_count = 0

    while time.time() - start < timeout:
        check_count += 1
        result = get_session_status(session_id)

        if not result:
            print(f"[{check_count}] 获取状态失败")
            time.sleep(poll_interval)
            continue

        state = result.get('state', 'UNKNOWN')
        print(f"[{check_count}] 状态: {state}")

        if state in ['COMPLETED', 'FAILED', 'CANCELLED']:
            print()
            print("=" * 60)
            print(f"任务结束 - 状态: {state}")
            print("=" * 60)

            # 显示 PR 信息
            outputs = result.get('outputs', [])
            for output in outputs:
                if 'pullRequest' in output:
                    pr = output['pullRequest']
                    print(f"\nPR: {pr.get('url')}")
                    print(f"分支: {pr.get('headRef')}")

            return result

        time.sleep(poll_interval)

    print(f"\n超时 ({timeout}秒)")
    return None


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--session-id', '-s', help='Jules Session ID')
    parser.add_argument('--task-id', '-t', help='任务ID (从进度文件查找)')
    parser.add_argument('--wait', '-w', action='store_true', help='持续监控')
    parser.add_argument('--timeout', type=int, default=3600)
    args = parser.parse_args()

    if not API_KEY:
        print("错误: JULES_API_KEY 未设置")
        sys.exit(1)

    session_id = args.session_id

    # 如果没有 session_id，尝试从进度文件查找
    if not session_id and args.task_id:
        progress_file = Path(__file__).parent / "progress.md"
        if progress_file.exists():
            content = progress_file.read_text()
            for line in content.split('\n'):
                if args.task_id in line and 'Session:' in line:
                    import re
                    match = re.search(r'Session:\s*(\d+)', line)
                    if match:
                        session_id = match.group(1)
                        print(f"从进度文件找到 Session ID: {session_id}")
                        break

    if not session_id:
        print("错误: 请提供 --session-id 或 --task-id")
        sys.exit(1)

    if args.wait:
        monitor_session(session_id, args.timeout)
    else:
        result = get_session_status(session_id)
        if result:
            try:
                print(json.dumps(result, indent=2, ensure_ascii=False))
            except UnicodeEncodeError:
                print(json.dumps(result, indent=2, ensure_ascii=True))
