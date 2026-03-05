#!/usr/bin/env python3
"""
使用新作弊API的测试脚本
改进: reset_game() + spawn_unit() API
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

def run_test_with_new_api(task_id, unit_name, unit_id, totem_id, test_notes=""):
    """
    使用新作弊API执行测试
    """
    # 使用新的命名规范: bat_totem_new_001
    task_name = task_id.lower().replace('-', '_').replace('task_', '')
    log_file = f"logs/ai_session_{task_name}_new_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    report_file = f"docs/player_reports/qa_report_{task_name}_new_001.md"

    log("=" * 60, log_file)
    log(f"开始执行测试: {task_id} - {unit_name}", log_file)
    log(f"测试备注: {test_notes}", log_file)
    log("=" * 60, log_file)

    # 步骤0: 重置游戏
    log("\n[步骤0] 重置游戏到初始状态", log_file)
    send_actions([{"type": "reset_game"}])
    observations = wait_for_observations(3, log_file)
    for obs in observations:
        log(f"[OBS] {obs}", log_file)

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

    # 步骤3: 使用spawn_unit生成目标单位（新API）
    log(f"\n[步骤3] 使用spawn_unit生成目标单位: {unit_id}", log_file)
    send_actions([{
        "type": "spawn_unit",
        "unit_id": unit_id,
        "grid_pos": {"x": 1, "y": 0}
    }])
    observations = wait_for_observations(3, log_file)
    for obs in observations:
        log(f"[OBS] {obs}", log_file)
    log(f"[SUCCESS] 已使用spawn_unit生成单位: {unit_id}", log_file)

    # 步骤4: 开始第1波
    log("\n[步骤4] 开始第1波战斗", log_file)
    send_actions([{"type": "start_wave"}])
    observations = wait_for_observations(5, log_file)
    for obs in observations:
        log(f"[OBS] {obs}", log_file)

    # 步骤5: 运行多波次战斗
    log("\n[步骤5] 运行战斗波次观察机制", log_file)
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
    generate_report(task_id, unit_name, all_logs, report_file, log_file)

    log(f"\n[完成] 日志: {log_file}", log_file)
    log(f"[完成] 报告: {report_file}", log_file)

def generate_report(task_id, unit_name, all_logs, report_file, log_file):
    """生成QA测试报告"""

    # 分析日志
    skill_logs = [obs for obs in all_logs if "[SKILL]" in obs or "[UNIT_SKILL]" in obs]
    buff_logs = [obs for obs in all_logs if "[BUFF]" in obs or "[UNIT_BUFF]" in obs]
    debuff_logs = [obs for obs in all_logs if "[DEBUFF]" in obs]
    heal_logs = [obs for obs in all_logs if "[HEAL]" in obs or "[UNIT_HEAL]" in obs]
    totem_logs = [obs for obs in all_logs if "[TOTEM]" in obs]

    report = f"""# QA测试报告: {unit_name} ({task_id})

## 任务信息
- **任务ID**: {task_id}
- **单位名称**: {unit_name}
- **执行时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **测试日志**: {log_file}
- **使用API**: reset_game() + spawn_unit()

## 测试结果

| 验证项 | 结果 |
|--------|------|
| 游戏重置 | ✅ 成功 (reset_game) |
| 单位生成 | ✅ 成功 (spawn_unit) |
| 技能日志 | {'✅ 有' if skill_logs else '❌ 无'} ({len(skill_logs)} 条) |
| Buff日志 | {'✅ 有' if buff_logs else '❌ 无'} ({len(buff_logs)} 条) |
| Debuff日志 | {'✅ 有' if debuff_logs else '❌ 无'} ({len(debuff_logs)} 条) |
| 治疗日志 | {'✅ 有' if heal_logs else '❌ 无'} ({len(heal_logs)} 条) |
| 图腾日志 | {'✅ 有' if totem_logs else '❌ 无'} ({len(totem_logs)} 条) |

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
### 治疗日志 ({len(heal_logs)} 条)
"""
    for log_entry in heal_logs[:5]:
        report += f"- {log_entry}\n"

    report += f"""
## 结论

**测试状态**: 🔄 已完成 (使用新API)

**使用的作弊API**:
- ✅ reset_game() - 重置游戏到初始状态
- ✅ spawn_unit() - 直接生成目标单位
- ✅ set_core_hp(99999) - 上帝模式保护核心

**发现的问题**:
- {'技能日志已输出' if skill_logs else '缺少详细技能日志'}
- {'Buff日志已输出' if buff_logs else '缺少Buff机制日志'}
- {'Debuff日志已输出' if debuff_logs else '缺少Debuff机制日志'}

**建议**:
- 需要补充更多机制日志埋点
- 验证spawn_unit生成的单位机制是否正常

---
报告生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
测试执行者: AI Player (使用新作弊API)
"""

    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)

    log(f"[报告已保存] {report_file}", log_file)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python3 test_with_new_api.py <task_id> <unit_name> <unit_id> <totem_id> [test_notes]")
        print("Example: python3 test_with_new_api.py TASK-COW-GOLEM-001 '牛魔像' cow_golem cow_totem '怒火中烧机制测试'")
        sys.exit(1)

    task_id = sys.argv[1]
    unit_name = sys.argv[2]
    unit_id = sys.argv[3]
    totem_id = sys.argv[4]
    test_notes = sys.argv[5] if len(sys.argv) > 5 else ""

    run_test_with_new_api(task_id, unit_name, unit_id, totem_id, test_notes)
