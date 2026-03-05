#!/usr/bin/env python3
"""
pre-commit 钩子检查脚本，用于限制各个角色在 docs 目录下的提交权限
"""

import os
import sys
import subprocess


# 角色权限配置
ROLE_PERMISSIONS = {
    "project_director": {
        "allowed_files": [
            "docs/states/project_director_state.md",
            "docs/GameDesign.md",
            "docs/roles/*.md"
        ],
        "allowed_patterns": []
    },
    "game_designer": {
        "allowed_files": [
            "docs/states/game_designer_state.md",
            "docs/design_proposals/proposal_*.md",
            "data/wave_config.json",
            "data/core_types.json",
            "data/barricade_types.json",
            "data/enemy_variants.json",
            "data/traits.json",
            "data/units/*.json"
        ],
        "allowed_patterns": []
    },
    "tech_director": {
        "allowed_files": [
            "docs/states/tech_director_state.md",
            "docs/design_proposals/proposal_*.md",
            "src/**/*.gd",
            "tests/**/*.py",
            "scripts/*.py",
            "hooks/*"
        ],
        "allowed_patterns": []
    },
    "ai_player": {
        "allowed_files": [
            "docs/states/ai_player_state.md",
            "logs/ai_session_*.log",
            "docs/player_reports/*.md",
            "ai_client/*.py",
            "ai_client/docs/player_reports/*.md"
        ],
        "allowed_patterns": []
    },
    "qa_tester": {
        "allowed_files": [
            "docs/states/qa_tester_state.md",
            "docs/GameDesign.md",
            "docs/qa_tasks/task_*.md"
        ],
        "allowed_patterns": []
    }
}


def get_staged_files():
    """
    获取 git 暂存区的文件列表
    """
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split("\n") if result.stdout.strip() else []
    except subprocess.CalledProcessError as e:
        print(f"Error getting staged files: {e}")
        sys.exit(1)


def is_file_allowed(file_path, role):
    """
    检查文件是否符合角色的权限
    """
    if role not in ROLE_PERMISSIONS:
        return False

    permissions = ROLE_PERMISSIONS[role]

    # 检查是否在允许的文件列表中
    for allowed_file in permissions["allowed_files"]:
        import fnmatch
        if fnmatch.fnmatch(file_path, allowed_file):
            return True

    # 检查是否符合允许的模式
    for pattern in permissions["allowed_patterns"]:
        import fnmatch
        if fnmatch.fnmatch(file_path, pattern):
            return True

    return False


def get_current_role():
    """
    获取当前角色（从环境变量或配置文件中读取）
    """
    # 这里可以根据实际情况从环境变量、配置文件或其他方式获取角色
    # 目前先从环境变量中读取
    role = os.environ.get("ROLE")
    if not role:
        # 尝试从 .claude/agents 目录中查找当前运行的 agent
        agent_dir = "/home/zhangzhan/tower-ai/.claude/agents"
        if os.path.exists(agent_dir):
            agents = os.listdir(agent_dir)
            if agents:
                role = agents[0].split(".")[0]

    return role


def main():
    """
    主函数
    """
    # 获取当前角色
    role = get_current_role()
    if not role:
        print("Error: No role specified. Please set the ROLE environment variable (e.g., ROLE=game_designer git commit)")
        sys.exit(1)

    role = role.lower()

    if role not in ROLE_PERMISSIONS:
        print(f"Warning: Unknown role '{role}'. Allowing all files.")
        sys.exit(0)

    # 获取暂存区的文件
    staged_files = get_staged_files()

    # 检查每个文件是否符合角色权限
    invalid_files = []
    for file_path in staged_files:
        if not is_file_allowed(file_path, role):
            invalid_files.append(file_path)

    if invalid_files:
        print(f"Error: Role '{role}' is not allowed to commit the following files:")
        for file_path in invalid_files:
            print(f"  - {file_path}")
        print("\nAllowed files for this role:")
        for allowed_file in ROLE_PERMISSIONS[role]["allowed_files"]:
            print(f"  - {allowed_file}")
        sys.exit(1)

    print(f"Check passed: Role '{role}' is allowed to commit all staged files.")
    sys.exit(0)


if __name__ == "__main__":
    main()
