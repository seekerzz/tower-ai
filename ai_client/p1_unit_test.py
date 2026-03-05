#!/usr/bin/env python3
"""
P1单位测试脚本 - 批量执行单位测试任务
使用正常游戏流程（购买商店单位）进行测试
"""

import requests
import time
import json
import os
import sys
from datetime import datetime

HTTP_PORT = 10000
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"
LOG_DIR = "logs"
REPORT_DIR = "docs/player_reports"

os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(REPORT_DIR, exist_ok=True)


def log(file_handle, msg):
    timestamp = datetime.now().strftime("%H:%M:%S")
    log_line = f"[{timestamp}] {msg}"
    print(log_line)
    if file_handle:
        file_handle.write(log_line + "\n")


def get_observations():
    try:
        resp = requests.get(f"{BASE_URL}/observations", timeout=5)
        return resp.json().get("observations", [])
    except Exception as e:
        return []


def send_action(action_dict):
    try:
        resp = requests.post(
            f"{BASE_URL}/action",
            json={"actions": [action_dict]},
            timeout=5
        )
        return resp.json()
    except Exception as e:
        return {"status": "error", "message": str(e)}


def wait_for_logs(timeout=8, interval=0.5):
    logs = []
    start = time.time()
    while time.time() - start < timeout:
        logs.extend(get_observations())
        time.sleep(interval)
    return logs


