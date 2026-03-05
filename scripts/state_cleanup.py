#!/usr/bin/env python3
"""
状态文件清理脚本

功能：
1. 仅保留状态文件中最近10条未完成任务
2. 将已完成的任务条目移动到归档文件中

用法：
    python3 scripts/state_cleanup.py <role_name>

<role_name> 可选值：
    - project_director
    - game_designer
    - tech_director
    - ai_player

示例：
    python3 scripts/state_cleanup.py project_director
"""

import sys
import os
from datetime import datetime


def get_state_paths(role_name):
    """获取状态文件和归档文件路径"""
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    states_dir = os.path.join(base_dir, "docs", "states")

    state_files = {
        "project_director": ("project_director_state.md", "project_director_state_archive.md"),
        "game_designer": ("game_designer_state.md", "game_designer_state_archive.md"),
        "tech_director": ("tech_director_state.md", "tech_director_state_archive.md"),
        "ai_player": ("ai_player_state.md", "ai_player_state_archive.md"),
    }

    if role_name not in state_files:
        raise ValueError(f"未知角色: {role_name}. 可选值: {list(state_files.keys())}")

    state_file, archive_file = state_files[role_name]
    return (
        os.path.join(states_dir, state_file),
        os.path.join(states_dir, archive_file)
    )


def parse_inbox_entries(content):
    """解析状态文件中的Inbox条目"""
    # 找到Inbox区域
    inbox_start = content.find("## [Inbox")
    if inbox_start == -1:
        return [], content, ""

    # 找到下一个##标题或文件结尾
    next_section = content.find("## [", inbox_start + 1)
    if next_section == -1:
        inbox_content = content[inbox_start:]
        after_inbox = ""
    else:
        inbox_content = content[inbox_start:next_section]
        after_inbox = content[next_section:]

    before_inbox = content[:inbox_start]

    # 解析条目 - 以"### "开头的是条目
    entries = []
    lines = inbox_content.split("\n")
    current_entry = []
    current_title = ""

    for line in lines:
        if line.startswith("### "):
            if current_entry:
                entries.append({
                    "title": current_title,
                    "content": "\n".join(current_entry)
                })
            current_title = line[4:]  # 去掉"### "
            current_entry = [line]
        elif current_entry:
            current_entry.append(line)

    if current_entry:
        entries.append({
            "title": current_title,
            "content": "\n".join(current_entry)
        })

    return entries, before_inbox, after_inbox


def is_completed(entry):
    """判断条目是否已完成"""
    content = entry["content"].lower()
    completed_markers = [
        "状态**: ✅",
        "状态**: ✓",
        "状态**: 完成",
        "状态**: 已解决",
        "状态**: 已通过",
        "状态**: 已修复",
        "状态**: 已归档",
        "状态**: 已合并"
    ]
    return any(marker.lower() in content for marker in completed_markers)


def cleanup_state(role_name):
    """清理指定角色的状态文件"""
    state_path, archive_path = get_state_paths(role_name)

    if not os.path.exists(state_path):
        print(f"错误: 状态文件不存在: {state_path}")
        return False

    # 读取状态文件
    with open(state_path, "r", encoding="utf-8") as f:
        state_content = f.read()

    # 解析条目
    entries, before_inbox, after_inbox = parse_inbox_entries(state_content)

    if not entries:
        print(f"未找到Inbox条目: {role_name}")
        return True

    # 分离已完成和未完成的条目
    completed = [e for e in entries if is_completed(e)]
    pending = [e for e in entries if not is_completed(e)]

    print(f"总计条目: {len(entries)}")
    print(f"已完成: {len(completed)}")
    print(f"未完成: {len(pending)}")

    # 保留最近10条未完成的条目
    pending_to_keep = pending[-10:] if len(pending) > 10 else pending
    pending_to_archive = pending[:-10] if len(pending) > 10 else []

    if pending_to_archive:
        print(f"未完成任务超过10条，将归档 {len(pending_to_archive)} 条最旧的未完成任务")

    # 构建归档内容
    archive_entries = completed + pending_to_archive

    if archive_entries:
        # 读取或创建归档文件
        if os.path.exists(archive_path):
            with open(archive_path, "r", encoding="utf-8") as f:
                archive_content = f.read()
        else:
            archive_content = f"# {role_name.replace('_', ' ').title()} State Archive\n\n## [Archive - Historical Records]\n\n"

        # 在归档区域后添加新条目
        archive_section = "## [Archive"
        archive_pos = archive_content.find(archive_section)
        if archive_pos != -1:
            # 找到归档区域后的第一个空行
            section_end = archive_content.find("\n\n", archive_pos)
            if section_end == -1:
                section_end = len(archive_content)
            else:
                section_end += 2

            # 添加时间戳分隔
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            new_entries = f"\n---\n\n### 📦 Archival Batch: {timestamp}\n\n"
            for entry in reversed(archive_entries):  # 按时间顺序排列
                new_entries += entry["content"] + "\n\n"

            archive_content = archive_content[:section_end] + new_entries + archive_content[section_end:]

        # 写入归档文件
        with open(archive_path, "w", encoding="utf-8") as f:
            f.write(archive_content)

        print(f"已归档 {len(archive_entries)} 条到: {archive_path}")

    # 构建新的状态文件内容
    if pending_to_keep:
        new_inbox = "## [Inbox - 待办]\n\n" + "\n\n---\n\n".join(
            e["content"] for e in reversed(pending_to_keep)
        ) + "\n\n"
    else:
        # 保留原有的Inbox标题
        inbox_match = state_content.find("## [Inbox")
        inbox_end = state_content.find("\n", inbox_match)
        inbox_title = state_content[inbox_match:inbox_end] if inbox_match != -1 else "## [Inbox - 待办]"
        new_inbox = inbox_title + "\n\n"

    new_state_content = before_inbox + new_inbox + after_inbox

    # 写入状态文件
    with open(state_path, "w", encoding="utf-8") as f:
        f.write(new_state_content)

    print(f"状态文件已清理，保留 {len(pending_to_keep)} 条未完成任务: {state_path}")
    return True


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    role_name = sys.argv[1].lower()

    # 支持简写
    aliases = {
        "pd": "project_director",
        "gd": "game_designer",
        "td": "tech_director",
        "ai": "ai_player",
    }
    role_name = aliases.get(role_name, role_name)

    try:
        if cleanup_state(role_name):
            print("\n✅ 清理完成!")
            sys.exit(0)
        else:
            print("\n❌ 清理失败!")
            sys.exit(1)
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
