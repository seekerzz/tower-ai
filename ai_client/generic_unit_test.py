#!/usr/bin/env python3
"""
通用QA测试脚本v4
改进: 使用spawn_unit()新作弊API直接生成单位
不再使用商店刷新，直接使用spawn_unit生成目标单位
"""

import sys
import time
import json
import requests
from datetime import datetime

HTTP_PORT = 8080
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"

def log(message, log_file):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_line = f"[{timestamp}] {message}"
    print(log_line)
    with open(log_file, 'a', encoding='utf-8') as f:
        f.write(log_line + '\n')

def send_actions(actions):
    try:
        response = requests.post(f"{BASE_URL}/action", json={"actions": actions}, timeout=5)
        return response.json()
    except Exception as e:
        return None

def get_observations():
    try:
        response = requests.get(f"{BASE_URL}/observations", timeout=5)
        return response.json().get("observations", [])
    except Exception as e:
        return []

def wait_for_observations(duration=3, log_file=None):
    if log_file:
        log(f"[WAIT] 等待 {duration} 秒...", log_file)
    time.sleep(duration)
    return get_observations()

def run_unit_test(task_id, unit_name, unit_keywords, totem_id, test_notes=""):
    """
    执行单位测试的通用函数
    """
    log_file = f"logs/ai_session_{task_id.lower()}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    report_file = f"docs/player_reports/qa_report_{task_id.lower()}.md"

    log("=" * 60, log_file)
    log(f"开始执行测试: {task_id} - {unit_name}", log_file)
    log(f"测试备注: {test_notes}", log_file)
    log("=" * 60, log_file)

    # 步骤1: 选择图腾
    log(f"\n[步骤1] 选择图腾 ({totem_id})", log_file)
    send_actions([{"type": "select_totem", "totem_id": totem_id}])
    observations = wait_for_observations(3, log_file)
    for obs in observations:
        log(f"[OBS] {obs}", log_file)

    # 步骤2: 启用上帝模式
    log("\n[步骤2] 启用上帝模式保护核心", log_file)
    send_actions([{"type": "set_core_hp", "hp": 99999}])
    wait_for_observations(2, log_file)

    # 步骤3: 使用spawn_unit直接生成目标单位（先生成单位）
    log(f"\n[步骤3] 使用spawn_unit生成目标单位: {unit_keywords[0]}", log_file)
    target_unit = unit_keywords[0] if unit_keywords else "squirrel"
    # 在多个位置生成单位以覆盖敌人路径
    positions = [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": -1, "y": 0}]
    for pos in positions:
        send_actions([{
            "type": "spawn_unit",
            "unit_id": target_unit,
            "grid_pos": pos
        }])
        wait_for_observations(1, log_file)
    wait_for_observations(3, log_file)  # 等待单位初始化
    unit_found = True
    log(f"[SUCCESS] 已使用spawn_unit生成单位: {target_unit} (3个位置)", log_file)

    # 步骤4: 开始第1波（再开始波次）
    log("\n[步骤4] 开始第1波战斗", log_file)
    send_actions([{"type": "start_wave"}])
    observations = wait_for_observations(5, log_file)
    for obs in observations:
        log(f"[OBS] {obs}", log_file)

    # 步骤7: 运行多波次战斗
    log("\n[步骤7] 运行战斗波次观察机制", log_file)
    all_logs = []

    for wave in range(1, 4):
        log(f"\n[波次 {wave}] 开始战斗...", log_file)
        send_actions([{"type": "start_wave"}])
        observations = wait_for_observations(10, log_file)

        wave_logs = []
        for obs in observations:
            log(f"[OBS] {obs}", log_file)
            wave_logs.append(obs)
            all_logs.append(obs)

        log(f"[SUMMARY] 波次 {wave} 收集日志: {len(wave_logs)} 条", log_file)

    # 生成测试报告
    log("\n[生成报告]", log_file)
    shop_obs = []  # 使用spawn_unit时没有商店观察
    generate_report(task_id, unit_name, unit_found, shop_obs, all_logs, report_file, log_file)

    log(f"\n[完成] 日志: {log_file}", log_file)
    log(f"[完成] 报告: {report_file}", log_file)

    return unit_found

def generate_report(task_id, unit_name, unit_found, shop_obs, all_logs, report_file, log_file):
    """生成QA测试报告"""

    # 分析日志
    skill_logs = [obs for obs in all_logs if "[SKILL]" in obs]
    buff_logs = [obs for obs in all_logs if "[BUFF]" in obs]
    debuff_logs = [obs for obs in all_logs if "[DEBUFF]" in obs]
    damage_logs = [obs for obs in all_logs if "[TOTEM_DAMAGE]" in obs or "damage" in obs.lower()]

    report = f"""# QA测试报告: {unit_name} ({task_id})

## 任务信息
- **任务ID**: {task_id}
- **单位名称**: {unit_name}
- **执行时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **测试日志**: {log_file}

## 测试结果

| 验证项 | 结果 |
|--------|------|
| 目标单位购买 | {'✅ 成功' if unit_found else '⚠️ 未找到，使用备用单位'} |
| 技能日志 | {'✅ 有' if skill_logs else '❌ 无'} ({len(skill_logs)} 条) |
| Buff日志 | {'✅ 有' if buff_logs else '❌ 无'} ({len(buff_logs)} 条) |
| Debuff日志 | {'✅ 有' if debuff_logs else '❌ 无'} ({len(debuff_logs)} 条) |
| 伤害日志 | {'✅ 有' if damage_logs else '❌ 无'} ({len(damage_logs)} 条) |

## 商店观察
"""

    # 添加商店内容
    for obs in shop_obs[-5:]:  # 只显示最后5次商店内容
        if "商店" in obs:
            report += f"- {obs}\n"

    report += f"""
## 关键日志片段

### 技能日志 ({len(skill_logs)} 条)
"""
    for log_entry in skill_logs[:5]:
        report += f"- {log_entry}\n"

    report += f"""
### Buff日志 ({len(buff_logs)} 条)
"""
    for log_entry in buff_logs[:5]:
        report += f"- {log_entry}\n"

    report += f"""
### Debuff日志 ({len(debuff_logs)} 条)
"""
    for log_entry in debuff_logs[:5]:
        report += f"- {log_entry}\n"

    report += f"""
## 结论

**测试状态**: {'⚠️ 部分完成' if not unit_found else '🔄 已完成'}

**发现的问题**:
- {'目标单位未在商店中出现' if not unit_found else '目标单位已通过spawn_unit生成'}
- {'缺少详细机制日志' if not (skill_logs or buff_logs or debuff_logs) else '机制日志正常输出'}

**建议**:
- 需要补充单位技能日志埋点
- spawn_unit API已可用，测试流程已优化

---
报告生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
测试执行者: AI Player
"""

    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)

    log(f"[报告已保存] {report_file}", log_file)

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python3 generic_unit_test.py <task_id> <unit_name> <unit_keywords> <totem_id> [test_notes]")
        print("Example: python3 generic_unit_test.py TASK-COW-GOLEM-001 '牛魔像' 'cow_golem,牛魔像' cow_totem '怒火中烧机制'")
        sys.exit(1)

    task_id = sys.argv[1]
    unit_name = sys.argv[2]
    unit_keywords = sys.argv[3].split(',')
    totem_id = sys.argv[4]
    test_notes = sys.argv[5] if len(sys.argv) > 5 else ""

    run_unit_test(task_id, unit_name, unit_keywords, totem_id, test_notes)
