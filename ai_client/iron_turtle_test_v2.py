#!/usr/bin/env python3
"""
QA测试脚本v2: 铁甲龟 (Iron Turtle) 机制验证
改进: 添加上帝模式保护和多次刷新商店
任务ID: TASK-IRON-TURTLE-001
"""

import sys
import time
import json
import requests
from datetime import datetime

HTTP_PORT = 8080
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"
LOG_FILE = f"logs/ai_session_iron_turtle_v2_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

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

def enable_god_mode():
    """启用上帝模式保护核心"""
    log("[保护] 启用上帝模式...")
    # 尝试使用set_core_hp设置高血量
    result = send_actions([{"type": "set_core_hp", "hp": 99999}])
    if result:
        log(f"[RESULT] 设置核心血量: {result}")
    return result

def find_and_buy_unit(target_unit_keywords, max_refreshes=10):
    """
    多次刷新商店寻找目标单位
    target_unit_keywords: 单位名称关键词列表，如 ['iron_turtle', '铁甲龟']
    """
    log(f"[商店] 开始寻找目标单位: {target_unit_keywords}")

    for i in range(max_refreshes):
        log(f"[商店] 第 {i+1}/{max_refreshes} 次刷新...")

        # 刷新商店
        send_actions([{"type": "refresh_shop"}])
        observations = wait_for_observations(2)

        # 检查商店内容
        shop_content = ""
        for obs in observations:
            if "商店" in obs or "shop" in obs.lower():
                shop_content = obs
                log(f"[商店内容] {obs}")

                # 检查是否出现目标单位
                for keyword in target_unit_keywords:
                    if keyword.lower() in obs.lower():
                        log(f"[FOUND] 找到目标单位: {keyword}")

                        # 尝试购买（假设在商店位置0）
                        log("[购买] 尝试购买商店位置0...")
                        send_actions([{"type": "buy_unit", "shop_index": 0}])
                        wait_for_observations(2)
                        return True

    log("[WARN] 未找到目标单位，使用备用方案...")
    return False

def test_iron_turtle_v2():
    log("=" * 60)
    log("开始执行铁甲龟机制验证测试 v2 (TASK-IRON-TURTLE-001)")
    log("改进: 上帝模式 + 多次刷新商店")
    log("=" * 60)

    # 步骤1: 选择牛图腾
    log("\n[步骤1] 选择牛图腾 (cow_totem)")
    send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 步骤2: 启用上帝模式保护核心
    log("\n[步骤2] 启用上帝模式保护核心")
    enable_god_mode()
    observations = wait_for_observations(2)
    for obs in observations:
        if "血量" in obs or "HP" in obs:
            log(f"[OBS] {obs}")

    # 步骤3: 开始第1波
    log("\n[步骤3] 开始第1波战斗")
    send_actions([{"type": "start_wave"}])
    observations = wait_for_observations(5)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 步骤4: 多次刷新商店寻找铁甲龟
    log("\n[步骤4] 寻找并购买铁甲龟")
    iron_turtle_found = find_and_buy_unit(
        target_unit_keywords=['iron_turtle', '铁甲龟'],
        max_refreshes=10
    )

    if not iron_turtle_found:
        log("[备用] 购买商店中可用的单位...")
        send_actions([{"type": "buy_unit", "shop_index": 0}])
        wait_for_observations(2)

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

    # 步骤6: 运行多波次战斗，观察伤害减免
    log("\n[步骤6] 运行战斗波次，观察铁甲龟伤害减免机制")

    for wave in range(1, 4):
        log(f"\n[波次 {wave}] 开始战斗...")
        send_actions([{"type": "start_wave"}])
        observations = wait_for_observations(12)

        # 检查关键日志
        core_hit_logs = []
        skill_logs = []

        for obs in observations:
            log(f"[OBS] {obs}")
            if "[CORE_HIT]" in obs:
                core_hit_logs.append(obs)
            elif "[SKILL]" in obs and "iron" in obs.lower():
                skill_logs.append(obs)

        log(f"[SUMMARY] 波次 {wave} 核心受击日志: {len(core_hit_logs)} 条")
        for hit in core_hit_logs[:3]:  # 只显示前3条
            log(f"  - {hit}")

    # 测试总结
    log("\n" + "=" * 60)
    log("测试总结")
    log("=" * 60)

    log("\n[验证点检查]")
    log(f"1. 铁甲龟购买: {'✅ 成功' if iron_turtle_found else '⚠️ 使用备用单位'}")
    log("2. LV.1 硬化皮肤 - 受到伤害减去固定数值20: 需要检查日志")
    log("3. LV.3 绝对防御 - 伤害为0时回血: 需要升级验证")

    log(f"\n[日志文件] {LOG_FILE}")
    log("[状态] 铁甲龟测试v2完成")

    return True

if __name__ == "__main__":
    log("=" * 60)
    log("铁甲龟机制验证测试脚本 v2")
    log(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log("=" * 60)

    try:
        response = requests.get(f"{BASE_URL}/health", timeout=3)
        log(f"[INFO] 服务器状态: {response.json()}")
    except Exception as e:
        log(f"[ERROR] 无法连接服务器: {e}")
        sys.exit(1)

    try:
        test_iron_turtle_v2()
    except Exception as e:
        log(f"[ERROR] 测试执行失败: {e}")
        import traceback
        log(traceback.format_exc())
