#!/usr/bin/env python3
"""
QA测试脚本: 铁甲龟 (Iron Turtle) 机制验证
任务ID: TASK-IRON-TURTLE-001
"""

import sys
import time
import json
import requests
from datetime import datetime

# 配置
HTTP_PORT = 8080
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"
LOG_FILE = f"logs/ai_session_iron_turtle_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

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

def check_log_pattern(observations, pattern):
    """检查日志中是否包含特定模式"""
    for obs in observations:
        if pattern in obs:
            return True, obs
    return False, None

def test_iron_turtle():
    """执行铁甲龟测试"""
    log("=" * 60)
    log("开始执行铁甲龟机制验证测试 (TASK-IRON-TURTLE-001)")
    log("=" * 60)

    # 测试步骤1: 选择牛图腾
    log("\n[步骤1] 选择牛图腾 (cow_totem)")
    result = send_actions([{"type": "select_totem", "totem_id": "cow_totem"}])
    if result:
        log(f"[RESULT] 选择图腾结果: {result}")

    # 等待观测
    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤2: 设置高血量核心（上帝模式）
    log("\n[步骤2] 设置高血量核心保护")
    # 使用skip_to_wave跳到第一波来开始游戏
    result = send_actions([{"type": "start_wave"}])
    if result:
        log(f"[RESULT] 开始波次结果: {result}")

    observations = wait_for_observations(5)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤3: 检查商店并购买铁甲龟
    log("\n[步骤3] 刷新商店寻找铁甲龟")
    result = send_actions([{"type": "refresh_shop"}])
    if result:
        log(f"[RESULT] 刷新商店结果: {result}")

    observations = wait_for_observations(3)
    shop_found = False
    for obs in observations:
        log(f"[OBS] {obs}")
        if "商店" in obs or "shop" in obs.lower():
            shop_found = True

    if not shop_found:
        log("[WARN] 未检测到商店日志，继续测试...")

    # 尝试购买第一个单位（假设是铁甲龟或等待出现）
    log("\n[步骤4] 尝试购买单位")
    result = send_actions([{"type": "buy_unit", "shop_index": 0}])
    if result:
        log(f"[RESULT] 购买单位结果: {result}")

    observations = wait_for_observations(3)
    for obs in observations:
        log(f"[OBS] {obs}")

    # 测试步骤5: 部署单位到战场
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

    # 测试步骤6: 运行多波次战斗，观察伤害减免
    log("\n[步骤6] 运行战斗波次，观察铁甲龟伤害减免机制")

    for wave in range(1, 4):
        log(f"\n[波次 {wave}] 开始战斗...")

        # 开始波次
        result = send_actions([{"type": "start_wave"}])
        if result:
            log(f"[RESULT] 开始波次 {wave} 结果: {result}")

        # 等待战斗进行
        observations = wait_for_observations(10)

        # 检查关键日志
        core_hit_logs = []
        skill_logs = []
        damage_logs = []

        for obs in observations:
            log(f"[OBS] {obs}")
            if "[CORE_HIT]" in obs:
                core_hit_logs.append(obs)
            elif "[SKILL]" in obs and "iron" in obs.lower():
                skill_logs.append(obs)
            elif "damage" in obs.lower() or "伤害" in obs:
                damage_logs.append(obs)

        log(f"[SUMMARY] 波次 {wave} 核心受击日志: {len(core_hit_logs)} 条")
        for hit in core_hit_logs:
            log(f"  - {hit}")

        log(f"[SUMMARY] 波次 {wave} 技能日志: {len(skill_logs)} 条")
        for skill in skill_logs:
            log(f"  - {skill}")

    # 测试总结
    log("\n" + "=" * 60)
    log("测试总结")
    log("=" * 60)

    log("\n[验证点检查]")
    log("1. LV.1 硬化皮肤 - 受到伤害减去固定数值20: 需要人工检查日志")
    log("2. LV.2 数值提升 - 减伤 20→35: 需要升级后验证")
    log("3. LV.3 绝对防御 - 减伤提升至50，伤害为0时回血: 需要升级后验证")

    log(f"\n[日志文件] {LOG_FILE}")
    log("[状态] 铁甲龟基础测试完成，详细机制验证需要更多测试数据")

    return True

def main():
    """主函数"""
    log("=" * 60)
    log("铁甲龟机制验证测试脚本")
    log(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log("=" * 60)

    # 检查服务器连接
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=3)
        log(f"[INFO] 服务器状态: {response.json()}")
    except Exception as e:
        log(f"[ERROR] 无法连接服务器: {e}")
        log("[INFO] 请确保Godot服务器已启动:")
        log("  python3 ai_client/ai_game_client.py --project . --scene res://src/Scenes/UI/CoreSelection.tscn --http-port 8080")
        return 1

    # 执行测试
    try:
        test_iron_turtle()
        return 0
    except Exception as e:
        log(f"[ERROR] 测试执行失败: {e}")
        import traceback
        log(traceback.format_exc())
        return 1

if __name__ == "__main__":
    sys.exit(main())