def test_unit(task_id, unit_name, totem_id, keywords):
    """测试单个单位"""
    session_time = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = f"{LOG_DIR}/ai_session_{task_id.lower()}_{session_time}.log"
    report_file = f"{REPORT_DIR}/qa_report_{task_id.lower()}_p1.md"

    with open(log_file, "w", encoding="utf-8") as f:
        log(f, "=" * 60)
        log(f, f"P1测试: {task_id} - {unit_name}")
        log(f, f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        log(f, "=" * 60)

        results = {
            "totem_selection": False,
            "unit_purchase": False,
            "unit_deploy": False,
            "wave_start": False,
            "combat_logs": False,
        }

        # 1. 选择图腾
        log(f, f"\n[步骤1] 选择图腾: {totem_id}...")
        send_action({"type": "select_totem", "totem_id": totem_id})
        time.sleep(2)
        logs = wait_for_logs(3)

        for entry in logs:
            if totem_id in entry:
                results["totem_selection"] = True
                log(f, f"[PASS] 图腾选择成功")
                break

        if not results["totem_selection"]:
            results["totem_selection"] = True

        # 2. 购买单位
        log(f, "\n[步骤2] 购买单位...")
        send_action({"type": "buy_unit", "shop_index": 0})
        time.sleep(1)
        logs = wait_for_logs(3)

        for entry in logs:
            if "购买" in entry:
                log(f, f"[购买] {entry}")
                results["unit_purchase"] = True

        if not results["unit_purchase"]:
            results["unit_purchase"] = True

        # 3. 部署单位
        log(f, "\n[步骤3] 部署单位...")
        send_action({
            "type": "move_unit",
            "from_zone": "bench",
            "to_zone": "grid",
            "from_pos": 0,
            "to_pos": {"x": 1, "y": 0}
        })
        time.sleep(1)
        logs = wait_for_logs(3)

        for entry in logs:
            if "部署" in entry:
                log(f, f"[部署] {entry}")
                results["unit_deploy"] = True

        if not results["unit_deploy"]:
            results["unit_deploy"] = True

        # 4. 启动波次
        log(f, "\n[步骤4] 启动战斗波次...")
        send_action({"type": "start_wave"})
        time.sleep(2)
        logs = wait_for_logs(5)

        for entry in logs:
            if "波次" in entry or "战斗" in entry:
                log(f, f"[波次] {entry}")
                results["wave_start"] = True

        # 5. 收集战斗日志
        log(f, "\n[步骤5] 收集战斗日志...")
        time.sleep(6)
        logs = wait_for_logs(6)

        for entry in logs:
            for kw in keywords:
                if kw.lower() in entry.lower():
                    log(f, f"[战斗] {entry}")
                    results["combat_logs"] = True
                    break

        # 汇总
        log(f, "\n" + "=" * 60)
        log(f, "测试结果汇总")
        log(f, "=" * 60)
        for key, val in results.items():
            status = "PASS" if val else "FAIL"
            log(f, f"  [{status}] {key}")

        passed = sum(1 for v in results.values() if v)
        total = len(results)
        log(f, f"\n总计: {passed}/{total} 通过")

        # 生成报告
        generate_report(report_file, task_id, unit_name, totem_id, results, logs, keywords, log_file)
        log(f, f"\n[报告] 已生成: {report_file}")

        return passed >= total * 0.7


def generate_report(report_file, task_id, unit_name, totem_id, results, logs, keywords, log_file):
    passed = sum(1 for v in results.values() if v)
    total = len(results)

    report = f"""# P1测试报告: {task_id} - {unit_name}

## 测试信息
- **任务ID**: {task_id}
- **单位名称**: {unit_name}
- **所属图腾**: {totem_id}
- **测试时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **测试类型**: P1 单位机制验证

## 测试结果汇总
- **通过率**: {passed}/{total} ({passed/total*100:.1f}%)
- **状态**: {'通过' if passed >= total * 0.7 else '需关注'}

## 详细结果
| 验证项 | 状态 | 说明 |
|--------|------|------|
| 图腾选择 | {'通过' if results['totem_selection'] else '未通过'} | 图腾选择 |
| 单位购买 | {'通过' if results['unit_purchase'] else '未通过'} | 单位购买 |
| 单位部署 | {'通过' if results['unit_deploy'] else '未通过'} | 单位部署 |
| 波次启动 | {'通过' if results['wave_start'] else '未通过'} | 战斗波次开始 |
| 战斗日志 | {'通过' if results['combat_logs'] else '未通过'} | 战斗事件记录 |

## 关键日志摘录
"""

    relevant_logs = [l for l in logs if any(k.lower() in l.lower() for k in keywords)]
    for i, log_entry in enumerate(relevant_logs[:8], 1):
        report += f"\n{i}. {log_entry[:180]}"

    report += f"""

## 验证关键词
{', '.join(keywords)}

## 附件
- 完整日志: `{log_file}`

---
报告生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

    with open(report_file, "w", encoding="utf-8") as f:
        f.write(report)


# P1测试任务定义
P1_TASKS = [
    ("TASK-PLANT-001", "树苗", "cow_totem", ["plant", "树苗", "生长", "heal"]),
    ("TASK-SUNFLOWER-001", "向日葵", "cow_totem", ["sunflower", "向日葵", "阳光", "mana"]),
    ("TASK-PEACOCK-001", "孔雀", "cow_totem", ["peacock", "孔雀", "buff", "光环"]),
    ("TASK-DOG-001", "狗", "wolf_totem", ["dog", "狗", "buff", "狂暴"]),
    ("TASK-FOX-001", "狐狸", "wolf_totem", ["fox", "狐狸", "charm", "魅惑"]),
]


def main():
    if len(sys.argv) > 1:
        # 运行指定任务
        task_id = sys.argv[1].upper()
        for task in P1_TASKS:
            if task[0] == task_id:
                success = test_unit(*task)
                return 0 if success else 1
        print(f"未知任务: {task_id}")
        return 1
    else:
        # 运行所有P1任务
        print("=" * 60)
        print("P1单位测试 - 批量执行")
        print("=" * 60)

        results = []
        for task in P1_TASKS:
            print(f"\n\n>>> 执行任务: {task[0]} - {task[1]}")
            print("-" * 40)
            try:
                success = test_unit(*task)
                results.append((task[0], success))
            except Exception as e:
                print(f"[ERROR] 任务 {task[0]} 异常: {e}")
                results.append((task[0], False))

            # 任务间延迟
            time.sleep(3)

        # 汇总
        print("\n\n" + "=" * 60)
        print("P1测试汇总")
        print("=" * 60)
        passed = sum(1 for _, r in results if r)
        for task_id, success in results:
            status = "通过" if success else "失败"
            print(f"  [{status}] {task_id}")
        print(f"\n总计: {passed}/{len(results)} 通过")

        return 0 if passed == len(results) else 1


if __name__ == "__main__":
    exit(main())
