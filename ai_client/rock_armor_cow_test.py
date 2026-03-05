#!/usr/bin/env python3
"""
QA测试脚本: 岩甲牛 (Rock Armor Cow) 机制验证
任务ID: TASK-ROCK-ARMOR-COW-001
"""

import sys
import time
import json
import requests
from datetime import datetime

HTTP_PORT = 8080
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"
LOG_FILE = f"logs/ai_session_rock_armor_cow_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

def log(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_line = f"[{timestamp}] {message}"
    print(log_line)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(log_line + '\n')

def send_actions(actions):
    try:
        response = requests.post(f"{BASE_URL}/action", json={"actions": actions}, timeout=5)
        return response.json()
    except Exception as e:
        log(f"[ERROR] 发送动作失败: {e}")
        return None

def get_observations():
    try:
        response = requests.get(f"{BASE_URL}/observations", timeout=5)
        return response.json().get("observations", [])
    except Exception as e:
        log(f"[ERROR] 获取观测失败: {e}")
        return []

def wait_for_observations(duration=5):
    log(f"[WAIT] 等待 {duration} 秒收集日志...")
    time.sleep(duration)
    return get_observations()

def test_rock_armor_cow():
    log("=" * 60)
    log("开始执行岩甲牛机制验证测试 (TASK-ROCK-ARMOR-COW-001)")
    log("=" * 60)

    # 步骤1: 选择牛图腾
    log("\n[步骤1] 选择牛图腾")
    send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 步骤2: 开始第1波
    log("\n[步骤2] 开始第1波战斗")
    send_actions([{"type": "start_wave"}])
    observations = wait_for_observations(5)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 步骤3: 多次刷新商店寻找岩甲牛
    log("\n[步骤3] 多次刷新商店寻找岩甲牛")
    rock_armor_cow_found = False
    for i in range(5):
        log(f"[商店刷新] 第 {i+1} 次刷新...")
        send_actions([{"type": "refresh_shop"}])
        observations = wait_for_observations(2)
        for obs in observations:
            log(f"[OBS] {obs}")
            if "rock_armor_cow" in obs.lower() or "岩甲牛" in obs:
                rock_armor_cow_found = True
                log("[INFO] 商店中出现岩甲牛！")
                break
        if rock_armor_cow_found:
            break

    # 步骤4: 购买单位
    log("\n[步骤4] 尝试购买商店单位")
    send_actions([{"type": "buy_unit", "shop_index": 0}])
    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 步骤5: 部署单位
    log("\n[步骤5] 部署单位到战场")
    send_actions([{
        "type": "move_unit",
        "from_zone": "bench", "to_zone": "grid",
        "from_pos": 0, "to_pos": {"x": 1, "y": 0}
    }])
    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 步骤6: 运行多波次战斗
    log("\n[步骤6] 运行多波次战斗，观察岩甲牛护盾机制")
    all_shield_logs = []

    for wave in range(1, 4):
        log(f"\n[波次 {wave}] 开始战斗...")
        send_actions([{"type": "start_wave"}])
        observations = wait_for_observations(12)

        shield_logs = []
        for obs in observations:
            log(f"[OBS] {obs}")
            if "[SHIELD]" in obs or "护盾" in obs:
                shield_logs.append(obs)
                all_shield_logs.append(obs)

        log(f"[SUMMARY] 波次 {wave} 护盾日志: {len(shield_logs)} 条")

    # 测试总结
    log("\n" + "=" * 60)
    log("测试总结")
    log("=" * 60)

    log(f"\n[护盾日志统计] 总计 {len(all_shield_logs)} 条")
    for shield in all_shield_logs:
        log(f"  - {shield}")

    log("\n[验证点检查]")
    log("1. LV.1 岩甲护盾 - 每波生成100% HP护盾: 需要验证")
    log("2. LV.2 数值提升 - 护盾150% HP: 需要升级验证")
    log("3. LV.3 溢出转护盾 - 治疗溢出10%转护盾: 需要升级验证")

    log(f"\n[日志文件] {LOG_FILE}")

if __name__ == "__main__":
    log("=" * 60)
    log(f"岩甲牛测试 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log("=" * 60)

    try:
        requests.get(f"{BASE_URL}/health", timeout=3)
        test_rock_armor_cow()
    except Exception as e:
        log(f"[ERROR] {e}")
        import traceback
        log(traceback.format_exc())
