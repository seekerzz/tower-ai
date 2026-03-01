#!/usr/bin/env python3
"""
提交 Jules 任务 - 使用 requests 库
验证成功的版本

使用方法:
    python submit_jules_task.py --task-id feat-auth-login --prompt "你的 prompt 内容"

Task ID 命名规范:
    feat-xxxx    - 新功能 (feature)
    bug-xxxx     - Bug 修复
    refactor-xxx - 重构
    docs-xxxx    - 文档
    test-xxxx    - 测试

环境变量:
    JULES_API_KEY - 从 https://jules.google.com/settings#api 获取
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from datetime import datetime

API_KEY = os.getenv('JULES_API_KEY')
PROXY = os.getenv('HTTP_PROXY', 'http://127.0.0.1:10808')
API_URL = "https://jules.googleapis.com/v1alpha/sessions"


def get_default_repo():
    """自动检测当前 git 仓库的远程 GitHub 地址"""
    try:
        import subprocess
        result = subprocess.run(
            ['git', 'remote', 'get-url', 'origin'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            remote_url = result.stdout.strip()
            # 解析 GitHub URL，支持 HTTPS 和 SSH 格式
            # HTTPS: https://github.com/owner/repo.git
            # SSH: git@github.com:owner/repo.git
            if 'github.com' in remote_url:
                # 移除协议前缀和 .git 后缀
                remote_url = remote_url.rstrip('.git')
                if remote_url.startswith('https://'):
                    parts = remote_url.replace('https://github.com/', '').split('/')
                elif remote_url.startswith('git@github.com:'):
                    parts = remote_url.replace('git@github.com:', '').split('/')
                else:
                    return None
                if len(parts) >= 2:
                    return f"{parts[0]}/{parts[1]}"
    except Exception:
        pass
    return None


def submit_task(task_id: str, prompt_content: str, title: str = None, repo: str = None):
    """Submit task to Jules"""

    if not API_KEY:
        print("Error: JULES_API_KEY not set")
        print("Set in docs/secrets/.env or export as environment variable")
        sys.exit(1)

    # 确定仓库地址
    if repo is None:
        repo = get_default_repo()
    if repo is None:
        print("Error: 无法自动检测 GitHub 仓库地址")
        print("请使用 --repo 参数指定，格式: owner/repo")
        sys.exit(1)

    # Add task identifier
    prompt_content += f"\n\n## Task ID\n\nTask being executed: {task_id}\n"

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": API_KEY
    }

    body = {
        "title": title or task_id,
        "prompt": prompt_content,
        "sourceContext": {
            "source": f"sources/github/{repo}",
            "githubRepoContext": {"startingBranch": "master"}
        },
        "automationMode": "AUTO_CREATE_PR"
    }

    proxies = {"http": PROXY, "https": PROXY} if PROXY else None

    print("=" * 60)
    print(f"Submitting task: {task_id}")
    print("=" * 60)

    try:
        print(f"[DEBUG] API_URL: {API_URL}")
        print(f"[DEBUG] Headers: {headers}")
        print(f"[DEBUG] Body keys: {body.keys()}")
        print(f"[DEBUG] Body title: {body.get('title')}")
        print(f"[DEBUG] Body prompt length: {len(body.get('prompt', ''))}")
        resp = requests.post(
            API_URL,
            json=body,
            headers=headers,
            proxies=proxies,
            timeout=30
        )
        resp.raise_for_status()
        result = resp.json()

        session_id = result.get('id')
        print(f"[OK] Success! Session ID: {session_id}")
        print(f"[OK] URL: https://jules.google.com/session/{session_id}")

        # Update progress
        update_progress(task_id, "submitted", f"Task submitted, Session: {session_id}")

        return session_id

    except Exception as e:
        print(f"[ERROR] {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"[ERROR] Response status: {e.response.status_code}")
            print(f"[ERROR] Response body: {e.response.text}")
        sys.exit(1)


def update_progress(task_id: str, status: str, desc: str):
    """Update progress file"""
    progress_file = Path(__file__).parent / "progress.md"
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    content = ""
    if progress_file.exists():
        content = progress_file.read_text(encoding='utf-8')

    # Simple task line replacement
    lines = content.split('\n')
    new_lines = []
    found = False

    for line in lines:
        if f"| {task_id} " in line and line.startswith('|'):
            new_lines.append(f"| {task_id} | {status} | {desc} | {now} |")
            found = True
        else:
            new_lines.append(line)

    if not found:
        # Add to end of table
        for i, line in enumerate(new_lines):
            if line.startswith('| feat-') or line.startswith('| bug-') or line.startswith('| refact-') or line.startswith('| docs-') or line.startswith('| test-'):
                new_lines.insert(i, f"| {task_id} | {status} | {desc} | {now} |")
                break

    progress_file.write_text('\n'.join(new_lines), encoding='utf-8')
    print(f"[OK] Progress updated: jules/progress.md")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(
        description='提交 Jules 任务 - 自动检测当前 GitHub 仓库或手动指定',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  # 自动检测当前 git 仓库的远程地址
  python submit_jules_task.py -t feat-auth-login -p "实现登录功能"

  # 手动指定仓库地址
  python submit_jules_task.py -t feat-auth-login -p "实现登录功能" --repo owner/repo

环境变量:
  JULES_API_KEY - 从 https://jules.google.com/settings#api 获取
        '''
    )
    parser.add_argument('--task-id', '-t', required=True, help='任务唯一标识，如 feat-auth-login')
    parser.add_argument('--prompt', '-p', required=True, help='Prompt 内容（直接文本）')
    parser.add_argument('--title', default=None, help='任务标题，默认为 task-id')
    parser.add_argument('--repo', '-r', default=None,
                        help='GitHub 仓库地址，格式: owner/repo。如不指定，自动检测当前 git 仓库的远程地址')
    args = parser.parse_args()

    submit_task(args.task_id, args.prompt, args.title, args.repo)

