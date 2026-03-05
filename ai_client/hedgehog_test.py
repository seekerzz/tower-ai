#!/usr/bin/env python3
"""
QA测试脚本: 刺猬 (Hedgehog) 机制验证
任务ID: TASK-HEDGEHOG-001
"""

import sys
import time
import json
import requests
from datetime import datetime

# 配置
HTTP_PORT = 8080
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"
LOG_FILE = f"logs/ai_session_hedgehog_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

def log(message):
    """记录日志到文件和控制台"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_line = f"[{timestamp}] {message}"
    print(log_line)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(log_line + '\n')

def send_actions(actions):
    """发送动作到游戏服务器"""
    try:
        response = requests.post(
            f"{BASE_URL}/action",
            json={"actions": actions},
            timeout=5
        )
        return response.json()
    except Exception as e:
        log(f"[ERROR] 发送动作失败: {e}")
        return None

def get_observations():
    """获取游戏观测日志"""
    try:
        response = requests.get(f"{BASE_URL}/observations", timeout=5)
        data = response.json()
        return data.get("observations", [])
    except Exception as e:
        log(f"[ERROR] 获取观测失败: {e}")
        return []

def wait_for_observations(duration=5):
    """等待并收集观测日志"""
    log(f"[WAIT] 等待 {duration} 秒收集日志...")
    time.sleep(duration)
    return get_observations()

def test_hedgehog():
    """执行刺猬测试"""
    log("=" * 60)
    log("开始执行刺猬机制验证测试 (TASK-HEDGEHOG-001)")
    log("=" * 60)

    # 测试步骤1: 选择牛图腾
    log("\n[步骤1] 选择牛图腾 (cow_totem)")
    result = send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
    if result:
        log(f"[RESULT] 选择图腾结果: {result}")

    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤2: 开始波次
    log("\n[步骤2] 开始第1波战斗")
    result = send_actions([{"type": "start_wave"}])
    if result:
        log(f"[RESULT] 开始波次结果: {result}")

    observations = wait_for_observations(5)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤3: 刷新商店寻找刺猬
    log("\n[步骤3] 刷新商店寻找刺猬")
    result = send_actions([{"type": "refresh_shop"}])
    if result:
        log(f"[RESULT] 刷新商店结果: {result}")

    observations = wait_for_observations(3)
    hedgehog_found = False
    for obs in observations:
        log(f"[OBS] {obs}")
        if "hedgehog" in obs.lower() or "刺猬" in obs:
            hedgehog_found = True
            log("[INFO] 商店中出现刺猬！")

    # 测试步骤4: 尝试购买单位
    log("\n[步骤4] 尝试购买商店第0个单位")
    result = send_actions([{"type": "buy_unit", "shop_index": 0}])
    if result:
        log(f"[RESULT] 购买单位结果: {result}")

    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤5: 部署单位
    log("\n[步骤5] 部署单位到战场")
    result = send_actions([{
        "type": "move_unit",
        "from_zone": "bench",
        "to_zone": "grid",
        "from_pos": 0,
        "to_pos": {"x": 1, "y": 0}
    }])
    if result:
        log(f"[RESULT] 部署单位结果: {result}")

    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤6: 运行多波次战斗，观察刺猬反弹
    log("\n[步骤6] 运行战斗波次，观察刺猬尖刺反弹机制")

    total_waves = 5
    all_skill_logs = []

    for wave in range(1, total_waves + 1):
        log(f"\n[波次 {wave}] 开始战斗...")

        result = send_actions([{"type": "start_wave"}])
        if result:
            log(f"[RESULT] 开始波次 {wave} 结果: {result}")

        observations = wait_for_observations(12)

        skill_logs = []
        damage_logs = []

        for obs in observations:
            log(f"[OBS] {obs}")
            if "[SKILL]" in obs and ("hedgehog" in obs.lower() or "刺猬" in obs):
                skill_logs.append(obs)
                all_skill_logs.append(obs)
            elif "damage" in obs.lower() or "伤害" in obs:
                damage_logs.append(obs)

        log(f"[SUMMARY] 波次 {wave} 刺猬技能日志: {len(skill_logs)} 条")
        for skill in skill_logs:
            log(f"  - {skill}")

    # 测试总结
    log("\n" + "=" * 60)
    log("测试总结")
    log("=" * 60)

    log(f"\n[技能日志统计] 总计 {len(all_skill_logs)} 条刺猬相关技能日志")
    for skill in all_skill_logs:
        log(f"  - {skill}")

    log("\n[验证点检查]")
    log("1. LV.1 尖刺反弹 - 30%概率反弹: 需要统计触发概率")
    log("2. LV.2 数值提升 - 50%概率反弹: 需要升级后验证")
    log("3. LV.3 刚毛散射 - 发射3枚尖刺: 需要升级后验证")

    log(f"\n[日志文件] {LOG_FILE}")
    log("[状态] 刺猬基础测试完成")

    return True

def main():
    """主函数"""
    log("=" * 60)
    log("刺猬机制验证测试脚本")
    log(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log("=" * 60)

    try:
        response = requests.get(f"{BASE_URL}/health", timeout=3)
        log(f"[INFO] 服务器状态: {response.json()}")
    except Exception as e:
        log(f"[ERROR] 无法连接服务器: {e}")
        return 1

    try:
        test_hedgehog()
        return 0
    except Exception as e:
        log(f"[ERROR] 测试执行失败: {e}")
        import traceback
        log(traceback.format_exc())
        return 1

if __name__ == "__main__":
    sys.exit(main())
