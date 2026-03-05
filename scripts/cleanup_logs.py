#!/usr/bin/env python3
"""
日志文件清理脚本 - 只保留最近的日志文件

保留策略：
- 保留最近20个日志文件
- 删除其余所有日志文件
"""

import os
import sys
from datetime import datetime

LOG_DIR = "/home/zhangzhan/tower-ai/logs"
MAX_LOGS_TO_KEEP = 20


def main():
    if not os.path.exists(LOG_DIR):
        print(f"日志目录不存在: {LOG_DIR}")
        return

    # 获取所有日志文件
    log_files = []
    for filename in os.listdir(LOG_DIR):
        file_path = os.path.join(LOG_DIR, filename)
        if os.path.isfile(file_path) and filename.endswith(".log"):
            log_files.append(file_path)

    # 按修改时间排序（最新的在前面）
    log_files.sort(key=lambda f: os.path.getmtime(f), reverse=True)

    # 计算需要删除的日志文件
    if len(log_files) > MAX_LOGS_TO_KEEP:
        files_to_delete = log_files[MAX_LOGS_TO_KEEP:]
        print(f"发现 {len(log_files)} 个日志文件，保留 {MAX_LOGS_TO_KEEP} 个，删除 {len(files_to_delete)} 个")

        for file_path in files_to_delete:
            try:
                os.remove(file_path)
                print(f"删除日志文件: {os.path.basename(file_path)}")
            except Exception as e:
                print(f"删除日志文件失败 {os.path.basename(file_path)}: {e}")
    else:
        print(f"日志文件数量未超过限制: {len(log_files)}/{MAX_LOGS_TO_KEEP}")

    print("日志清理完成")


if __name__ == "__main__":
    main()
